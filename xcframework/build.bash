#!/usr/bin/env bash

set -euo pipefail
: "${J2OBJC_HOME:?Please export J2OBJC_HOME=/path/to/j2objc/dist}"

OUT="$PWD/build/apple"
OBJCDIR="$OUT/objc"
BUILDDIR="$OUT/build"
INCDIR="$OUT/include"

rm -rf "$BUILDDIR" "$INCDIR"
mkdir -p "$BUILDDIR" "$INCDIR"

rsync -a "$OBJCDIR"/ "$INCDIR"/

compile_one () {
  local sdk="$1" arch="$2" outdir="$3"
  mkdir -p "$outdir/obj" "$outdir/lib"

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
      -I"$J2OBJC_HOME/include" -I"$INCDIR" \
      -c "$f" -o "$o"
  done < <(find "$OBJCDIR" -name '*.m' -print0)

  # Create the static library (portable on macOS bash 3.2): use Apple libtool -filelist.
  local filelist="$outdir/objfiles.txt"
  find "$outdir/obj" -name '*.o' -print > "$filelist"
  /usr/bin/libtool -static -o "$outdir/lib/libTNoodle.a" -filelist "$filelist"
}

# iOS/iPadOS device: arm64 (iphoneos)
compile_one iphoneos arm64 "$BUILDDIR/iphoneos-arm64"

# iOS simulator: arm64 + x86_64
compile_one iphonesimulator arm64   "$BUILDDIR/iphonesim-arm64"
compile_one iphonesimulator x86_64  "$BUILDDIR/iphonesim-x86_64"

mkdir -p "$BUILDDIR/iphonesim-universal/lib"
lipo -create \
  "$BUILDDIR/iphonesim-arm64/lib/libTNoodle.a" \
  "$BUILDDIR/iphonesim-x86_64/lib/libTNoodle.a" \
  -output "$BUILDDIR/iphonesim-universal/lib/libTNoodle.a"

lipo -info "$BUILDDIR/iphoneos-arm64/lib/libTNoodle.a"
lipo -info "$BUILDDIR/iphonesim-universal/lib/libTNoodle.a"

# ---- Package as XCFramework (iOS device + iOS simulator) ----
# For Swift/Kotlin import, static libraries need headers + a Clang module map.
# We place `module.modulemap` next to the public headers and pass that folder to
# `xcodebuild -create-xcframework -headers`.

# Create an umbrella header if the user hasn't provided one.
# You can replace this with a curated API later.
if [[ ! -f "$INCDIR/TNoodle.h" ]]; then
  cat > "$INCDIR/TNoodle.h" <<'EOF'
#pragma once

// Umbrella header for the TNoodle XCFramework.
// NOTE: This currently exposes the translated J2ObjC headers under this include directory.
// You can later replace/curate this header to expose only a stable C/ObjC API surface.
EOF
fi

# Create a module map if missing.
# IMPORTANT: the filename must be `module.modulemap`.
if [[ ! -f "$INCDIR/module.modulemap" ]]; then
  cat > "$INCDIR/module.modulemap" <<'EOF'
module TNoodle {
  umbrella "."
  export *
  module * { export * }
}
EOF
fi

# Build the XCFramework from the two static-library slices.
XCF_OUT="$OUT/TNoodle.xcframework"
rm -rf "$XCF_OUT"

if [[ ! -f "$BUILDDIR/iphoneos-arm64/lib/libTNoodle.a" ]]; then
  echo "[ERROR] Missing device library: $BUILDDIR/iphoneos-arm64/lib/libTNoodle.a" >&2
  exit 1
fi
if [[ ! -f "$BUILDDIR/iphonesim-universal/lib/libTNoodle.a" ]]; then
  echo "[ERROR] Missing simulator library: $BUILDDIR/iphonesim-universal/lib/libTNoodle.a" >&2
  exit 1
fi

xcodebuild -create-xcframework \
    -library "$BUILDDIR/iphoneos-arm64/lib/libTNoodle.a" \
    -headers "$INCDIR" \
    -library "$BUILDDIR/iphonesim-universal/lib/libTNoodle.a" \
    -headers "$INCDIR" \
    -output "$XCF_OUT"

echo "[OK] Created XCFramework: $XCF_OUT"
echo "[NOTE] This XCFramework depends on the J2ObjC runtime (JRE.xcframework from your j2objc dist)."
echo "       Link/ship JRE.xcframework alongside TNoodle.xcframework in your final integration."
