// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Brow",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "BrowCore", targets: ["BrowCore"]),
        .library(name: "BrowMediaRemote", type: .dynamic, targets: ["BrowMediaRemote"]),
    ],
    dependencies: [
        // Self-updates. Pinned: this code installs updates on users' Macs.
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0"),
    ],
    targets: [
        .target(name: "BrowCore"),
        .executableTarget(
            name: "Brow",
            dependencies: ["BrowCore", .product(name: "Sparkle", package: "Sparkle")],
            swiftSettings: [.swiftLanguageMode(.v5)],
            // Sparkle.framework is embedded in Brow.app/Contents/Frameworks.
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
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
