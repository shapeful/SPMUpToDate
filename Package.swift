// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SPMUpToDate",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .executable(name: "SPMUpToDate", targets: ["SPMUpToDate"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
        .package(url: "https://github.com/skelpo/json.git", branch: "main"),
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.10.2"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "SPMUpToDate",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "JSON", package: "json"),
                .product(name: "Alamofire", package: "alamofire"),
            ]
        )
    ]
)
