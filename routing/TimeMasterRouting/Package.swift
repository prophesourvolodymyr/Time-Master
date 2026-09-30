// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TimeMasterRouting",
    platforms: [.iOS(.v16)],
    products: [.library(name: "TimeMasterRouting", targets: ["TimeMasterRouting"])],
    targets: [.binaryTarget(name: "TimeMasterRouting", path: "TimeMasterRouting.xcframework")]
)
