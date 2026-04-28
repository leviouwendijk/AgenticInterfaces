// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "FixtureApp",
    products: [
        .library(
            name: "FixtureApp",
            targets: ["FixtureApp"]
        ),
    ],
    targets: [
        .target(
            name: "FixtureApp",
            path: "Sources/App"
        ),
        .testTarget(
            name: "FixtureAppTests",
            dependencies: ["FixtureApp"],
            path: "Tests/AppTests"
        ),
    ]
)
