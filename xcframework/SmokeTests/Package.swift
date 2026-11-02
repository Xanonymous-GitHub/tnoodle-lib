// swift-tools-version: 6.0

import PackageDescription

// Consumes the built XCFramework exactly the way an app would (see xcframework/README.md),
// so these tests also guard the documented integration steps.
//
// `xcframework/test.bash` copies `build/apple/TNoodle.xcframework` into `Artifacts/`
// before running, because a binary target must live inside the package directory.
let package = Package(
    name: "TNoodleSmokeTests",
    // Matches the default IOS_MIN_VERSION in xcframework/build.bash.
    platforms: [.iOS("18.7")],
    targets: [
        .binaryTarget(
            name: "TNoodle",
            path: "Artifacts/TNoodle.xcframework"
        ),
        .testTarget(
            name: "TNoodleSmokeTests",
            dependencies: ["TNoodle"],
            linkerSettings: [
                // J2ObjC's runtime registers Objective-C categories and loads classes reflectively.
                .unsafeFlags(["-ObjC"]),
                .linkedLibrary("iconv"),
                .linkedLibrary("z"),
                .linkedFramework("Security"),
            ]
        ),
    ]
)
