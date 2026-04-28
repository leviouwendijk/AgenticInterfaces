import Agentic
import Terminal
import Foundation

public enum AgenticApprovalChoice: String, Sendable, Codable, Hashable, CaseIterable {
    case approve
    case deny
    case inspectDetails = "inspect_details"
    case showDiff = "show_diff"
    case stopRun = "stop_run"

    public var title: String {
        switch self {
        case .approve:
            return "Approve"

        case .deny:
            return "Deny"

        case .inspectDetails:
            return "Inspect details"

        case .showDiff:
            return "Show diff"

        case .stopRun:
            return "Stop run"
        }
    }

    public var summary: String {
        switch self {
        case .approve:
            return "Approve this staged tool call."

        case .deny:
            return "Deny this staged tool call and continue with a denial result."

        case .inspectDetails:
            return "Render the full preflight and staged intent details."

        case .showDiff:
            return "Render the staged diff preview."

        case .stopRun:
            return "Stop this run without approving the staged tool call."
        }
    }

    public var approvalDecision: ApprovalDecision? {
        switch self {
        case .approve:
            return .approved

        case .deny:
            return .denied

        case .inspectDetails,
             .showDiff,
             .stopRun:
            return nil
        }
    }
}

public enum AgenticInterfaceEvent: Sendable, Codable, Hashable {
    case runStarted(prompt: String)
    case modeRunStarted(AgenticRunCommandModel)
    case toolCallProposed(AgentToolCall)
    case toolPreflight(ToolPreflight)
    case approvalRequested(AgenticApprovalPrompt)
    case approvalChoice(AgenticApprovalChoice)
    case approvalDecision(ApprovalDecision)
    case runStopped(reason: String)
    case runCompleted(summary: String)
}

public protocol AgenticInterfaceEventSink: Sendable {
    func record(
        _ event: AgenticInterfaceEvent
    ) async throws
}

public protocol AgenticRunPresenter: Sendable {
    func present(
        _ event: AgenticInterfaceEvent
    ) async throws

    func present(
        _ result: AgentRunResult
    ) async throws
}

public struct TerminalAgenticRunPresenter: AgenticRunPresenter {
    public var stream: TerminalStream
    public var sinks: [any AgenticInterfaceEventSink]
    public var theme: TerminalTheme
    public var showsVerboseEvents: Bool

    public init(
        stream: TerminalStream = .standardError,
        sinks: [any AgenticInterfaceEventSink] = [],
        theme: TerminalTheme = .agentic,
        showsVerboseEvents: Bool = false
    ) {
        self.stream = stream
        self.sinks = sinks
        self.theme = theme
        self.showsVerboseEvents = showsVerboseEvents
    }

    public func present(
        _ event: AgenticInterfaceEvent
    ) async throws {
        for sink in sinks {
            try await sink.record(
                event
            )
        }

        let rendered = render(
            event
        )

        guard !rendered.isEmpty else {
            return
        }

        Terminal.write(
            rendered,
            to: stream
        )
    }

    public func present(
        _ result: AgentRunResult
    ) async throws {
        let rendered = render(
            result
        )

        guard !rendered.isEmpty else {
            return
        }

        Terminal.write(
            rendered,
            to: stream
        )
    }
}

private extension TerminalAgenticRunPresenter {
    func render(
        _ result: AgentRunResult
    ) -> String {
        if let pendingApproval = result.pendingApproval {
            return block(
                title: "Run suspended",
                fields: [
                    .init("session", "\(result.sessionID)"),
                    .init("awaiting", "approval"),
                    .init("tool", pendingApproval.toolCall.name),
                    .init("summary", pendingApproval.preflight.summary),
                ]
            )
        }

        if result.isAwaitingUserInput {
            return block(
                title: "Run suspended",
                fields: [
                    .init("session", "\(result.sessionID)"),
                    .init("awaiting", "user input"),
                ]
            )
        }

        if result.isCompleted {
            return block(
                title: "Run completed",
                fields: [
                    .init("session", "\(result.sessionID)"),
                ],
                body: result.response?.message.content.text ?? "<empty>"
            )
        }

        return block(
            title: "Run result",
            fields: [
                .init("session", "\(result.sessionID)"),
                .init("state", "active"),
            ]
        )
    }

    func render(
        _ event: AgenticInterfaceEvent
    ) -> String {
        switch event {
        case .runStarted(let prompt):
            return block(
                title: "Agentic run",
                fields: [
                    .init("prompt", prompt),
                ]
            )

        case .modeRunStarted(let command):
            var fields: [TerminalField] = [
                .init("mode", command.modeID.rawValue),
                .init("purpose", command.routePurpose.rawValue),
                .init("autonomy", command.autonomyMode.rawValue),
                .init("budget", command.budgetPosture.rawValue),
                .init("approval", command.approvalStrictness.rawValue),
                .init("prompt", command.prompt),
            ]

            if !command.exposedToolNames.isEmpty {
                fields.append(
                    .init(
                        "tools",
                        command.exposedToolNames.joined(separator: ",")
                    )
                )
            }

            if !command.loadedSkillIDs.isEmpty {
                fields.append(
                    .init(
                        "skills",
                        command.loadedSkillIDs.map(\.rawValue).joined(separator: ",")
                    )
                )
            }

            return block(
                title: "Agentic mode run",
                fields: fields
            )

        case .toolCallProposed(let toolCall):
            return block(
                title: "Tool proposed",
                fields: [
                    .init("tool", toolCall.name),
                    .init("id", toolCall.id),
                ]
            )

        case .toolPreflight(let preflight):
            var fields: [TerminalField] = [
                .init("tool", preflight.toolName),
                .init("risk", preflight.risk.rawValue),
                .init("summary", preflight.summary),
            ]

            if !preflight.targetPaths.isEmpty {
                fields.append(
                    .init(
                        "targets",
                        preflight.targetPaths.joined(
                            separator: ", "
                        )
                    )
                )
            }

            return block(
                title: "Tool preflight",
                fields: fields
            )

        case .approvalRequested(let prompt):
            return block(
                title: "Approval required",
                fields: [
                    .init("tool", prompt.toolName),
                    .init("requirement", prompt.requirement.rawValue),
                    .init("risk", prompt.preflight.risk.rawValue),
                    .init("summary", prompt.preflight.summary),
                ]
            )

        case .approvalChoice(let choice):
            guard showsVerboseEvents else {
                return ""
            }

            return block(
                title: "Approval menu choice",
                fields: [
                    .init("choice", choice.rawValue),
                ]
            )

        case .approvalDecision(let decision):
            return block(
                title: "Approval decision",
                fields: [
                    .init("decision", decision.rawValue),
                ]
            )

        case .runStopped(let reason):
            return block(
                title: "Run stopped",
                fields: [
                    .init("reason", reason),
                ]
            )

        case .runCompleted(let summary):
            return block(
                title: "Run completed",
                body: summary
            )
        }
    }

    func block(
        title: String,
        fields: [TerminalField] = [],
        body: String? = nil
    ) -> String {
        TerminalBlock(
            title: title,
            fields: fields,
            body: body,
            theme: theme,
            layout: .agentic
        ).render(
            stream: stream
        )
    }
}

public enum TerminalApprovalPickerError: Error, Sendable, LocalizedError {
    case stoppedRun

    public var errorDescription: String? {
        switch self {
        case .stoppedRun:
            return "The run was stopped from the approval picker."
        }
    }
}

public struct TerminalApprovalPicker: Sendable {
    public var stream: TerminalStream
    public var presenter: (any AgenticRunPresenter)?
    public var theme: TerminalTheme

    public init(
        stream: TerminalStream = .standardError,
        presenter: (any AgenticRunPresenter)? = nil,
        theme: TerminalTheme = .agentic
    ) {
        self.stream = stream
        self.presenter = presenter
        self.theme = theme
    }

    public func pick(
        _ prompt: AgenticApprovalPrompt
    ) async throws -> AgenticApprovalChoice {
        try await presenter?.present(
            .approvalRequested(
                prompt
            )
        )

        while true {
            let choice = try runMenu(
                prompt
            )

            try await presenter?.present(
                .approvalChoice(
                    choice
                )
            )

            switch choice {
            case .inspectDetails:
                renderDetails(
                    prompt
                )

            case .showDiff:
                renderDiff(
                    prompt
                )

            case .approve,
                .deny,
                .stopRun:
                return choice
            }
        }
    }
}
