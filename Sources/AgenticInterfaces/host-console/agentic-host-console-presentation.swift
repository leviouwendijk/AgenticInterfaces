import Agentic
import DSL
import Reporting

public enum AgenticHostConsoleRunState:
    String,
    Sendable,
    Codable,
    Hashable
{
    case ready
    case active
    case pause_pending
    case paused
    case awaitingApproval
    case onHold
    case interrupted
    case completed
    case failed
}

public enum AgenticHostConsoleStepState:
    String,
    Sendable,
    Codable,
    Hashable
{
    case pending
    case active
    case completed
    case warning
    case failed
    case skipped
}

public struct AgenticHostConsoleField:
    Sendable,
    Codable,
    Hashable
{
    public var label: String
    public var value: String

    public init(
        _ label: String,
        _ value: String
    ) {
        self.label = label
        self.value = value
    }
}

public struct AgenticHostConsoleStepPresentation:
    Sendable,
    Codable,
    Hashable
{
    public var id: String
    public var title: String
    public var detail: String?
    public var state: AgenticHostConsoleStepState
    public var fields: [AgenticHostConsoleField]
    public var groups: [String]

    public init(
        id: String,
        title: String,
        detail: String? = nil,
        state: AgenticHostConsoleStepState,
        fields: [AgenticHostConsoleField] = [],
        groups: [String] = []
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.state = state
        self.fields = fields
        self.groups = groups
    }
}

public struct AgenticHostConsoleRunPresentation:
    Sendable,
    Codable,
    Hashable
{
    public var id: String
    public var title: String
    public var summary: String?
    public var state: AgenticHostConsoleRunState
    public var iteration: Int?
    public var steps: [AgenticHostConsoleStepPresentation]
    /// The run's Agent and its delegated workers, parents before their
    /// children; empty when the run delegated nothing.
    public var agents: [AgenticHostConsoleAgentPresentation]
    /// For a worker's run, the run of the Agent that delegated to it.
    public var parentID: String?

    public init(
        id: String,
        title: String,
        summary: String? = nil,
        state: AgenticHostConsoleRunState,
        iteration: Int? = nil,
        steps: [AgenticHostConsoleStepPresentation] = [],
        agents: [AgenticHostConsoleAgentPresentation] = [],
        parentID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.state = state
        self.iteration = iteration
        self.steps = steps
        self.agents = agents
        self.parentID = parentID
    }
}

public enum AgenticHostConsoleAgentState:
    String,
    Sendable,
    Codable,
    Hashable
{
    case queued
    case running
    /// Suspended until its own workers settle.
    case waiting
    case awaitingReview
    case awaitingInput
    case completed
    case interrupted
    case failed

    public var mark: String {
        switch self {
        case .queued: "○"
        case .running: "●"
        case .waiting: "◌"
        case .awaitingReview, .awaitingInput: "!"
        case .completed: "✓"
        case .interrupted: "■"
        case .failed: "✗"
        }
    }

    public var title: String {
        switch self {
        case .queued: "queued"
        case .running: "running"
        case .waiting: "waiting on workers"
        case .awaitingReview: "awaiting review"
        case .awaitingInput: "awaiting input"
        case .completed: "done"
        case .interrupted: "interrupted"
        case .failed: "failed"
        }
    }

    public var isSettled: Bool {
        switch self {
        case .completed, .interrupted, .failed: true
        default: false
        }
    }
}

/// One Agent in a run's delegation tree.
public struct AgenticHostConsoleAgentPresentation:
    Sendable,
    Codable,
    Hashable,
    Identifiable
{
    /// The Agent's session; the root's is the run's.
    public var id: String
    public var parentID: String?
    public var depth: Int
    public var title: String
    public var state: AgenticHostConsoleAgentState
    /// What it was asked to do, e.g. a worker's requested scope.
    public var detail: String?
    /// The model its latest turn was sent to.
    public var model: String?
    /// Its current iteration out of its own run limit.
    public var iteration: Int?
    public var iterationLimit: Int?
    /// What it has cost so far, e.g. `0.0123 USD`.
    public var cost: String?

    public init(
        id: String,
        parentID: String?,
        depth: Int,
        title: String,
        state: AgenticHostConsoleAgentState,
        detail: String? = nil,
        model: String? = nil,
        iteration: Int? = nil,
        iterationLimit: Int? = nil,
        cost: String? = nil
    ) {
        self.id = id
        self.parentID = parentID
        self.depth = depth
        self.title = title
        self.state = state
        self.detail = detail
        self.model = model
        self.iteration = iteration
        self.iterationLimit = iterationLimit
        self.cost = cost
    }

    /// `deepseek-v4-flash · iteration 3/12 · 0.0021 USD`
    public var usageLine: String {
        var parts: [String] = []
        if let model { parts.append(model) }
        if let iteration {
            parts.append("iteration \(iteration)" + (iterationLimit.map { "/\($0)" } ?? ""))
        }
        if let cost { parts.append(cost) }
        return parts.joined(separator: " · ")
    }
}

public enum AgenticHostConsoleInterruptionKind:
    String,
    Sendable,
    Codable,
    Hashable
{
    case approval
    case workspace_access
    case recovery
    case run_limit
    /// Changes staged by finished work, awaiting publication.
    case publication
}

public enum AgenticHostConsoleAction:
    Sendable,
    Codable,
    Hashable
{
    case approve
    case deny
    case skip
    case grant_for_turn
    case grant_for_session
    case continue_run
    case stop_run
    case retry
    case create_fix_branch
    case run_limit_continue(iterations: Int)
    case run_limit_unlimited
    case run_limit_stop
    case publish
    case discard

    public var id: String {
        switch self {
        case .approve:
            return "approve"
        case .deny:
            return "deny"
        case .skip:
            return "skip"
        case .grant_for_turn:
            return "grant_for_turn"
        case .grant_for_session:
            return "grant_for_session"
        case .continue_run:
            return "continue_run"
        case .stop_run:
            return "stop_run"
        case .retry:
            return "retry"
        case .create_fix_branch:
            return "create_fix_branch"
        case .run_limit_continue(let iterations):
            return "run_limit_continue:\(iterations)"
        case .run_limit_unlimited:
            return "run_limit_unlimited"
        case .run_limit_stop:
            return "run_limit_stop"
        case .publish:
            return "publish"
        case .discard:
            return "discard"
        }
    }

    public var title: String {
        switch self {
        case .approve:
            return "Approve"

        case .deny:
            return "Deny"

        case .skip:
            return "Skip"

        case .grant_for_turn:
            return "This turn"

        case .grant_for_session:
            return "This session"
        case .continue_run:
            return "Continue ToolPlan"
        case .stop_run:
            return "Stop"
        case .retry:
            return "Retry"
        case .create_fix_branch:
            return "Create Fix Branch"
        case .run_limit_continue(let iterations):
            return "Continue to \(iterations) iterations"
        case .run_limit_unlimited:
            return "Remove iteration limit"
        case .run_limit_stop:
            return "Stop run"
        case .publish:
            return "Publish"
        case .discard:
            return "Discard"
        }
    }

    public var summary: String {
        switch self {
        case .approve:
            return "Approve the suspended operation and continue."
        case .deny:
            return "Deny the suspended operation."
        case .skip:
            return "Skip the suspended step and continue when the runtime permits it."
        case .grant_for_turn:
            return "Grant the requested workspace access until the current turn ends."
        case .grant_for_session:
            return "Grant the requested workspace access for the current session."
        case .continue_run:
            return "Continue the remaining ToolPlan after the resolved step."
        case .stop_run:
            return "Stop this run."
        case .retry:
            return "Retry the failed step."
        case .create_fix_branch:
            return "Create a nested recovery branch for repairing the failed step."
        case .run_limit_continue(let iterations):
            return "Replace the run iteration limit with \(iterations) and continue the same checkpoint."
        case .run_limit_unlimited:
            return "Remove the iteration limit and continue the same checkpoint."
        case .run_limit_stop:
            return "Stop this run without converting the limit into a failure."
        case .publish:
            return "Write the reviewed staged changes to disk."
        case .discard:
            return "Withdraw the reviewed staged changes and release their files."
        }
    }
}

public enum AgenticHostConsoleDocumentKind:
    String,
    Sendable,
    Codable,
    Hashable
{
    case details
    case diff
    case stdout
    case stderr

    public var title: String {
        switch self {
        case .details:
            return "Details"

        case .diff:
            return "Diff"

        case .stdout:
            return "stdout"

        case .stderr:
            return "stderr"
        }
    }
}

public struct AgenticHostConsoleInterruptionPresentation:
    Sendable,
    Codable,
    Hashable
{
    public var id: String
    public var runID: String
    public var stepID: String
    public var kind: AgenticHostConsoleInterruptionKind
    public var title: String
    public var summary: String
    public var actions: [AgenticHostConsoleAction]

    public init(
        id: String,
        runID: String,
        stepID: String,
        kind: AgenticHostConsoleInterruptionKind,
        title: String,
        summary: String,
        actions: [AgenticHostConsoleAction]
    ) {
        self.id = id
        self.runID = runID
        self.stepID = stepID
        self.kind = kind
        self.title = title
        self.summary = summary
        self.actions = actions
    }
}

public struct AgenticHostConsoleDocumentPresentation:
    Sendable,
    Codable,
    Hashable
{
    public var id: String
    public var runID: String
    public var stepID: String
    public var kind: AgenticHostConsoleDocumentKind
    public var title: String

    /// Canonical raw document text used for copy/export and fallback rendering.
    public var body: String

    /// Optional semantic presentation projected from the canonical source.
    /// Renderers may interpret this at their actual viewport width without
    /// replacing or mutating `body`.
    public var structuredBody: StructuredContent?

    /// Optional typed report; rendered without replacing the canonical body.
    public var reportBody: ReportDocument?

    /// Semantic diff retained until the enclosing viewport establishes its width.
    public var differenceBody: ToolPreflight.Preview.Difference?

    /// Text shown above the semantic diff, preserved independently of raw body.
    public var differencePrelude: String?

    /// Read-only nodes supporting in-place trace navigation.
    public var traceRoots: [AgenticHostConsoleTraceNode]?

    public init(
        id: String,
        runID: String,
        stepID: String,
        kind: AgenticHostConsoleDocumentKind,
        title: String? = nil,
        body: String,
        structuredBody: StructuredContent? = nil,
        traceRoots: [AgenticHostConsoleTraceNode]? = nil,
        reportBody: ReportDocument? = nil,
        differenceBody: ToolPreflight.Preview.Difference? = nil,
        differencePrelude: String? = nil
    ) {
        self.id = id
        self.runID = runID
        self.stepID = stepID
        self.kind = kind
        self.title = title ?? kind.title
        self.body = body
        self.structuredBody = structuredBody
        self.traceRoots = traceRoots
        self.reportBody = reportBody
        self.differenceBody = differenceBody
        self.differencePrelude = differencePrelude
    }
}

public enum AgenticHostConsoleStatusKind:
    String,
    Sendable,
    Codable,
    Hashable
{
    case info
    case warning
    case error
}

public struct AgenticHostConsoleStatusPresentation:
    Sendable,
    Codable,
    Hashable
{
    public var id: String
    public var runID: String?
    public var stepID: String?
    public var kind: AgenticHostConsoleStatusKind
    public var title: String
    public var summary: String
    public var body: String

    public init(
        id: String,
        runID: String? = nil,
        stepID: String? = nil,
        kind: AgenticHostConsoleStatusKind,
        title: String,
        summary: String,
        body: String
    ) {
        self.id = id
        self.runID = runID
        self.stepID = stepID
        self.kind = kind
        self.title = title
        self.summary = summary
        self.body = body
    }
}

public struct AgenticHostConsoleSnapshot:
    Sendable,
    Codable,
    Hashable
{
    public var title: String
    public var context: String?
    public var runs: [AgenticHostConsoleRunPresentation]
    public var interruptions: [AgenticHostConsoleInterruptionPresentation]
    public var documents: [AgenticHostConsoleDocumentPresentation]
    public var statuses: [AgenticHostConsoleStatusPresentation]

    public init(
        title: String = "agentic host",
        context: String? = nil,
        runs: [AgenticHostConsoleRunPresentation] = [],
        interruptions: [AgenticHostConsoleInterruptionPresentation] = [],
        documents: [AgenticHostConsoleDocumentPresentation] = [],
        statuses: [AgenticHostConsoleStatusPresentation] = []
    ) {
        self.title = title
        self.context = context
        self.runs = runs
        self.interruptions = interruptions
        self.documents = documents
        self.statuses = statuses
    }
}
