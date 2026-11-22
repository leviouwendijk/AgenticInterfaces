import Agentic
import Foundation

public enum AgenticApprovalChoice: String, Sendable, Codable, Hashable, CaseIterable {
    case approve
    case deny
    case skip
    case inspect_details
    case show_diff
    case stop_run

    public var title: String {
        switch self {
        case .approve:
            return "Approve"

        case .deny:
            return "Deny"

        case .skip:
            return "Skip"

        case .inspect_details:
            return "Inspect details"

        case .show_diff:
            return "Show diff"

        case .stop_run:
            return "Stop run"
        }
    }

    public var summary: String {
        switch self {
        case .approve:
            return "Approve this staged tool call."

        case .deny:
            return "Deny this staged tool call and continue with a denial result."

        case .skip:
            return "Skip this staged tool call without executing it and continue the surrounding work."

        case .inspect_details:
            return "Render the full preflight and staged intent details."

        case .show_diff:
            return "Render the staged diff preview."

        case .stop_run:
            return "Stop this run without approving the staged tool call."
        }
    }

}

public enum AgenticInterfaceEvent: Sendable, Codable, Hashable {
    case runStarted(prompt: String)
    case functionCallProposed(FunctionCall)
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

public enum AgenticRunPresentationState: String, Sendable, Codable, Hashable {
    case active
    case awaiting_approval
    case awaiting_user_input
    case awaiting_run_limit
    case interrupted
    case completed
}

public struct AgenticRunPresentation: Sendable, Codable, Hashable {
    public var sessionID: String
    public var state: AgenticRunPresentationState
    public var toolName: String?
    public var summary: String?
    public var body: String?

    public init(
        sessionID: String,
        state: AgenticRunPresentationState,
        toolName: String? = nil,
        summary: String? = nil,
        body: String? = nil
    ) {
        self.sessionID = sessionID
        self.state = state
        self.toolName = toolName
        self.summary = summary
        self.body = body
    }
}

public protocol AgenticRunPresenter: Sendable {
    func present(
        _ event: AgenticInterfaceEvent
    ) async throws

    func present(
        _ result: AgenticRunPresentation
    ) async throws
}

