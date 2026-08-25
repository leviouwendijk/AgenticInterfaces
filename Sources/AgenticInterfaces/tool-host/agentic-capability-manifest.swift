import Agentic
import Foundation

public struct AgenticCapabilityManifest:
    Sendable,
    Codable,
    Hashable
{
    public let workspaceRoot: String?
    public let sessionID: String?
    public let definitions: [AgentToolDefinition]

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
            "    - Treat the declared tools and schemas as the authoritative local tool surface for this session."
        )

        lines.append(
            "    - Do not assume undeclared tools exist."
        )

        lines.append(
            "    - Request tool invocations as AgentToolCall JSON."
        )

        lines.append(
            "    - Prefer a declared typed Agentic tool over an equivalent shell or process operation."
        )

        lines.append(
            "    - Use preflight before consequential mutation."
        )

        lines.append(
            "    - Treat Agentic preflight and invocation results as authoritative execution state."
        )

        return lines.joined(
            separator: "\n"
        )
    }
}

private extension AgenticCapabilityManifestRenderer {
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
