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
        .executableTarget(
            name: "Brow",
            dependencies: ["BrowCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "BrowMediaRemote",
            cSettings: [.unsafeFlags(["-fobjc-arc"])],
            linkerSettings: [.linkedFramework("Foundation")]
        ),
        .testTarget(name: "BrowCoreTests", dependencies: ["BrowCore"]),
        .testTarget(name: "BrowMediaRemoteTests", dependencies: ["BrowMediaRemote"]),
    ]
)
