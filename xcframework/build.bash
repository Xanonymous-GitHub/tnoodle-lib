#!/usr/bin/env bash

set -euo pipefail
: "${J2OBJC_HOME:?Please export J2OBJC_HOME=/path/to/j2objc/dist}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- Output layout ----
OUT="$PWD/build/apple"
OBJCDIR="$OUT/objc"          # produced by your prepare-build.bash (j2objc translation output)
BUILDDIR="$OUT/build"        # per-SDK/arch object + lib output
HDRROOT="$OUT/Headers"       # staged *public* headers for the XCFramework (minimal API)

rm -rf "$BUILDDIR" "$HDRROOT"
mkdir -p "$BUILDDIR" "$HDRROOT"

# ---- Helpers ----
# Which J2ObjC runtime library to embed into libTNoodle.a.
# Default is the full emulation runtime (most compatible).
# You can try J2OBJC_RUNTIME=jre_core for smaller output *only if it links and runs for your code*.

J2OBJC_RUNTIME="${J2OBJC_RUNTIME:-jre_emul}"

# ---- Arch helpers ----
# NOTE: Do NOT use grep "\\b" for arch matching. In basic grep regex, "\\b" is a backspace escape, not a word-boundary.
# Use `lipo -archs` and exact matching instead.
has_arch() {
  # Usage: has_arch <binary_or_archive> <arch>
  local file="$1" arch="$2"
  # `lipo -archs` prints a space-separated list of architectures.
  # We split and match exact tokens.
  lipo -archs "$file" 2>/dev/null | tr ' ' '\n' | grep -Fxq "$arch"
}

# Simulator x86_64 is optional (depends on toolchain + host).
# Set BUILD_SIM_X86_64=0 to skip it (smaller + faster; OK if you don't need Intel sim support).
BUILD_SIM_X86_64="${BUILD_SIM_X86_64:-auto}"
can_build_sim_x86_64() {
  if [[ "$BUILD_SIM_X86_64" == "0" ]]; then
    return 1
  fi
  if [[ "$BUILD_SIM_X86_64" == "1" ]]; then
    return 0
  fi
  # auto-detect: try compiling an empty file for iphonesimulator/x86_64
  local tmp
  tmp="$(mktemp -t tnoodle_x86_64_test).o"
  if xcrun --sdk iphonesimulator clang -arch x86_64 -c -x c /dev/null -o "$tmp" >/dev/null 2>&1; then
    rm -f "$tmp"
    return 0
  fi
  rm -f "$tmp" >/dev/null 2>&1 || true
  return 1
}

j2objc_runtime_lib_for_sdk() {
  # Usage: j2objc_runtime_lib_for_sdk <sdk>
  # Returns absolute path to the appropriate libjre_*.a slice for that SDK.
  local sdk="$1"
  local base="$J2OBJC_HOME/lib"

  case "$sdk" in
    iphoneos)
      echo "$base/iphone/lib${J2OBJC_RUNTIME}.a"
      ;;
    iphonesimulator)
      echo "$base/simulator/lib${J2OBJC_RUNTIME}.a"
      ;;
    *)
      echo "[ERROR] Unsupported sdk: $sdk" >&2
      return 1
      ;;
  esac
}

# Stage headers: curated umbrella header + module map only.
# IMPORTANT: Only ship minimal public headers (.h) and module.modulemap.
# Do NOT ship translated or J2ObjC runtime headers.
stage_headers() {
  local dest="$1"
  rm -rf "$dest"
  mkdir -p "$dest"

  # We intentionally ship a *tiny* public API surface.
  # The translated J2ObjC headers and J2ObjC runtime headers are used only at build time,
  # and are NOT copied into the XCFramework headers directory.

  # Copy curated umbrella header.
  if [[ -f "$SCRIPT_DIR/TNoodle.h" ]]; then
    cp -f "$SCRIPT_DIR/TNoodle.h" "$dest/TNoodle.h"
  elif [[ -f "$SCRIPT_DIR/Tnoodle.h" ]]; then
    cp -f "$SCRIPT_DIR/Tnoodle.h" "$dest/TNoodle.h"
  else
    echo "[ERROR] Missing curated header next to build.bash: TNoodle.h (or Tnoodle.h)" >&2
    exit 1
  fi

  # Copy module map.
  if [[ -f "$SCRIPT_DIR/module.modulemap" ]]; then
    cp -f "$SCRIPT_DIR/module.modulemap" "$dest/module.modulemap"
  else
    # Fallback minimal modulemap.
    cat > "$dest/module.modulemap" <<'EOF'
module TNoodle {
  umbrella "."
  export *
  module * { export * }
}
EOF
  fi
}

compile_one() {
  local sdk="$1" arch="$2" outdir="$3"
  mkdir -p "$outdir/obj" "$outdir/lib"

  local j2rt
  j2rt="$(j2objc_runtime_lib_for_sdk "$sdk")"
  if [[ ! -f "$j2rt" ]]; then
    echo "[ERROR] Missing J2ObjC runtime library for $sdk: $j2rt" >&2
    echo "        Check J2OBJC_HOME and/or build j2objc dist with the needed targets." >&2
    exit 1
  fi

  # IMPORTANT: J2ObjC runtime libs are often FAT (contain multiple archs).
  # If we pass a fat runtime into libtool, it may pick the wrong slice and
  # produce a lib with an unexpected architecture (e.g., arm64 for an x86_64 build).
  # So we *always* thin the runtime to the target arch before re-packing.
  local j2rt_thin="$outdir/lib/lib${J2OBJC_RUNTIME}_${sdk}_${arch}.a"
  if [[ -f "$j2rt" ]]; then
    # Ensure the runtime actually contains the requested arch.
    if ! has_arch "$j2rt" "$arch"; then
      echo "[ERROR] J2ObjC runtime library does not contain arch '$arch': $j2rt" >&2
      echo "        lipo -archs => $(lipo -archs "$j2rt" 2>/dev/null || true)" >&2
      exit 1
    fi
    # Extract the exact slice we want.
    lipo -thin "$arch" "$j2rt" -output "$j2rt_thin"
  else
    echo "[ERROR] Missing J2ObjC runtime library: $j2rt" >&2
    exit 1
  fi

  # If translated sources contain the J2ObjC ARC guard, compile without ARC.
  # Otherwise (when translated with `j2objc -use-arc`), compile with ARC.
  local arcflag="-fobjc-arc"
  if grep -R "must not be compiled with ARC" -n "$OBJCDIR" >/dev/null 2>&1; then
    arcflag="-fno-objc-arc"
  fi

  # Compile each .m, preserving relative paths to avoid basename collisions.
  while IFS= read -r -d '' f; do
    # Strip the OBJCDIR prefix to keep object paths short and stable.
    local rel="${f#$OBJCDIR/}"
    local o="$outdir/obj/${rel%.m}.o"
    mkdir -p "$(dirname "$o")"

    xcrun --sdk "$sdk" clang \
      -arch "$arch" -O2 -g0 \
      "$arcflag" \
      -isysroot "$(xcrun --sdk "$sdk" --show-sdk-path)" \
      -I"$J2OBJC_HOME/include" -I"$OBJCDIR" -I"$HDRROOT" \
      -c "$f" -o "$o"
  done < <(find "$OBJCDIR" -name '*.m' -print0)

  # Compile the curated wrapper (bridges a tiny stable API to the generated J2ObjC classes).
  local wrapper_m="$SCRIPT_DIR/TNoodle.m"
  if [[ ! -f "$wrapper_m" ]]; then
    wrapper_m="$SCRIPT_DIR/Tnoodle.m"
  fi
  if [[ ! -f "$wrapper_m" ]]; then
    echo "[ERROR] Missing curated wrapper next to build.bash: TNoodle.m (or Tnoodle.m)" >&2
    exit 1
  fi

  local wrapper_o="$outdir/obj/__tnoodle_wrapper__/TNoodle.o"
  mkdir -p "$(dirname "$wrapper_o")"

  xcrun --sdk "$sdk" clang \
    -arch "$arch" -O2 -g0 \
    "$arcflag" \
    -isysroot "$(xcrun --sdk "$sdk" --show-sdk-path)" \
    -I"$J2OBJC_HOME/include" -I"$OBJCDIR" -I"$HDRROOT" \
    -c "$wrapper_m" -o "$wrapper_o"

  # 1) Create a static library from translated objects.
  local filelist="$outdir/objfiles.txt"
  find "$outdir/obj" -name '*.o' -print > "$filelist"
  /usr/bin/libtool -static -o "$outdir/lib/libTNoodle_obj.a" -filelist "$filelist"

  # 2) Re-pack into the final libTNoodle.a, embedding the J2ObjC runtime library.
  # This avoids shipping JRE.xcframework separately.
  /usr/bin/libtool -static -o "$outdir/lib/libTNoodle.a" \
    "$outdir/lib/libTNoodle_obj.a" \
    "$j2rt_thin"

  # Sanity check: the produced library must match the requested arch.
  if ! has_arch "$outdir/lib/libTNoodle.a" "$arch"; then
    echo "[ERROR] Produced libTNoodle.a does not contain expected arch '$arch'" >&2
    echo "        lib: $outdir/lib/libTNoodle.a" >&2
    echo "        lipo -archs => $(lipo -archs "$outdir/lib/libTNoodle.a" 2>/dev/null || true)" >&2
    exit 1
  fi
}

# ---- Build slices (iOS only) ----
# iOS/iPadOS device: arm64 (iphoneos)
stage_headers "$HDRROOT"
compile_one iphoneos arm64 "$BUILDDIR/iphoneos-arm64"

# iOS simulator: arm64 (+ optional x86_64)
compile_one iphonesimulator arm64  "$BUILDDIR/iphonesim-arm64"

mkdir -p "$BUILDDIR/iphonesim-universal/lib"

if can_build_sim_x86_64; then
  compile_one iphonesimulator x86_64 "$BUILDDIR/iphonesim-x86_64"
  lipo -create \
    "$BUILDDIR/iphonesim-arm64/lib/libTNoodle.a" \
    "$BUILDDIR/iphonesim-x86_64/lib/libTNoodle.a" \
    -output "$BUILDDIR/iphonesim-universal/lib/libTNoodle.a"
else
  echo "[WARN] Skipping iphonesimulator x86_64 slice (BUILD_SIM_X86_64=$BUILD_SIM_X86_64)"
  cp -f "$BUILDDIR/iphonesim-arm64/lib/libTNoodle.a" "$BUILDDIR/iphonesim-universal/lib/libTNoodle.a"
fi

lipo -archs "$BUILDDIR/iphoneos-arm64/lib/libTNoodle.a"
lipo -archs "$BUILDDIR/iphonesim-universal/lib/libTNoodle.a"

# ---- Package as XCFramework (iOS device + iOS simulator) ----
XCF_OUT="$OUT/TNoodle.xcframework"
rm -rf "$XCF_OUT"

xcodebuild -create-xcframework \
  -library "$BUILDDIR/iphoneos-arm64/lib/libTNoodle.a" \
  -headers "$HDRROOT" \
  -library "$BUILDDIR/iphonesim-universal/lib/libTNoodle.a" \
  -headers "$HDRROOT" \
  -output "$XCF_OUT"

echo "[OK] Created XCFramework: $XCF_OUT"
echo "[OK] Embedded J2ObjC runtime: lib${J2OBJC_RUNTIME}.a (device+sim slices)"

echo "[NOTE] Consumer link flags (typical for J2ObjC):"
echo "       -ObjC  (often required for ObjC categories in static libs)"
echo "       -lz -liconv (may be required depending on used JRE classes)"
