// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "Runner",

  platforms: [.macOS(.v12), .iOS(.v15), .watchOS(.v8), .tvOS(.v15)],

  products: [.library(name: "Runner", targets: ["Runner"])],

  dependencies: [
    .package(
      url: "https://github.com/elegantchaos/ChaosByteStreams",
      from: "1.0.4"
    )
  ],

  targets: [
    .target(
      name: "Runner",
      dependencies: [
        .product(name: "ChaosByteStreams", package: "ChaosByteStreams")
      ]
    ),

    .testTarget(
      name: "RunnerTests",
      dependencies: ["Runner"],
      resources: [.process("Resources")]
    ),
  ]
)
