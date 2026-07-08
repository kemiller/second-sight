// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SecondSight",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "SecondSight",
            path: "Sources/SecondSight",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "SecondSightTests",
            dependencies: ["SecondSight"],
            path: "Tests/SecondSightTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
