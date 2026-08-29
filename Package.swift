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
    ],
    dependencies: [
        .package(url: "https://github.com/leviouwendijk/Agentic.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/AgenticExecution.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Primitives.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Schema.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/SchemaMacros.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Guidelines.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Difference.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Terminal.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Arguments.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "AgenticInterfaces",
            dependencies: [
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "AgenticExecution", package: "AgenticExecution"),
                .product(name: "Primitives", package: "Primitives"),
                .product(name: "Schema", package: "Schema"),
                .product(name: "SchemaMacros", package: "SchemaMacros"),
                .product(name: "Guidelines", package: "Guidelines"),
                .product(name: "Terminal", package: "Terminal"),
                .product(name: "Difference", package: "Difference"),
                .product(name: "Arguments", package: "Arguments"),
            ]
        ),
    ]
)
