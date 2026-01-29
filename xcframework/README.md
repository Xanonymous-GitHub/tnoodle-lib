# TNoodle XCFramework Build Guide

This guide describes how to build TNoodle as an iOS XCFramework using J2ObjC for Apple platforms.

## Prerequisites

### Required Tools

- **Java Development Kit (JDK)**: OpenJDK LTS version (tested with JDK 25)
- **J2ObjC**: Google's Java-to-Objective-C transpiler
- **Xcode Command Line Tools**: For `xcodebuild`, `clang`, and iOS SDKs
- **macOS**: Required for Apple platform development

### J2ObjC Setup

1. Clone the J2ObjC repository:
   ```bash
   git clone git@github.com:google/j2objc.git
   cd j2objc
   ```

2. Build J2ObjC for iOS architectures:
   ```bash
   export J2OBJC_ARCHS="iphone64 simulator64"
   make dist
   ```

3. Set the `J2OBJC_HOME` environment variable:
   ```bash
   export J2OBJC_HOME=/path/to/j2objc/dist
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
- Filters out third-party dependencies (GWT Exporter, SLF4J)
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
make dist
```

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
└── TNoodle.xcframework/     # Final output
```

## Clean Build

To start fresh, remove the build directory:

```bash
rm -rf build/apple
```

Then re-run the build process from step 2.
