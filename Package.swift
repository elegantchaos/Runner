// swift-tools-version:5.6

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
        .package(url: "https://github.com/elegantchaos/XCTestExtensions.git", from: "1.1.2")
    ],
    targets: [
        .target(
            name: "Runner",
            dependencies: []),
        .testTarget(
            name: "RunnerTests",
            dependencies: ["Runner", "XCTestExtensions"],
            resources: [
                .copy("Resources/")
            ]
        ),
    ]
)

import Foundation
if ProcessInfo.processInfo.environment["RESOLVE_COMMAND_PLUGINS"] != nil {
    package.dependencies.append(
        .package(url: "https://github.com/elegantchaos/SwiftFormatterPlugin.git", from: "1.0.2")
    )
}

