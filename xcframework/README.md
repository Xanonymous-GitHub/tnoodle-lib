# TNoodle XCFramework Build Guide

This guide describes how to build TNoodle as an iOS XCFramework using J2ObjC for Apple platforms.

## Prerequisites

### Required Tools

- **JDK 25**: Builds the project with Gradle (`JAVA_HOME`)
- **JDK 21**: Builds and runs J2ObjC, whose 3.1 launcher only accepts JDK 1.8 or 11-22 (`J2OBJC_JAVA_HOME`)
- **J2ObjC 3.1**: Google's Java-to-Objective-C transpiler, built from source (see below)
- **Xcode** (CI uses Xcode 27): For `xcodebuild`, `clang`, iOS SDKs and simulators
- **macOS**: Required for Apple platform development
- **jq**: Used by `test.bash` to pick a simulator

### J2ObjC Setup

The build is pinned to **J2ObjC 3.1**, the newest tag. Google labels it an interim
pre-release, but 3.0.0 (the last release without that label) cannot translate the switch
expressions, `yield` and pattern-matching `instanceof` used in this codebase. Neither version
publishes prebuilt binaries, so J2ObjC is built from source.

1. Clone the pinned tag:
   ```bash
   git clone --depth 1 --branch 3.1 https://github.com/google/j2objc.git
   cd j2objc
   ```

2. Build the translator and JRE emulation libraries for the two iOS slices, with JDK 21:
   ```bash
   export JAVA_HOME="$(/usr/libexec/java_home -v 21)"
   export J2OBJC_ARCHS="iphone64 simulator64"   # arm64 device, arm64 simulator
   make -j"$(sysctl -n hw.logicalcpu)" translator_dist jre_emul_dist
   ```

3. Point the scripts at the distribution and the JDK that runs it:
   ```bash
   export J2OBJC_HOME=/path/to/j2objc/dist
   export J2OBJC_JAVA_HOME="$(/usr/libexec/java_home -v 21)"
   export JAVA_HOME="$(/usr/libexec/java_home -v 25)"   # back to JDK 25 for Gradle
   ```

## Build Process

### 1. Verify Project Build

Before creating the XCFramework, ensure the project builds successfully:

```bash
./gradlew build
```

This validates that all Java sources compile and tests pass.

### 2. Prepare Translation

Run the preparation script to translate Java sources to Objective-C:

```bash
./xcframework/prepare-build.bash
```

**What this does:**

- Extracts the project classpath from Gradle
- Keeps only third-party jars on the translation classpath, minus GWT Exporter and SLF4J
  (the project's own modules are translated from source)
- Creates a working copy of source files
- Strips GWT-specific annotations and logging code
- Translates Java sources to Objective-C using J2ObjC

### 3. Build XCFramework

Configure runtime libraries and build the XCFramework:

```bash
export J2OBJC_RUNTIME_LIBS="jre_core jre_security jre_util jre_net"
./xcframework/build.bash
```

**What this does:**

- Compiles Objective-C sources for iOS device (arm64) and simulator (arm64)
- Links with specified J2ObjC runtime libraries
- Packages static libraries into an XCFramework
- Applies optimization and symbol stripping

**Build time:** Typically 2-5 minutes depending on hardware

### 4. Output Location

The completed XCFramework will be located at:

```
build/apple/TNoodle.xcframework
```

### 5. Test

```bash
./xcframework/test.bash
```

**What this does:**

- Generates reference scrambles and images on the JVM
  (`SmokeTests/Fixtures/GenerateExpectedScrambles.java`) for every puzzle and several seeds
- Runs the Swift tests in `SmokeTests/` on an iOS simulator against the built XCFramework,
  linked the same way an app links it. They check that:
  - `TNoodlePuzzle` mirrors the Java `PuzzleRegistry` ordinals
  - every scramble reaches the same state as on the JVM, with a byte-identical SVG image
  - the move sequence is identical too, wherever the official solver is deterministic for
    a seed (Pyraminx and Skewb deliberately randomize among equally short solutions)
  - FTO scrambles use FTO notation, and the error sentinels behave as documented
- Builds the tests for a physical device, proving the device slice links

`TNOODLE_SIMULATOR_UDID` selects a specific simulator; by default an iPhone on the newest
iOS runtime is used.

## Continuous Integration

`.github/workflows/xcframework.yml` runs all of the above on every push and pull request
to `master` and `dev`, on the GitHub-hosted `xcode-27` runner. It builds J2ObjC from
source once and caches the result per J2ObjC version, architecture set and Xcode build,
and uploads the XCFramework (and, on failure, the `.xcresult` bundle) as artifacts.

## Build Configuration

### Runtime Libraries

The `J2OBJC_RUNTIME_LIBS` variable controls which J2ObjC runtime components are included:

- `jre_core`: Core Java runtime (required)
- `jre_security`: Security providers and cryptography
- `jre_util`: Utility collections and data structures
- `jre_net`: Network and URL handling

**Format options:**

```bash
# Space-separated (recommended)
export J2OBJC_RUNTIME_LIBS="jre_core jre_security"

# Comma-separated
export J2OBJC_RUNTIME_LIBS="jre_core,jre_security"

# Colon-separated
export J2OBJC_RUNTIME_LIBS="jre_core:jre_security"
```

### Optimization Options

| Variable          | Values                      | Default | Description               |
|-------------------|-----------------------------|---------|---------------------------|
| `IOS_MIN_VERSION` | iOS version                 | `18.7`  | Minimum deployment target |
| `OPTIMIZE_FOR`    | `size`, `balanced`, `speed` | `speed` | Optimization strategy     |
| `STRIP_SYMBOLS`   | `0`, `1`                    | `1`     | Remove debug symbols      |

**Example:**

```bash
export IOS_MIN_VERSION="17.0"
export OPTIMIZE_FOR="size"
export STRIP_SYMBOLS="1"
./xcframework/build.bash
```

### Size Reduction Options

For advanced size optimization, set these before running `prepare-build.bash`:

| Variable                        | Values    | Default | Description                          |
|---------------------------------|-----------|---------|--------------------------------------|
| `J2OBJC_STRIP_REFLECTION`       | `0`, `1`  | `0`     | Remove reflection metadata           |
| `J2OBJC_STRIP_GWT_INCOMPATIBLE` | `0`, `1`  | `1`     | Remove `@GwtIncompatible` code       |
| `J2OBJC_DEAD_CODE_REPORT`       | file path | unset   | Path to dead code elimination report |

## Integration with Xcode

### Adding to Your Project

1. Drag `TNoodle.xcframework` into your Xcode project
2. Select "Copy items if needed"
3. Add to your app target under "Frameworks, Libraries, and Embedded Content"

### Required Linker Flags

Add these flags in your target's **Build Settings** → **Other Linker Flags**:

```
-ObjC
-liconv
-lz
```

### Required Frameworks

Link these frameworks in **Build Phases** → **Link Binary With Libraries**:

```
Security.framework
```

## Architecture Support

The XCFramework includes:

- **iOS Device**: arm64 (iPhone, iPad)
- **iOS Simulator**: arm64 (Apple Silicon Macs)

> **Note:** x86_64 simulator support (Intel Macs) is not included in the default build.

## Troubleshooting

### Missing J2OBJC_HOME

**Error:** `J2OBJC_HOME: Please export J2OBJC_HOME=/path/to/j2objc/dist`

**Solution:** Ensure J2ObjC is built and the environment variable is set:

```bash
export J2OBJC_HOME=/path/to/j2objc/dist
```

### Gradle Build Failures

**Error:** Tests fail during `./gradlew build`

**Solution:** Fix failing tests before proceeding with XCFramework build. The Java project must be healthy.

### Missing Runtime Libraries

**Error:** `Missing J2ObjC runtime library for iphoneos`

**Solution:** Verify J2ObjC was built with correct architectures:

```bash
export J2OBJC_ARCHS="iphone64 simulator64"
cd /path/to/j2objc
make -j"$(sysctl -n hw.logicalcpu)" translator_dist jre_emul_dist
```

### Unsupported JDK

**Error:** `JDK not supported. Please set JAVA_HOME to JDK 11 or higher.`

**Solution:** The J2ObjC 3.1 launcher only accepts JDK 1.8 or 11-22. Point `J2OBJC_JAVA_HOME`
at JDK 21; `JAVA_HOME` can stay on JDK 25 for Gradle.

### Architecture Mismatch

**Error:** `J2ObjC runtime library does not contain arch 'arm64'`

**Solution:** The J2ObjC libraries were not built for the required architecture. Rebuild J2ObjC with
`J2OBJC_ARCHS="iphone64 simulator64"`.

## Build Artifacts

The build process creates:

```
build/apple/
├── objc/                    # Translated Objective-C sources
├── build/                   # Compiled object files and libraries
│   ├── iphoneos-arm64/
│   └── iphonesim-arm64/
├── Headers/                 # Public API headers
│   ├── TNoodle.h
│   └── module.modulemap
├── TNoodle.xcframework/     # Final output
├── expected-scrambles.tsv   # JVM reference written by test.bash
└── SmokeTests.xcresult      # Test results written by test.bash
```

## Clean Build

To start fresh, remove the build directory:

```bash
rm -rf build/apple
```

Then re-run the build process from step 2.
