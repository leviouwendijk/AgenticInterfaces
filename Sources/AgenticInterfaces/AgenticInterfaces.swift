import Agentic
import Foundation
import Terminal
import Difference
import DifferenceTerminal

public struct AgenticApprovalPrompt: Sendable, Codable, Hashable {
    public var title: String
    public var toolCall: AgentToolCall?
    public var preflight: ToolPreflight
    public var requirement: ApprovalRequirement
    public var metadata: [String: String]

    public init(
        title: String? = nil,
        toolCall: AgentToolCall? = nil,
        preflight: ToolPreflight,
        requirement: ApprovalRequirement,
        metadata: [String: String] = [:]
    ) {
        self.title = title ?? "Tool approval requested"
        self.toolCall = toolCall
        self.preflight = preflight
        self.requirement = requirement
        self.metadata = metadata
    }

    public init(
        pendingApproval: PendingApproval,
        title: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.init(
            title: title,
            toolCall: pendingApproval.toolCall,
            preflight: pendingApproval.preflight,
            requirement: pendingApproval.requirement,
            metadata: metadata
        )
    }

    public var toolName: String {
        toolCall?.name ?? preflight.toolName
    }
}

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

    public init(
        stream: TerminalStream = .standardError,
        sinks: [any AgenticInterfaceEventSink] = []
    ) {
        self.stream = stream
        self.sinks = sinks
    }

    public func present(
        _ event: AgenticInterfaceEvent
    ) async throws {
        for sink in sinks {
            try await sink.record(
                event
            )
        }

        Terminal.write(
            render(
                event
            ),
            to: stream
        )
    }

    public func present(
        _ result: AgentRunResult
    ) async throws {
        let rendered: String

        if let pendingApproval = result.pendingApproval {
            rendered = """
            run suspended

            session: \(result.sessionID)
            awaiting: approval
            tool: \(pendingApproval.toolCall.name)
            summary: \(pendingApproval.preflight.summary)

            """
        } else if result.isAwaitingUserInput {
            rendered = """
            run suspended

            session: \(result.sessionID)
            awaiting: user input

            """
        } else if result.isCompleted {
            rendered = """
            run completed

            session: \(result.sessionID)
            response: \(result.response?.message.content.text ?? "<empty>")

            """
        } else {
            rendered = """
            run result

            session: \(result.sessionID)
            state: active

            """
        }

        Terminal.write(
            rendered,
            to: stream
        )
    }
}

private extension TerminalAgenticRunPresenter {
    func render(
        _ event: AgenticInterfaceEvent
    ) -> String {
        switch event {
        case .runStarted(let prompt):
            return """
            agentic run started

            prompt: \(prompt)

            """

        case .toolCallProposed(let toolCall):
            return """
            model proposed tool call

            tool: \(toolCall.name)
            id: \(toolCall.id)

            """

        case .toolPreflight(let preflight):
            return """
            tool preflight

            tool: \(preflight.toolName)
            risk: \(preflight.risk.rawValue)
            summary: \(preflight.summary)

            """

        case .approvalRequested(let prompt):
            return """
            approval requested

            tool: \(prompt.toolName)
            requirement: \(prompt.requirement.rawValue)
            summary: \(prompt.preflight.summary)

            """

        case .approvalChoice(let choice):
            return """
            approval menu choice

            choice: \(choice.rawValue)

            """

        case .approvalDecision(let decision):
            return """
            approval decision

            decision: \(decision.rawValue)

            """

        case .runStopped(let reason):
            return """
            run stopped

            reason: \(reason)

            """

        case .runCompleted(let summary):
            return """
            run completed

            \(summary)

            """
        }
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

    public init(
        stream: TerminalStream = .standardError,
        presenter: (any AgenticRunPresenter)? = nil
    ) {
        self.stream = stream
        self.presenter = presenter
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

extension TerminalApprovalPicker: ToolApprovalHandler {
    public func decide(
        on preflight: ToolPreflight,
        requirement: ApprovalRequirement
    ) async throws -> ApprovalDecision {
        if requirement.isDenied {
            return .denied
        }

        if !requirement.requiresHumanReview {
            return .approved
        }

        let choice = try await pick(
            AgenticApprovalPrompt(
                preflight: preflight,
                requirement: requirement
            )
        )

        switch choice {
        case .approve:
            return .approved

        case .deny:
            return .denied

        case .stopRun:
            throw TerminalApprovalPickerError.stoppedRun

        case .inspectDetails,
             .showDiff:
            return .needshuman
        }
    }
}

private extension TerminalApprovalPicker {
    func runMenu(
        _ prompt: AgenticApprovalPrompt
    ) throws -> AgenticApprovalChoice {
        let menu = TerminalInteractiveMenu<AgenticApprovalChoice, String>(
            items: AgenticApprovalChoice.allCases,
            configuration: .inline(
                title: "\(prompt.title): \(prompt.toolName)",
                instructions: "Move with Ctrl-P/Ctrl-N or arrows. Enter picks. q/Esc stops.",
                outputStream: stream,
                completionPresentation: .leaveSummary
            ),
            id: { choice in
                choice.rawValue
            },
            row: { row in
                let cursor = row.isCurrent ? ">" : " "
                return "\(cursor) \(row.item.title) — \(row.item.summary)\n"
            },
            summary: { result in
                switch result {
                case .picked(let item, _):
                    return "selected: \(item.title)\n"

                case .cancelled:
                    return "selected: Stop run\n"
                }
            }
        )

        switch try menu.run() {
        case .picked(let item, _):
            return item

        case .cancelled:
            return .stopRun
        }
    }

    func renderDetails(
        _ prompt: AgenticApprovalPrompt
    ) {
        let preflight = prompt.preflight
        var lines: [String] = [
            "",
            "staged intent details",
            "",
            "title: \(prompt.title)",
            "tool: \(prompt.toolName)",
            "requirement: \(prompt.requirement.rawValue)",
            "risk: \(preflight.risk.rawValue)",
            "summary: \(preflight.summary)"
        ]

        if let toolCall = prompt.toolCall {
            lines.append(
                "tool call id: \(toolCall.id)"
            )
        }

        if let workspaceRoot = preflight.workspaceRoot {
            lines.append(
                "workspace: \(workspaceRoot)"
            )
        }

        if !preflight.rootIDs.isEmpty {
            lines.append(
                "roots: \(preflight.rootIDs.joined(separator: ", "))"
            )
        }

        if !preflight.capabilitiesRequired.isEmpty {
            lines.append(
                "capabilities: \(preflight.capabilitiesRequired.map(\.rawValue).joined(separator: ", "))"
            )
        }

        if !preflight.targetPaths.isEmpty {
            lines.append(
                "targets: \(preflight.targetPaths.joined(separator: ", "))"
            )
        }

        if let commandPreview = preflight.commandPreview {
            lines.append(
                "command: \(commandPreview)"
            )
        }

        if let diffPreview = preflight.diffPreview {
            lines.append(
                "diff preview: \(diffPreview.insertedLineCount) insertions, \(diffPreview.deletedLineCount) deletions, context \(diffPreview.contextLineCount)"
            )
        }

        if preflight.estimatedWriteCount > 0 {
            lines.append(
                "estimated writes: \(preflight.estimatedWriteCount)"
            )
        }

        if let estimatedByteCount = preflight.estimatedByteCount {
            lines.append(
                "estimated bytes: \(estimatedByteCount)"
            )
        }

        if let estimatedRuntimeSeconds = preflight.estimatedRuntimeSeconds {
            lines.append(
                "estimated runtime seconds: \(estimatedRuntimeSeconds)"
            )
        }

        if !preflight.sideEffects.isEmpty {
            lines.append(
                "side effects:"
            )

            lines.append(
                contentsOf: preflight.sideEffects.map {
                    "    - \($0)"
                }
            )
        }

        if !preflight.warnings.isEmpty {
            lines.append(
                "warnings:"
            )

            lines.append(
                contentsOf: preflight.warnings.map {
                    "    - \($0)"
                }
            )
        }

        lines.append(
            ""
        )

        Terminal.write(
            lines.joined(
                separator: "\n"
            ),
            to: stream
        )
    }

    func renderDiff(
        _ prompt: AgenticApprovalPrompt
    ) {
        guard let diffPreview = prompt.preflight.diffPreview,
              !diffPreview.isEmpty
        else {
            Terminal.write(
                """

                no diff preview available

                """,
                to: stream
            )

            return
        }

        let renderedDiff: String

        if let layout = diffPreview.layout {
            renderedDiff = DifferenceRenderer.Terminal.render(
                layout,
                options: .init(
                    base: .init(
                        showHeader: true,
                        showUnchangedLines: false,
                        contextLineCount: diffPreview.contextLineCount
                    )
                )
            )
        } else {
            renderedDiff = diffPreview.text
        }

        Terminal.write(
            """

            \(diffPreview.title ?? "diff preview")
            format: \(diffPreview.format)
            context lines: \(diffPreview.contextLineCount)
            changes: +\(diffPreview.insertedLineCount) -\(diffPreview.deletedLineCount)

            \(renderedDiff)

            """,
            to: stream
        )
    }
}
