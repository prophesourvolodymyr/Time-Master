// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TimeMasterCore",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        .library(
            name: "TimeMasterCore",
            targets: ["TimeMasterCore"]
        ),
    ],
    targets: [
        .target(
            name: "TimeMasterCore",
            path: "Sources"
        ),
        .testTarget(
            name: "TimeMasterCoreTests",
            dependencies: ["TimeMasterCore"],
            path: "Tests"
        ),
    ]
)
