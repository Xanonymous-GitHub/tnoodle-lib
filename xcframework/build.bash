#!/usr/bin/env bash

set -euo pipefail
: "${J2OBJC_HOME:?Please export J2OBJC_HOME=/path/to/j2objc/dist}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- Output layout ----
OUT="$PWD/build/apple"
OBJCDIR="$OUT/objc"          # produced by prepare-build.bash (j2objc translation output)
BUILDDIR="$OUT/build"        # per-SDK/arch object + lib output
HDRROOT="$OUT/Headers"       # staged *public* headers for the XCFramework (minimal API)

rm -rf "$BUILDDIR" "$HDRROOT"
mkdir -p "$BUILDDIR" "$HDRROOT"

# ---- Runtime libs selection ----
# Backward compatible default: if J2OBJC_RUNTIME_LIBS is unset, fall back to J2OBJC_RUNTIME (default: jre_emul).
J2OBJC_RUNTIME="${J2OBJC_RUNTIME:-jre_emul}"
J2OBJC_RUNTIME_LIBS_STR="${J2OBJC_RUNTIME_LIBS:-}"

# Accepted formats:
#   J2OBJC_RUNTIME_LIBS="jre_core jre_security"
#   J2OBJC_RUNTIME_LIBS="jre_core,jre_security"
#   J2OBJC_RUNTIME_LIBS="jre_core:jre_security"
if [[ -z "$J2OBJC_RUNTIME_LIBS_STR" ]]; then
  J2OBJC_RUNTIME_LIBS=("$J2OBJC_RUNTIME")
else
  J2OBJC_RUNTIME_LIBS_STR="${J2OBJC_RUNTIME_LIBS_STR//,/ }"
  J2OBJC_RUNTIME_LIBS_STR="${J2OBJC_RUNTIME_LIBS_STR//:/ }"
  read -r -a J2OBJC_RUNTIME_LIBS <<< "$J2OBJC_RUNTIME_LIBS_STR"
fi

if [[ "${#J2OBJC_RUNTIME_LIBS[@]}" -eq 0 ]]; then
  echo "[ERROR] J2OBJC_RUNTIME_LIBS resolved to an empty list" >&2
  exit 1
fi

# ---- Size/perf knobs ----
IOS_MIN_VERSION="${IOS_MIN_VERSION:-18.7}"  # deployment target
OPTIMIZE_FOR="${OPTIMIZE_FOR:-balanced}"        # size|balanced|speed
STRIP_SYMBOLS="${STRIP_SYMBOLS:-1}"

clang_optflags() {
  case "$OPTIMIZE_FOR" in
    size)     echo "-Oz" ;;
    balanced) echo "-O2" ;;
    speed)    echo "-O3" ;;
    *)
      echo "[ERROR] OPTIMIZE_FOR must be one of: size|balanced|speed (got '$OPTIMIZE_FOR')" >&2
      exit 1
      ;;
  esac
}

min_version_flag_for_sdk() {
  local sdk="$1"
  case "$sdk" in
    iphoneos)        echo "-miphoneos-version-min=${IOS_MIN_VERSION}" ;;
    iphonesimulator) echo "-mios-simulator-version-min=${IOS_MIN_VERSION}" ;;
    *)
      echo "[ERROR] Unsupported sdk for min version flag: $sdk" >&2
      exit 1
      ;;
  esac
}

has_arch() {
  local file="$1" arch="$2"
  lipo -archs "$file" 2>/dev/null | tr ' ' '\n' | grep -Fxq "$arch"
}

j2objc_runtime_lib_for_sdk() {
  # Usage: j2objc_runtime_lib_for_sdk <sdk> <runtime_lib>
  local sdk="$1" rt="$2"
  local base="$J2OBJC_HOME/lib"
  case "$sdk" in
    iphoneos)        echo "$base/iphone/lib${rt}.a" ;;
    iphonesimulator) echo "$base/simulator/lib${rt}.a" ;;
    *)
      echo "[ERROR] Unsupported sdk: $sdk" >&2
      return 1
      ;;
  esac
}

# Stage headers: curated umbrella header + module map only.
stage_headers() {
  local dest="$1"
  rm -rf "$dest"
  mkdir -p "$dest"

  if [[ -f "$SCRIPT_DIR/TNoodle.h" ]]; then
    cp -f "$SCRIPT_DIR/TNoodle.h" "$dest/TNoodle.h"
  elif [[ -f "$SCRIPT_DIR/Tnoodle.h" ]]; then
    cp -f "$SCRIPT_DIR/Tnoodle.h" "$dest/TNoodle.h"
  else
    echo "[ERROR] Missing curated header next to build.bash: TNoodle.h (or Tnoodle.h)" >&2
    exit 1
  fi

  if [[ -f "$SCRIPT_DIR/module.modulemap" ]]; then
    cp -f "$SCRIPT_DIR/module.modulemap" "$dest/module.modulemap"
  else
    cat > "$dest/module.modulemap" <<'EOF'
module TNoodle {
  header "TNoodle.h"
  export *
}
EOF
  fi
}

compile_one() {
  local sdk="$1" arch="$2" outdir="$3"
  mkdir -p "$outdir/obj" "$outdir/lib"

  # Thin each runtime lib to the target arch
  local j2rt_thins=()
  for rt in "${J2OBJC_RUNTIME_LIBS[@]}"; do
    local j2rt
    j2rt="$(j2objc_runtime_lib_for_sdk "$sdk" "$rt")"
    if [[ ! -f "$j2rt" ]]; then
      echo "[ERROR] Missing J2ObjC runtime library for $sdk: $j2rt" >&2
      exit 1
    fi
    if ! has_arch "$j2rt" "$arch"; then
      echo "[ERROR] J2ObjC runtime library does not contain arch '$arch': $j2rt" >&2
      echo "        lipo -archs => $(lipo -archs "$j2rt" 2>/dev/null || true)" >&2
      exit 1
    fi
    local thin="$outdir/lib/lib${rt}_${sdk}_${arch}.a"
    lipo -thin "$arch" "$j2rt" -output "$thin"
    j2rt_thins+=("$thin")
  done

  local arcflag="-fobjc-arc"
  if grep -R "must not be compiled with ARC" -n "$OBJCDIR" >/dev/null 2>&1; then
    arcflag="-fno-objc-arc"
  fi

  local minverflag
  minverflag="$(min_version_flag_for_sdk "$sdk")"

  while IFS= read -r -d '' f; do
    local rel="${f#$OBJCDIR/}"
    local o="$outdir/obj/${rel%.m}.o"
    mkdir -p "$(dirname "$o")"

    xcrun --sdk "$sdk" clang \
      -arch "$arch" $(clang_optflags) -g0 \
      -DNDEBUG \
      -ffunction-sections -fdata-sections \
      $minverflag \
      "$arcflag" \
      -isysroot "$(xcrun --sdk "$sdk" --show-sdk-path)" \
      -I"$J2OBJC_HOME/include" -I"$OBJCDIR" -I"$HDRROOT" \
      -c "$f" -o "$o"
  done < <(find "$OBJCDIR" -name '*.m' -print0)

  local wrapper_m="$SCRIPT_DIR/TNoodle.m"
  if [[ ! -f "$wrapper_m" ]]; then wrapper_m="$SCRIPT_DIR/Tnoodle.m"; fi
  if [[ ! -f "$wrapper_m" ]]; then
    echo "[ERROR] Missing curated wrapper next to build.bash: TNoodle.m (or Tnoodle.m)" >&2
    exit 1
  fi

  local wrapper_o="$outdir/obj/__tnoodle_wrapper__/TNoodle.o"
  mkdir -p "$(dirname "$wrapper_o")"

  xcrun --sdk "$sdk" clang \
    -arch "$arch" $(clang_optflags) -g0 \
    -DNDEBUG \
    -ffunction-sections -fdata-sections \
    $minverflag \
    "$arcflag" \
    -isysroot "$(xcrun --sdk "$sdk" --show-sdk-path)" \
    -I"$J2OBJC_HOME/include" -I"$OBJCDIR" -I"$HDRROOT" \
    -c "$wrapper_m" -o "$wrapper_o"

  # (Optional) force-link file - keep as you had it, if you need it.
  local forcelink_m="$outdir/obj/__tnoodle_wrapper__/TNoodleForceLink.m"
  cat > "$forcelink_m" <<'EOF'
// Auto-generated.
// References security provider classes so the linker can keep them.

#if __has_include("sun/security/provider/Sun.h")
#import "sun/security/provider/Sun.h"
__attribute__((used)) static void TNoodleForceLink_SunProvider(void) {
  [SunSecurityProviderSun class];
}
#endif

#if __has_include("com/google/j2objc/security/IosSecurityProvider.h")
#import "com/google/j2objc/security/IosSecurityProvider.h"
__attribute__((used)) static void TNoodleForceLink_IosSecurityProvider(void) {
  [ComGoogleJ2objcSecurityIosSecurityProvider class];
}
#endif
EOF

  local forcelink_o="$outdir/obj/__tnoodle_wrapper__/TNoodleForceLink.o"
  xcrun --sdk "$sdk" clang \
    -arch "$arch" $(clang_optflags) -g0 \
    -DNDEBUG \
    -ffunction-sections -fdata-sections \
    $minverflag \
    "$arcflag" \
    -isysroot "$(xcrun --sdk "$sdk" --show-sdk-path)" \
    -I"$J2OBJC_HOME/include" -I"$OBJCDIR" -I"$HDRROOT" \
    -c "$forcelink_m" -o "$forcelink_o"

  local filelist="$outdir/objfiles.txt"
  find "$outdir/obj" -name '*.o' -print > "$filelist"
  /usr/bin/libtool -static -o "$outdir/lib/libTNoodle_obj.a" -filelist "$filelist"

  /usr/bin/libtool -static -o "$outdir/lib/libTNoodle.a" \
    "$outdir/lib/libTNoodle_obj.a" \
    "${j2rt_thins[@]}"

  if [[ "$STRIP_SYMBOLS" == "1" ]]; then
    xcrun --sdk "$sdk" strip -S -x "$outdir/lib/libTNoodle.a" >/dev/null 2>&1 || true
  fi

  if ! has_arch "$outdir/lib/libTNoodle.a" "$arch"; then
    echo "[ERROR] Produced libTNoodle.a does not contain expected arch '$arch'" >&2
    echo "        lipo -archs => $(lipo -archs "$outdir/lib/libTNoodle.a" 2>/dev/null || true)" >&2
    exit 1
  fi
}

# ---- Build slices (iOS only) ----
stage_headers "$HDRROOT"

compile_one iphoneos arm64 "$BUILDDIR/iphoneos-arm64"
compile_one iphonesimulator arm64 "$BUILDDIR/iphonesim-arm64"

# Arm64-only simulator slice (Apple Silicon). No x86_64 simulator build.
mkdir -p "$BUILDDIR/iphonesim-universal/lib"
cp -f "$BUILDDIR/iphonesim-arm64/lib/libTNoodle.a" "$BUILDDIR/iphonesim-universal/lib/libTNoodle.a"

if [[ "$STRIP_SYMBOLS" == "1" ]]; then
  xcrun --sdk iphonesimulator strip -S -x "$BUILDDIR/iphonesim-universal/lib/libTNoodle.a" >/dev/null 2>&1 || true
  xcrun --sdk iphoneos        strip -S -x "$BUILDDIR/iphoneos-arm64/lib/libTNoodle.a" >/dev/null 2>&1 || true
fi

lipo -archs "$BUILDDIR/iphoneos-arm64/lib/libTNoodle.a"
lipo -archs "$BUILDDIR/iphonesim-universal/lib/libTNoodle.a"

# ---- Package as XCFramework ----
XCF_OUT="$OUT/TNoodle.xcframework"
rm -rf "$XCF_OUT"

xcodebuild -create-xcframework \
  -library "$BUILDDIR/iphoneos-arm64/lib/libTNoodle.a" \
  -headers "$HDRROOT" \
  -library "$BUILDDIR/iphonesim-universal/lib/libTNoodle.a" \
  -headers "$HDRROOT" \
  -output "$XCF_OUT"

echo "[OK] Created XCFramework: $XCF_OUT"
echo "[OK] Embedded J2ObjC runtime libs: ${J2OBJC_RUNTIME_LIBS[*]} (device+sim slices)"

echo "[NOTE] Consumer link flags / frameworks (typical for J2ObjC):"
echo "       -ObjC                     (may be needed when classes are loaded dynamically/reflection)"
echo "       -liconv                   (required when using J2ObjC JRE charset/iconv)"
echo "       -lz                       (needed if java.util.zip is used)"
echo "       -framework Security       (required if any embedded runtime/lib uses jre_security)"
