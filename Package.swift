// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "MTCoordinator",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(
            name: "MTCoordinator",
            targets: ["MTCoordinator"]
        ),
    ],
    targets: [
        .target(
            name: "MTCoordinator",
            path: "Sources/MTCoordinator"
        ),
    ]
)
