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
            targets: ["AgenticInterfacesTestFlows"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/leviouwendijk/Agentic.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/AgenticAdapters.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/AWSConnector.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Difference.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Terminal.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Arguments.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/TestFlows.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "AgenticInterfaces",
            dependencies: [
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "Terminal", package: "Terminal"),
                .product(name: "Difference", package: "Difference"),
                .product(name: "Arguments", package: "Arguments"),
                // .product(name: "DifferenceTerminal", package: "Difference")
            ]
        ),
        .executableTarget(
            name: "AgenticInterfacesTestFlows",
            dependencies: [
                "AgenticInterfaces",
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "AgenticApple", package: "AgenticAdapters"),
                .product(name: "AgenticAWS", package: "AgenticAdapters"),
                .product(name: "AWSConnector", package: "AWSConnector"),
                .product(name: "Terminal", package: "Terminal"),
                .product(name: "Difference", package: "Difference"),
                // .product(name: "DifferenceTerminal", package: "Difference"),
                .product(name: "TestFlows", package: "TestFlows"),
            ]
        ),
    ]
)
