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

    public init(
        id: String,
        title: String,
        detail: String? = nil,
        state: AgenticHostConsoleStepState,
        fields: [AgenticHostConsoleField] = []
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.state = state
        self.fields = fields
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
    public var steps: [AgenticHostConsoleStepPresentation]

    public init(
        id: String,
        title: String,
        summary: String? = nil,
        state: AgenticHostConsoleRunState,
        steps: [AgenticHostConsoleStepPresentation] = []
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.state = state
        self.steps = steps
    }
}

public enum AgenticHostConsoleInterruptionKind:
    String,
    Sendable,
    Codable,
    Hashable
{
    case approval
    case recovery
}

public enum AgenticHostConsoleAction:
    String,
    Sendable,
    Codable,
    Hashable
{
    case approve
    case deny
    case skip
    case continueRun = "continue_run"
    case stopRun = "stop_run"
    case retry
    case createFixBranch = "create_fix_branch"

    public var title: String {
        switch self {
        case .approve:
            return "Approve"

        case .deny:
            return "Deny"

        case .skip:
            return "Skip"

        case .continueRun:
            return "Continue ToolPlan"

        case .stopRun:
            return "Stop"

        case .retry:
            return "Retry"

        case .createFixBranch:
            return "Create Fix Branch"
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

        case .continueRun:
            return "Continue the remaining ToolPlan after the resolved step."

        case .stopRun:
            return "Stop this run."

        case .retry:
            return "Retry the failed step."

        case .createFixBranch:
            return "Create a nested recovery branch for repairing the failed step."
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
    public var body: String

    public init(
        id: String,
        runID: String,
        stepID: String,
        kind: AgenticHostConsoleDocumentKind,
        title: String? = nil,
        body: String
    ) {
        self.id = id
        self.runID = runID
        self.stepID = stepID
        self.kind = kind
        self.title = title ?? kind.title
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

    public init(
        title: String = "agentic host",
        context: String? = nil,
        runs: [AgenticHostConsoleRunPresentation] = [],
        interruptions: [AgenticHostConsoleInterruptionPresentation] = [],
        documents: [AgenticHostConsoleDocumentPresentation] = []
    ) {
        self.title = title
        self.context = context
        self.runs = runs
        self.interruptions = interruptions
        self.documents = documents
    }
}
