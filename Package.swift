// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "aita-secret-santa",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .executable(name: "Run", targets: ["Run"]),
        .library(name: "App", targets: ["App"])
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.36.0"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/fluent-mysql-driver.git", from: "4.0.0"),
        .package(url: "https://github.com/givip/Telegrammer.git", from: "1.0.0-alpha")
    ],
    targets: [
        .target(name: "App", dependencies: [
            .product(name: "Fluent"),
            .product(name: "FluentMySQLDriver"),
            .product(name: "Vapor"),
            .product(name: "Telegrammer")
        ]),
        .target(name: "Run", dependencies: ["App"]),
    ]
)

