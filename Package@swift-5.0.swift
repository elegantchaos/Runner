// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "Runner",
    platforms: [
        .macOS(.v10_13)
    ],
    products: [
        .library(
            name: "Runner",
            targets: ["Runner"]),
    ],
    dependencies: [
        .package(url: "https://github.com/elegantchaos/XCTestExtensions.git", from: "1.3.2")
    ],
    targets: [
        .target(
            name: "Runner",
            dependencies: []),
        .testTarget(
            name: "RunnerTests",
            dependencies: ["Runner", "XCTestExtensions"]
        ),
    ]
)
