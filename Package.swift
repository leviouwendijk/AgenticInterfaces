// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AgenticInterfaces",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "AgenticInterfaces",
            targets: ["AgenticInterfaces"]
        ),
        .executable(
            name: "aginttest",
            targets: ["aginttest"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/leviouwendijk/Agentic.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/AgenticAdapters.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Difference.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Terminal.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "AgenticInterfaces",
            dependencies: [
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "Terminal", package: "Terminal"),
                .product(name: "DifferenceTerminal", package: "Difference")
            ]
        ),
        .executableTarget(
            name: "aginttest",
            dependencies: [
                "AgenticInterfaces",
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "AgenticApple", package: "AgenticAdapters"),
            ]
        ),
    ]
)
