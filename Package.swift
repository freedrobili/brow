// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Brow",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "BrowCore", targets: ["BrowCore"]),
    ],
    targets: [
        .target(name: "BrowCore"),
        .testTarget(name: "BrowCoreTests", dependencies: ["BrowCore"]),
    ]
)
