// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-llm-docs",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(name: "swift-llm-docs", targets: ["swift-llm-docs"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0")
    ],
    targets: [
        .executableTarget(
            name: "swift-llm-docs",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        )
    ]
)
