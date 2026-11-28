import Agentic
import Foundation

public enum AgenticInterfaceEvent: Sendable, Codable, Hashable {
    case runStarted(prompt: String)
    case functionCallProposed(FunctionCall)
    case toolPreflight(ToolPreflight)
    case approvalRequested(AgenticApprovalPrompt)
    case approvalChoice(AgenticHostConsole.Action)
    case approvalDecision(ApprovalDecision)
    case runStopped(reason: String)
    case runCompleted(summary: String)
}

public protocol AgenticInterfaceEventSink: Sendable {
    func record(
        _ event: AgenticInterfaceEvent
    ) async throws
}

extension AgenticRun {
    public enum State: String, Sendable, Codable, Hashable {
        case active
        case awaiting_approval
        case awaiting_user_input
        case awaiting_run_limit
        case interrupted
        case completed
    }
}

public struct AgenticRun: Sendable, Codable, Hashable {
    public var sessionID: String
    public var state: AgenticRun.State
    public var toolName: String?
    public var summary: String?
    public var body: String?

    public init(
        sessionID: String,
        state: AgenticRun.State,
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
        _ result: AgenticRun
    ) async throws
}

