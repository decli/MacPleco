// swift-tools-version: 6.0
import PackageDescription

// The app is split into a library that holds everything and a three-line
// executable that boots it. Test targets cannot link an executable target
// cleanly (duplicate `main`), so the logic has to live in a library.
let package = Package(
    name: "MacPleco",
    platforms: [
        .macOS(.v15)
    ],
    targets: [
        .target(
            name: "MacPlecoKit",
            path: "Sources/MacPlecoKit",
            swiftSettings: [
                // Swift 5 language mode keeps strict-concurrency diagnostics as
                // warnings. The app is single-process and UI-bound; opting into
                // Swift 6 mode would buy little and cost a lot of annotation.
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("IOKit")
            ]
        ),
        .executableTarget(
            name: "MacPleco",
            dependencies: ["MacPlecoKit"],
            path: "Sources/MacPleco",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "MacPlecoKitTests",
            dependencies: ["MacPlecoKit"],
            path: "Tests/MacPlecoKitTests",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
