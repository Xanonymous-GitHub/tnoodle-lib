#!/usr/bin/env bash
#
# Tests build/apple/TNoodle.xcframework the way an app consumes it:
#   1. generates JVM reference scrambles and images (Fixtures/GenerateExpectedScrambles.java);
#   2. runs the Swift smoke tests on an iOS simulator, comparing against that reference;
#   3. builds the tests for a physical iOS device to prove the device slice links.
#
# Run from the repository root after prepare-build.bash and build.bash.
#
# Environment:
#   JAVA_HOME                JDK that runs the JVM reference (the project targets Java 25).
#   TNOODLE_SIMULATOR_UDID   Simulator to test on (default: an iPhone on the newest iOS runtime).
#   TNOODLE_RESULT_BUNDLE    Where to write the .xcresult bundle (default: build/apple/SmokeTests.xcresult).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$SCRIPT_DIR/SmokeTests"

OUT="$PWD/build/apple"
XCFRAMEWORK="$OUT/TNoodle.xcframework"
CLASSPATH_FILE="$PWD/build/apple-classpath.txt"
REFERENCE="$OUT/expected-scrambles.tsv"
DERIVED_DATA="$OUT/SmokeTestsDerivedData"
RESULT_BUNDLE="${TNOODLE_RESULT_BUNDLE:-$OUT/SmokeTests.xcresult}"

die() {
  echo "[ERROR] $*" >&2
  exit 1
}

[[ -d "$XCFRAMEWORK" ]] || die "Missing $XCFRAMEWORK; run xcframework/prepare-build.bash and xcframework/build.bash first."
[[ -s "$CLASSPATH_FILE" ]] || die "Missing $CLASSPATH_FILE; run xcframework/prepare-build.bash first."
command -v jq >/dev/null || die "jq is required to pick a simulator and scheme."

JAVA="${JAVA_HOME:+$JAVA_HOME/bin/}java"

# ---- 1. JVM reference ----
# :scrambles' own output (built by prepare-build.bash via `showClassPath`) plus its unfiltered
# runtime classpath, which lists only its dependencies; the reference needs every one of them.
SCRAMBLES_CLASSES="$PWD/scrambles/build/classes/java/main"
SCRAMBLES_RESOURCES="$PWD/scrambles/build/resources/main"
[[ -d "$SCRAMBLES_CLASSES" ]] || die "Missing $SCRAMBLES_CLASSES; run xcframework/prepare-build.bash first."
REFERENCE_CLASSPATH="$SCRAMBLES_CLASSES:$SCRAMBLES_RESOURCES:$(paste -sd ':' "$CLASSPATH_FILE")"

echo "[test] Generating JVM reference data with $("$JAVA" -version 2>&1 | head -n 1)"
"$JAVA" -cp "$REFERENCE_CLASSPATH" \
  "$PACKAGE_DIR/Fixtures/GenerateExpectedScrambles.java" > "$REFERENCE"
echo "[test] Wrote $(wc -l < "$REFERENCE" | tr -d ' ') reference records to $REFERENCE"

# ---- Stage the XCFramework inside the package (binary targets must live there) ----
rm -rf "$PACKAGE_DIR/Artifacts"
mkdir -p "$PACKAGE_DIR/Artifacts"
cp -R "$XCFRAMEWORK" "$PACKAGE_DIR/Artifacts/"

cd "$PACKAGE_DIR"

SCHEME="$(xcodebuild -list -json | jq -r '
  .workspace.schemes as $schemes
  | ($schemes | map(select(. == "TNoodleSmokeTests" or endswith("-Package"))) | first) // $schemes[0]
')"
[[ -n "$SCHEME" && "$SCHEME" != "null" ]] || die "Could not determine an Xcode scheme for $PACKAGE_DIR"

if [[ -z "${TNOODLE_SIMULATOR_UDID:-}" ]]; then
  TNOODLE_SIMULATOR_UDID="$(xcrun simctl list devices available --json | jq -r '
    .devices
    | to_entries
    | map(select(.key | test("SimRuntime\\.iOS-")))
    | sort_by(.key | capture("iOS-(?<v>[0-9-]+)$").v | split("-") | map(tonumber))
    | map(.value[] | select(.name | startswith("iPhone")))
    | last
    | .udid // empty
  ')"
fi
[[ -n "$TNOODLE_SIMULATOR_UDID" ]] || die "No available iPhone simulator found."

echo "[test] Scheme: $SCHEME"
echo "[test] Simulator: $(xcrun simctl list devices --json | jq -r --arg id "$TNOODLE_SIMULATOR_UDID" \
  '.devices | to_entries[] | .key as $rt | .value[] | select(.udid == $id) | "\(.name) (\($rt | sub(".*SimRuntime\\."; "")))"')"

# ---- 2. Simulator tests ----
rm -rf "$RESULT_BUNDLE"
# xcodebuild forwards TEST_RUNNER_-prefixed variables (prefix stripped) to the test process.
TEST_RUNNER_TNOODLE_EXPECTED_SCRAMBLES="$REFERENCE" \
  xcodebuild test \
    -scheme "$SCHEME" \
    -destination "platform=iOS Simulator,id=$TNOODLE_SIMULATOR_UDID" \
    -derivedDataPath "$DERIVED_DATA" \
    -resultBundlePath "$RESULT_BUNDLE"

# ---- 3. Device link check (cannot run on a hosted runner, but must build and link) ----
xcodebuild build-for-testing \
  -scheme "$SCHEME" \
  -destination "generic/platform=iOS" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO

echo "[OK] XCFramework smoke tests passed on the simulator and linked for device."
