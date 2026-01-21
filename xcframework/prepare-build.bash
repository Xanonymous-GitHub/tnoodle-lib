#!/usr/bin/env bash

set -euo pipefail

: "${J2OBJC_HOME:?Please export J2OBJC_HOME=/path/to/j2objc/dist}"

./gradlew -q showClassPath > build/apple-classpath.txt

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

"$J2OBJC_HOME/j2objc" \
  -use-arc \
  -sourcepath "$SOURCEPATH" \
  -classpath "$CLASSPATH" \
  -d "$OBJCDIR" \
  @"$OUT/sources.txt"

find "$OBJCDIR" -name '*.m' | head
find "$OBJCDIR" -name '*.h' | head
