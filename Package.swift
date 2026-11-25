// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AgenticInterfaces",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "AgenticPresentation",
            targets: ["AgenticPresentation"]
        ),
        .library(
            name: "AgenticInterfaces",
            targets: ["AgenticInterfaces"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-agentic/Agentic.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Workspace.git", branch: "master"),

        .package(url: "https://github.com/leviouwendijk/Primitives.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Schema.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Macros.git", branch: "master"),
        .package(url: "https://github.com/swift-tooling/Guidelines.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Difference.git", branch: "master"),
        .package(url: "https://github.com/swift-dsl/DSL.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Terminal.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Reporting.git", branch: "master"),
        .package(url: "https://github.com/swift-nvim/Swim.git", branch: "master"),
        .package(url: "https://github.com/swift-nvim/SwimIO.git", branch: "master"),
        .package(url: "https://github.com/swift-nvim/SwimTerminal.git", branch: "master"),
        .package(url: "https://github.com/swift-langs/Parsers.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Arguments.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Search.git", branch: "master"),
    ],
    targets: [
        // What an interface shows, with no terminal: the conversation
        // snapshot, presentations, prompts and command definitions.
        .target(
            name: "AgenticPresentation",
            dependencies: [
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "AgenticStandard", package: "Agentic"),
                .product(name: "Primitives", package: "Primitives"),
                .product(name: "Guidelines", package: "Guidelines"),
                .product(name: "DSL", package: "DSL"),
                .product(name: "Reporting", package: "Reporting"),
                .product(name: "Search", package: "Search"),
                .product(name: "Difference", package: "Difference"),
            ]
        ),
        .target(
            name: "AgenticInterfaces",
            dependencies: [
                "AgenticPresentation",
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "AgenticStandard", package: "Agentic"),
                .product(name: "Workspace", package: "Workspace"),

                .product(name: "Primitives", package: "Primitives"),
                .product(name: "Schema", package: "Schema"),
                .product(name: "Macros", package: "Macros"),
                .product(name: "Guidelines", package: "Guidelines"),
                .product(name: "DSL", package: "DSL"),
                .product(name: "Terminal", package: "Terminal"),
                .product(name: "Swim", package: "Swim"),
                .product(name: "SwimIO", package: "SwimIO"),
                .product(name: "SwimTerminal", package: "SwimTerminal"),
                .product(name: "TerminalStructuredContent", package: "Terminal"),
                .product(name: "TerminalReporting", package: "Terminal"),
                .product(name: "TerminalGraph", package: "Terminal"),
                .product(name: "Reporting", package: "Reporting"),
                .product(name: "ParsersStructuredContent", package: "Parsers"),
                .product(name: "Difference", package: "Difference"),
                .product(name: "Arguments", package: "Arguments"),
                .product(name: "Search", package: "Search"),
            ]
        ),
    ]
)

for target in package.targets {
    switch target.type {
    case .regular, .executable, .test, .macro:
        var settings = target.swiftSettings ?? []

        settings.append(
            .treatAllWarnings(as: .error)
        )

        settings.append(
            .unsafeFlags(
                [
                    "-continue-building-after-errors"
                ]
            )
        )

        target.swiftSettings = settings

    case .plugin, .system, .binary:
        break

    @unknown default:
        break
    }
}
