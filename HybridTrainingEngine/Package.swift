// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HybridTrainingEngine",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "HybridTrainingCore",
            targets: ["HybridTrainingCore"]
        ),
        .library(
            name: "HybridTrainingStorage",
            targets: ["HybridTrainingStorage"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "HybridTrainingCore",
            dependencies: []
        ),
        .target(
            name: "HybridTrainingStorage",
            dependencies: ["HybridTrainingCore"]
        ),
        .testTarget(
            name: "HybridTrainingCoreTests",
            dependencies: [
                "HybridTrainingCore",
                "HybridTrainingStorage"
            ]
        ),
    ]
)
