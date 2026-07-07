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
        .executable(
            name: "timemaster-tool",
            targets: ["timemaster-tool"]
        ),
    ],
    targets: [
        .target(
            name: "TimeMasterCore",
            path: "Sources"
        ),
        .executableTarget(
            name: "timemaster-tool",
            dependencies: ["TimeMasterCore"],
            path: "CLI"
        ),
        .testTarget(
            name: "TimeMasterCoreTests",
            dependencies: ["TimeMasterCore"],
            path: "Tests"
        ),
    ]
)
