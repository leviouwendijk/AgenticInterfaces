import Agentic
import Foundation

public enum AgenticCapabilityInvocationForm:
    String,
    Sendable,
    Codable,
    Hashable,
    CaseIterable
{
    case call = "AgentToolCall"
    case batch = "non-empty AgentToolCall array"
    case plan = "AgentToolPlan"
}

public struct AgenticCapabilityProtocol:
    Sendable,
    Codable,
    Hashable
{
    public let invocationForms: [AgenticCapabilityInvocationForm]
    public let normalInvocationPerformsPreflight: Bool
    public let explicitPreflightExecutes: Bool
    public let sequenceStopsOnNonSuccess: Bool
    public let supportsOutcomeBranches: Bool

    public static var current: Self {
        .init(
            invocationForms:
                AgenticCapabilityInvocationForm.allCases,
            normalInvocationPerformsPreflight: true,
            explicitPreflightExecutes: false,
            sequenceStopsOnNonSuccess: true,
            supportsOutcomeBranches: true
        )
    }

    public init(
        invocationForms: [AgenticCapabilityInvocationForm],
        normalInvocationPerformsPreflight: Bool,
        explicitPreflightExecutes: Bool,
        sequenceStopsOnNonSuccess: Bool,
        supportsOutcomeBranches: Bool
    ) {
        self.invocationForms = invocationForms
        self.normalInvocationPerformsPreflight =
            normalInvocationPerformsPreflight
        self.explicitPreflightExecutes =
            explicitPreflightExecutes
        self.sequenceStopsOnNonSuccess =
            sequenceStopsOnNonSuccess
        self.supportsOutcomeBranches =
            supportsOutcomeBranches
    }
}

public struct AgenticCapabilityManifest:
    Sendable,
    Codable,
    Hashable
{
    public let workspaceRoot: String?
    public let sessionID: String?
    public let definitions: [AgentToolDefinition]

    public var protocolCapabilities: AgenticCapabilityProtocol {
        .current
    }

    public init(
        workspaceRoot: String? = nil,
        sessionID: String? = nil,
        definitions: [AgentToolDefinition]
    ) {
        self.workspaceRoot = workspaceRoot
        self.sessionID = sessionID
        self.definitions = definitions
    }
}

public extension AgenticToolHost {
    func capabilityManifest()
        -> AgenticCapabilityManifest
    {
        .init(
            workspaceRoot:
                context.workspace?
                    .rootURL
                    .standardizedFileURL
                    .path,
            sessionID:
                context.sessionID,
            definitions:
                registry.definitions
        )
    }

    func capabilityManifestText() throws
        -> String
    {
        try AgenticCapabilityManifestRenderer
            .render(
                capabilityManifest()
            )
    }
}

public enum AgenticCapabilityManifestRenderer {
    public static func render(
        _ manifest: AgenticCapabilityManifest
    ) throws -> String {
        var lines = [
            "AGENTIC CAPABILITY MANIFEST",
            "",
            "Workspace:",
            "    \(manifest.workspaceRoot ?? "<none>")",
            "Session:",
            "    \(manifest.sessionID ?? "<none>")",
            "",
            "Available tools (\(manifest.definitions.count)):",
        ]

        for definition in manifest.definitions {
            lines.append(
                ""
            )

            lines.append(
                definition.identifier.rawValue
            )

            lines.append(
                "    risk: \(definition.risk.rawValue)"
            )

            lines.append(
                "    description:"
            )

            lines.append(
                contentsOf:
                    indentedLines(
                        definition.description,
                        spaces: 8
                    )
            )

            lines.append(
                "    input_schema:"
            )

            lines.append(
                contentsOf:
                    try renderedSchemaLines(
                        for: definition,
                        spaces: 8
                    )
            )
        }

        lines.append(
            ""
        )

        lines.append(
            "Protocol:"
        )

        lines.append(
            contentsOf:
                protocolLines(
                    for: manifest.protocolCapabilities
                )
        )

        return lines.joined(
            separator: "\n"
        )
    }
}

private extension AgenticCapabilityManifestRenderer {
    static func protocolLines(
        for capabilities: AgenticCapabilityProtocol
    ) -> [String] {
        let invocationForms =
            capabilities.invocationForms
                .map(\.rawValue)
                .joined(separator: ", ")

        var lines = [
            "    - Treat the declared tools and schemas as the authoritative local tool surface for this session.",
            "    - Do not assume undeclared tools exist.",
            "    - Supported invocation payloads: \(invocationForms).",
            "    - Prefer a declared typed Agentic tool over an equivalent shell or process operation.",
        ]

        if capabilities.normalInvocationPerformsPreflight {
            lines.append(
                "    - Normal invocation performs governed preflight, policy evaluation, and approval handling before execution; do not issue a separate preflight by default."
            )
        }

        if !capabilities.explicitPreflightExecutes {
            lines.append(
                "    - Use explicit preflight only when a tool call should be inspected or reviewed without executing it."
            )
        }

        if capabilities.sequenceStopsOnNonSuccess {
            lines.append(
                "    - Use sequence for ordered success-gated dependencies; sequence stops after the first non-success and skips remaining siblings."
            )
        }

        if capabilities.supportsOutcomeBranches {
            lines.append(
                "    - Use onSuccess, onFailure, and onDenied when subsequent work differs by call outcome."
            )
        }

        lines.append(
            "    - Treat Agentic invocation and AgentToolPlan results as authoritative execution state."
        )

        return lines
    }

    static func renderedSchemaLines(
        for definition: AgentToolDefinition,
        spaces: Int
    ) throws -> [String] {
        guard let schema =
            definition.inputSchema
        else {
            return [
                String(
                    repeating: " ",
                    count: spaces
                ) + "null",
            ]
        }

        let encoder =
            JSONEncoder()

        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys,
        ]

        let data =
            try encoder.encode(
                schema
            )

        let text =
            String(
                decoding: data,
                as: UTF8.self
            )

        return indentedLines(
            text,
            spaces: spaces
        )
    }

    static func indentedLines(
        _ text: String,
        spaces: Int
    ) -> [String] {
        let prefix =
            String(
                repeating: " ",
                count: spaces
            )

        return text
            .split(
                separator: "\n",
                omittingEmptySubsequences: false
            )
            .map {
                prefix + String($0)
            }
    }
}
