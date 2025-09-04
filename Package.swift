// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Kinetics",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .tvOS(.v18),
        .watchOS(.v11)
    ],
    products: [
        .library(
            name: "Kinetics",
            targets: ["Kinetics"]
        ),
    ],
    targets: [
        .target(
            name: "Kinetics",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        )
    ]
)
