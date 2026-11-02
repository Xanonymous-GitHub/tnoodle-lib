#!/usr/bin/env bash

set -euo pipefail
: "${J2OBJC_HOME:?Please export J2OBJC_HOME=/path/to/j2objc/dist}"

# Gradle and the j2objc launcher need different JDKs: the build targets Java 25, while the
# j2objc launcher only accepts the JDKs its release supports (J2ObjC 3.1: 1.8, 11-22).
# JAVA_HOME drives Gradle; J2OBJC_JAVA_HOME (default: JAVA_HOME) drives the translator.
J2OBJC_JAVA_HOME="${J2OBJC_JAVA_HOME:-${JAVA_HOME:-}}"
echo "JAVA_HOME=${JAVA_HOME:-<unset>}"
echo "J2OBJC_JAVA_HOME=${J2OBJC_JAVA_HOME:-<unset>}"

mkdir -p build
./gradlew -q showClassPath >| build/apple-classpath.txt

# Keep only third-party jars on the translation classpath, minus the ones we never translate:
# - this project's own module jars are translated from source (see WORKSRC below); their Java 25
#   class files are also unreadable by the older JDK the translator runs on;
# - GWT Exporter / SLF4J would drag their library-only sources into the translation.
awk -v project_root="$PWD/" '
  index($0, project_root) == 1 { next }
  /\/gwtexporter-/ || /\/slf4j-/ { next }
  { print }
' build/apple-classpath.txt > build/apple-classpath.filtered.txt

CLASSPATH="$(paste -sd ':' build/apple-classpath.filtered.txt)"
echo "Translation classpath:"
echo "${CLASSPATH:-<empty>}" | tr ':' '\n'

OUT="$PWD/build/apple"
OBJCDIR="$OUT/objc"


rm -rf "$OUT"
mkdir -p "$OBJCDIR"

# Create a working copy of sources for translation.
# We strip GWT-exporter-only annotations/types (org.timepedia.exporter.client.*) for Apple native targets.
WORKSRC="$OUT/worksrc"
rm -rf "$WORKSRC"
mkdir -p "$WORKSRC"

for m in scrambles svglite threephase min2phase sq12phase fto3phase; do
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
  -d "$OBJCDIR"
)

if [[ -n "$CLASSPATH" ]]; then
  j2objc_args+=(-classpath "$CLASSPATH")
fi

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

JAVA_HOME="$J2OBJC_JAVA_HOME" "$J2OBJC_HOME/j2objc" "${j2objc_args[@]}" @"$OUT/sources.txt"
