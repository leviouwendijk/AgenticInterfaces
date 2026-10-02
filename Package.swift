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
            name: "t_aint_main",
            targets: ["AgenticInterfacesTestFlows"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/leviouwendijk/Agentic.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Workspace.git", branch: "master"),

        .package(url: "https://github.com/leviouwendijk/Primitives.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Schema.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Macros.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Guidelines.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Difference.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/DSL.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Terminal.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Swim.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/SwimIO.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/SwimTerminal.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Parsers.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Arguments.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "AgenticInterfaces",
            dependencies: [
                .product(name: "Agentic", package: "Agentic"),
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
                .product(name: "ParsersStructuredContent", package: "Parsers"),
                .product(name: "Difference", package: "Difference"),
                .product(name: "Arguments", package: "Arguments"),
            ]
        ),
        .executableTarget(
            name: "AgenticInterfacesTestFlows",
            dependencies: [
                "AgenticInterfaces",
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "DSL", package: "DSL"),
                .product(name: "Terminal", package: "Terminal"),
            ],
            path: "Testing/AgenticInterfacesTestFlows"
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
