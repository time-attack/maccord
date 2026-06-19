// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "maccord",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .library(name: "MaccordCore", targets: ["MaccordCore"]),
        .executable(name: "maccord", targets: ["maccord"]),
    ],
    targets: [
        .target(
            name: "MaccordCore",
            path: "Sources/MaccordCore",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .executableTarget(
            name: "maccord",
            dependencies: ["MaccordCore"],
            path: "Sources/maccord",
            resources: [
                .copy("Resources/Fonts")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "MaccordCoreTests",
            dependencies: ["MaccordCore"],
            path: "Tests/MaccordCoreTests",
            resources: [
                .copy("Fixtures")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
    ]
)
