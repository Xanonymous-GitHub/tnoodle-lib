#!/usr/bin/env bash

set -euo pipefail
: "${J2OBJC_HOME:?Please export J2OBJC_HOME=/path/to/j2objc/dist}"

# J2ObjC's public distribution historically supports JDK 8/11. Ensure a compatible JAVA_HOME.
# (The j2objc launcher script itself enforces this on many versions.)
if [[ -n "${JAVA_HOME:-}" ]]; then
  echo "JAVA_HOME=$JAVA_HOME"
fi

mkdir -p build
./gradlew -q showClassPath >| build/apple-classpath.txt

# For iOS/macOS native build we intentionally do NOT translate third-party libs
# If third-party libs stays on the classpath, it will drag in third-party libs-only sources and break translation.
grep -v \
-e '/gwtexporter-' \
-e '/slf4j-' \
build/apple-classpath.txt > build/apple-classpath.filtered.txt

CLASSPATH="$(paste -sd ':' build/apple-classpath.filtered.txt)"
echo "$CLASSPATH" | tr ':' '\n' | head

OUT="$PWD/build/apple"
OBJCDIR="$OUT/objc"


rm -rf "$OUT"
mkdir -p "$OBJCDIR"

# Create a working copy of sources for translation.
# We strip GWT-exporter-only annotations/types (org.timepedia.exporter.client.*) for Apple native targets.
WORKSRC="$OUT/worksrc"
rm -rf "$WORKSRC"
mkdir -p "$WORKSRC"

for m in scrambles svglite threephase min2phase sq12phase; do
  mkdir -p "$WORKSRC/$m/src/main/java"
  rsync -a "$m/src/main/java/" "$WORKSRC/$m/src/main/java/"
done

# Some repos keep shared Java sources at the root module.
if [[ -d "src/main/java" ]]; then
  mkdir -p "$WORKSRC/root/src/main/java"
  rsync -a "src/main/java/" "$WORKSRC/root/src/main/java/"
fi

# Strip imports and annotations that are only meaningful for GWT JS export.
# This keeps the Java semantics for native usage while avoiding pulling GWT libraries.
find "$WORKSRC" -name '*.java' -print0 \
  | xargs -0 perl -0777 -i -pe '
    s/^import\s+org\.timepedia\.exporter\.client\.[^;]+;\s*\n//mg;
    s/^import\s+org\.slf4j\.(?:Logger|LoggerFactory)\s*;\s*\n//mg;
    s/^import\s+org\.slf4j\.[^;]+;\s*\n//mg;
    s/^\s*@(?:Export|NoExport|ExportClosure)(?:\([^)]*\))?\s*\n//mg;
    s/\bimplements\s+Exportable\s*,\s*/implements /g;
    s/\s*,\s*Exportable\b//g;
    s/\bimplements\s+Exportable\b\s*//g;
    # Drop common SLF4J logger fields initialized via LoggerFactory.
    s/^\s*(?:private|protected|public)?\s*static\s+final\s+Logger\s+\w+\s*=\s*LoggerFactory\.getLogger\([^;]*\);\s*\n//mg;
    s/^\s*(?:private|protected|public)?\s*static\s+Logger\s+\w+\s*=\s*LoggerFactory\.getLogger\([^;]*\);\s*\n//mg;

    # Drop simple one-line log statements (trace/debug/info/warn/error).
    s/^\s*\w+\.(?:trace|debug|info|warn|error)\([^;]*\);\s*\n//mg;

    # Drop common enabled-guard one-liners.
    s/^\s*if\s*\(\s*\w+\.is(?:Trace|Debug|Info|Warn|Error)Enabled\(\)\s*\)\s*\{\s*\w+\.(?:trace|debug|info|warn|error)\([^;]*\);\s*\}\s*\n//mg;
  '

SOURCEPATH="$(find "$WORKSRC" -type d -path "*/src/main/java" -print | paste -sd ':' -)"
echo "$SOURCEPATH" | tr ':' '\n'

# Build the list of Java sources to translate.
: > "$OUT/sources.txt"
find "$WORKSRC" -path '*/src/main/java/*' -name '*.java' -print >> "$OUT/sources.txt"

wc -l "$OUT/sources.txt"

# ---- J2ObjC translation flags (size-focused) ----
# NOTE:
# - `--dead-code-report` can significantly reduce output size, but the report must be generated
#   with correct keep rules (otherwise you may accidentally remove required code).
#   See: https://developers.google.com/j2objc/guides/dead-code-elimination
J2OBJC_DEAD_CODE_REPORT="${J2OBJC_DEAD_CODE_REPORT:-}"

# Strip Java reflection metadata to reduce size. Only enable if you don't rely on reflection.
J2OBJC_STRIP_REFLECTION="${J2OBJC_STRIP_REFLECTION:-0}"

# Remove @GwtIncompatible-marked methods to shrink output (safe for most non-GWT iOS uses).
J2OBJC_STRIP_GWT_INCOMPATIBLE="${J2OBJC_STRIP_GWT_INCOMPATIBLE:-1}"

j2objc_args=(
  -use-arc
  -sourcepath "$SOURCEPATH"
  -classpath "$CLASSPATH"
  -d "$OBJCDIR"
)

if [[ "$J2OBJC_STRIP_GWT_INCOMPATIBLE" == "1" ]]; then
  j2objc_args+=(--strip-gwt-incompatible)
fi

if [[ "$J2OBJC_STRIP_REFLECTION" == "1" ]]; then
  j2objc_args+=(--strip-reflection)
fi

if [[ -n "$J2OBJC_DEAD_CODE_REPORT" ]]; then
  if [[ ! -f "$J2OBJC_DEAD_CODE_REPORT" ]]; then
    echo "[ERROR] J2OBJC_DEAD_CODE_REPORT is set but file does not exist: $J2OBJC_DEAD_CODE_REPORT" >&2
    exit 1
  fi
  j2objc_args+=(--dead-code-report "$J2OBJC_DEAD_CODE_REPORT")
fi

"$J2OBJC_HOME/j2objc" "${j2objc_args[@]}" @"$OUT/sources.txt"
