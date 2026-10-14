// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Brow",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "BrowCore", targets: ["BrowCore"]),
        .library(name: "BrowMediaRemote", type: .dynamic, targets: ["BrowMediaRemote"]),
    ],
    targets: [
        .target(name: "BrowCore"),
        .target(
            name: "BrowMediaRemote",
            cSettings: [.unsafeFlags(["-fobjc-arc"])],
            linkerSettings: [.linkedFramework("Foundation")]
        ),
        .testTarget(name: "BrowCoreTests", dependencies: ["BrowCore"]),
    ]
)
