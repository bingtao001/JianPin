// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "JianPin",
    defaultLocalization: "zh-Hans",
    platforms: [
        .macOS(.v12)
    ],
    targets: [
        .target(
            name: "JianPinEngine",
            dependencies: [],
            path: "Sources/JianPinEngine"
        ),
        .executableTarget(
            name: "JianPin",
            dependencies: ["JianPinEngine"],
            path: "Sources/JianPin"
        ),
        .testTarget(
            name: "JianPinTests",
            dependencies: ["JianPinEngine"],
            path: "Tests/JianPinTests"
        )
    ]
)