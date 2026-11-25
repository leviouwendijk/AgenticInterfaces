// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AgenticInterfacesTests",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "t_aint_main",
            targets: ["AgenticInterfacesTestFlows"]
        ),
        .executable(
            name: "t_aint_reporting",
            targets: ["AgenticInterfacesReportingTesting"]
        ),
        .executable(
            name: "t_aint_structured",
            targets: ["AgenticInterfacesStructuredTesting"]
        ),
        .executable(
            name: "t_aint_diffpreview",
            targets: ["AgenticInterfacesDiffPreview"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-agentic/Agentic.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Workspace.git", branch: "master"),

        .package(url: "https://github.com/swift-lco/Primitives.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Schema.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Difference.git", branch: "master"),
        .package(url: "https://github.com/swift-dsl/DSL.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Terminal.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Reporting.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Search.git", branch: "master"),
        .package(url: "https://github.com/swift-agentic/AgenticIO.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Path.git", branch: "master"),
        .package(path: ".."),
    ],
    targets: [
        .executableTarget(
            name: "AgenticInterfacesStructuredTesting",
            dependencies: [
                .product(name: "AgenticInterfaces", package: "AgenticInterfaces"),
                .product(name: "AgenticPresentation", package: "AgenticInterfaces"),
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "AgenticStandard", package: "Agentic"),
                .product(name: "Primitives", package: "Primitives"),
                .product(name: "Reporting", package: "Reporting"),
            ]
        ),
        .executableTarget(
            name: "AgenticInterfacesReportingTesting",
            dependencies: [
                .product(name: "AgenticInterfaces", package: "AgenticInterfaces"),
                .product(name: "AgenticPresentation", package: "AgenticInterfaces"),
                .product(name: "DSL", package: "DSL"),
                .product(name: "Reporting", package: "Reporting"),
                .product(name: "Search", package: "Search"),
                .product(name: "Terminal", package: "Terminal"),
            ]
        ),
        .executableTarget(
            name: "AgenticInterfacesTestFlows",
            dependencies: [
                .product(name: "AgenticInterfaces", package: "AgenticInterfaces"),
                .product(name: "AgenticPresentation", package: "AgenticInterfaces"),
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "Reporting", package: "Reporting"),
                .product(name: "DSL", package: "DSL"),
                .product(name: "Terminal", package: "Terminal"),
                .product(name: "TerminalGhostty", package: "Terminal"),
                .product(name: "Difference", package: "Difference"),
                .product(name: "Schema", package: "Schema"),
            ]
        ),
        .executableTarget(
            name: "AgenticInterfacesDiffPreview",
            dependencies: [
                .product(name: "AgenticInterfaces", package: "AgenticInterfaces"),
                .product(name: "AgenticPresentation", package: "AgenticInterfaces"),
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "AgenticIO", package: "AgenticIO"),
                .product(name: "Path", package: "Path"),
                .product(name: "Terminal", package: "Terminal"),
                .product(name: "Workspace", package: "Workspace")
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
