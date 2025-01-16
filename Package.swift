// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SPMUpToDate",
    platforms: [
        .macOS(.v10_15),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
        .package(url: "https://github.com/skelpo/json.git", branch: "main"),
        //        .package(url: "https://github.com/freshOS/Networking.git", from: "2.0.3"),
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.10.2"),
        //        .package(url: "https://github.com/shapeful/swift-package-list.git", branch: "master")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "SPMUpToDate",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "JSON", package: "json"),
                //                .product(name: "Networking", package: "networking"),
                .product(name: "Alamofire", package: "alamofire"),
                //                .product(name: "SwiftPackageList", package: "swift-package-list"),
            ]
        )
    ]
)
