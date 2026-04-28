import Agentic

public struct AgenticRunCommandModel: Sendable, Codable, Hashable {
    public var prompt: String
    public var modeID: AgenticModeIdentifier
    public var modeTitle: String
    public var routePurpose: AgentModelRoutePurpose
    public var autonomyMode: AutonomyMode
    public var budgetPosture: BudgetPosture
    public var approvalStrictness: ApprovalStrictness
    public var exposedToolNames: [String]
    public var loadedSkillIDs: [AgentSkillIdentifier]
    public var missingSkillIDs: [AgentSkillIdentifier]
    public var metadata: [String: String]

    public init(
        prompt: String,
        modeID: AgenticModeIdentifier,
        modeTitle: String,
        routePurpose: AgentModelRoutePurpose,
        autonomyMode: AutonomyMode,
        budgetPosture: BudgetPosture,
        approvalStrictness: ApprovalStrictness,
        exposedToolNames: [String],
        loadedSkillIDs: [AgentSkillIdentifier],
        missingSkillIDs: [AgentSkillIdentifier],
        metadata: [String: String] = [:]
    ) {
        self.prompt = prompt
        self.modeID = modeID
        self.modeTitle = modeTitle
        self.routePurpose = routePurpose
        self.autonomyMode = autonomyMode
        self.budgetPosture = budgetPosture
        self.approvalStrictness = approvalStrictness
        self.exposedToolNames = exposedToolNames
        self.loadedSkillIDs = loadedSkillIDs
        self.missingSkillIDs = missingSkillIDs
        self.metadata = metadata
    }

    public init(
        prompt: String,
        application: ModeRuntimeApplication,
        request: AgentRequest
    ) {
        self.init(
            prompt: prompt,
            modeID: application.modeID,
            modeTitle: application.selection.mode.title,
            routePurpose: application.routePolicy.purpose,
            autonomyMode: application.configuration.autonomyMode,
            budgetPosture: application.selection.budgetPosture,
            approvalStrictness: application.selection.approvalStrictness,
            exposedToolNames: request.tools.map(\.name).sorted(),
            loadedSkillIDs: application.loadedSkills.map(\.identifier),
            missingSkillIDs: application.missingSkillIdentifiers,
            metadata: request.metadata
        )
    }
}

public struct AgenticRunScreen: Sendable, Codable, Hashable {
    public var command: AgenticRunCommandModel

    public init(
        command: AgenticRunCommandModel
    ) {
        self.command = command
    }

    public func renderedHeader() -> String {
        var lines: [String] = [
            "agentic run",
            "  mode        \(command.modeID.rawValue)",
            "  title       \(command.modeTitle)",
            "  purpose     \(command.routePurpose.rawValue)",
            "  autonomy    \(command.autonomyMode.rawValue)",
            "  budget      \(command.budgetPosture.rawValue)",
            "  approval    \(command.approvalStrictness.rawValue)",
            "  prompt      \(command.prompt)"
        ]

        if !command.exposedToolNames.isEmpty {
            lines.append(
                "  tools       \(command.exposedToolNames.joined(separator: ","))"
            )
        }

        if !command.loadedSkillIDs.isEmpty {
            lines.append(
                "  skills      \(command.loadedSkillIDs.map(\.rawValue).joined(separator: ","))"
            )
        }

        if !command.missingSkillIDs.isEmpty {
            lines.append(
                "  missing     \(command.missingSkillIDs.map(\.rawValue).joined(separator: ","))"
            )
        }

        return lines.joined(
            separator: "\n"
        )
    }

    public func renderedPreflight(
        _ preflight: ToolPreflight
    ) -> String {
        var lines: [String] = [
            "tool preflight",
            "  tool        \(preflight.toolName)",
            "  risk        \(preflight.risk.rawValue)",
            "  summary     \(preflight.summary)"
        ]

        if !preflight.targetPaths.isEmpty {
            lines.append(
                "  targets     \(preflight.targetPaths.joined(separator: ","))"
            )
        }

        lines.append(
            "  writes      \(preflight.estimatedWriteCount)"
        )

        if let estimatedWriteBytes = preflight.estimatedWriteBytes {
            lines.append(
                "  bytes       \(estimatedWriteBytes)"
            )
        }

        return lines.joined(
            separator: "\n"
        )
    }
}
