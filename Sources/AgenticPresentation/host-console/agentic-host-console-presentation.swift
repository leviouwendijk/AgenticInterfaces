import Agentic
import DSL
import Reporting

/// The host console as the interface shows it: runs, steps, agents,
/// interruptions with their actions, documents and status.
public enum AgenticHostConsole {}

extension AgenticHostConsole.Run {
    public enum State:
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
}

extension AgenticHostConsole.Step {
    public enum State:
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
}

extension AgenticHostConsole {
    public struct Field:
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
}

extension AgenticHostConsole {
    public struct Step:
        Sendable,
        Codable,
        Hashable
    {
        public var id: String
        public var title: String
        public var detail: String?
        public var state: AgenticHostConsole.Step.State
        public var fields: [AgenticHostConsole.Field]
        public var groups: [String]

        public init(
            id: String,
            title: String,
            detail: String? = nil,
            state: AgenticHostConsole.Step.State,
            fields: [AgenticHostConsole.Field] = [],
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
}

extension AgenticHostConsole {
    public struct Run:
        Sendable,
        Codable,
        Hashable
    {
        public var id: String
        public var title: String
        public var summary: String?
        public var state: AgenticHostConsole.Run.State
        public var iteration: Int?
        public var steps: [AgenticHostConsole.Step]
        /// The run's Agent and its delegated workers, parents before their
        /// children; empty when the run delegated nothing.
        public var agents: [AgenticHostConsole.Agent]
        /// For a worker's run, the run of the Agent that delegated to it.
        public var parentID: String?
        /// What the session holds besides the run: queued messages, a
        /// requested interrupt, commands issued during it.
        public var notes: [String]

        public init(
            id: String,
            title: String,
            summary: String? = nil,
            state: AgenticHostConsole.Run.State,
            iteration: Int? = nil,
            steps: [AgenticHostConsole.Step] = [],
            agents: [AgenticHostConsole.Agent] = [],
            parentID: String? = nil,
            notes: [String] = []
        ) {
            self.id = id
            self.title = title
            self.summary = summary
            self.state = state
            self.iteration = iteration
            self.steps = steps
            self.agents = agents
            self.parentID = parentID
            self.notes = notes
        }
    }
}

extension AgenticHostConsole.Agent {
    public enum State:
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
}

extension AgenticHostConsole {
    /// One Agent in a run's delegation tree.
    public struct Agent:
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
        public var state: AgenticHostConsole.Agent.State
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
            state: AgenticHostConsole.Agent.State,
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
}

extension AgenticHostConsole.Interruption {
    public enum Kind:
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
}

extension AgenticHostConsole {
    public enum Action:
        Sendable,
        Codable,
        Hashable
    {
        case approve
        case deny
        case skip
        case inspect_details
        case show_diff
        case grant_for_turn
        case grant_for_session
        case continue_run
        case stop_run
        case retry
        case create_fix_branch
        case run_limit_continue(iterations: Int)
        case run_limit_unlimited
        case run_limit_stop
        /// A context pause: compact older results to pointers, then continue.
        case compact_and_continue
        case publish
        case discard
        /// A written change, reviewed: it stays.
        case keep
        /// A written change, reviewed: undone from its recorded pre-image.
        case roll_back

        /// What a staged tool call can be answered with.
        public static let approval: [Action] = [
            .approve,
            .deny,
            .skip,
            .inspect_details,
            .show_diff,
            .stop_run,
        ]

        /// What a workspace access request can be answered with.
        public static let workspaceAccess: [Action] = [
            .grant_for_turn,
            .grant_for_session,
            .deny,
        ]

        public var id: String {
            switch self {
            case .approve:
                return "approve"
            case .deny:
                return "deny"
            case .skip:
                return "skip"
            case .inspect_details:
                return "inspect_details"
            case .show_diff:
                return "show_diff"
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
            case .compact_and_continue:
                return "compact_and_continue"
            case .publish:
                return "publish"
            case .discard:
                return "discard"
            case .keep:
                return "keep"
            case .roll_back:
                return "roll_back"
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

            case .inspect_details:
                return "Inspect details"

            case .show_diff:
                return "Show diff"

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
            case .compact_and_continue:
                return "Compact and continue"
            case .publish:
                return "Publish"
            case .discard:
                return "Discard"
            case .keep:
                return "Keep"
            case .roll_back:
                return "Roll back"
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
            case .inspect_details:
                return "Render the full preflight and staged intent details."
            case .show_diff:
                return "Render the staged diff preview."
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
            case .compact_and_continue:
                return "Replace older tool results with pointers to their preserved copies (one cache miss), then continue the same checkpoint."
            case .publish:
                return "Write the reviewed staged changes to disk."
            case .discard:
                return "Withdraw the reviewed staged changes and release their files."
            case .keep:
                return "Keep the written changes; they leave the review."
            case .roll_back:
                return "Undo the written changes, refused if their files changed since."
            }
        }
    }
}

extension AgenticHostConsole.Document {
    public enum Kind:
        String,
        Sendable,
        Codable,
        Hashable
    {
        case details
        /// What the call would do: a diff, a command, a card. The document's
        /// title comes from the tool's preview sections, e.g. `Event`.
        case preview
        case stdout
        case stderr

        public var title: String {
            switch self {
            case .details:
                return "Details"

            case .preview:
                return "Preview"

            case .stdout:
                return "stdout"

            case .stderr:
                return "stderr"
            }
        }
    }
}

extension AgenticHostConsole {
    public struct Interruption:
        Sendable,
        Codable,
        Hashable
    {
        public var id: String
        public var runID: String
        public var stepID: String
        public var kind: AgenticHostConsole.Interruption.Kind
        public var title: String
        public var summary: String
        public var actions: [AgenticHostConsole.Action]

        public init(
            id: String,
            runID: String,
            stepID: String,
            kind: AgenticHostConsole.Interruption.Kind,
            title: String,
            summary: String,
            actions: [AgenticHostConsole.Action]
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
}

extension AgenticHostConsole {
    public struct Document:
        Sendable,
        Codable,
        Hashable
    {
        public var id: String
        public var runID: String
        public var stepID: String
        public var kind: AgenticHostConsole.Document.Kind
        public var title: String

        /// Canonical raw document text used for copy/export and fallback rendering.
        public var body: String

        /// Optional semantic presentation projected from the canonical source.
        /// Renderers may interpret this at their actual viewport width without
        /// replacing or mutating `body`.
        public var structuredBody: StructuredContent?

        /// Optional typed report; rendered without replacing the canonical body.
        public var reportBody: ReportDocument?

        /// The tool's preview sections, laid out once the viewport's width is known.
        public var previewBody: [ToolPreflight.Preview.Section]?

        /// Text shown above the preview, preserved independently of raw body.
        public var previewPrelude: String?

        /// Read-only nodes supporting in-place trace navigation.
        public var traceRoots: [AgenticHostConsole.Trace.Node]?

        public init(
            id: String,
            runID: String,
            stepID: String,
            kind: AgenticHostConsole.Document.Kind,
            title: String? = nil,
            body: String,
            structuredBody: StructuredContent? = nil,
            traceRoots: [AgenticHostConsole.Trace.Node]? = nil,
            reportBody: ReportDocument? = nil,
            previewBody: [ToolPreflight.Preview.Section]? = nil,
            previewPrelude: String? = nil
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
            self.previewBody = previewBody
            self.previewPrelude = previewPrelude
        }
    }
}

extension AgenticHostConsole {
    public struct Status:
        Sendable,
        Codable,
        Hashable
    {
        public var id: String
        public var runID: String?
        public var stepID: String?
        public var tone: AgenticTone
        public var title: String
        public var summary: String
        public var body: String

        public init(
            id: String,
            runID: String? = nil,
            stepID: String? = nil,
            tone: AgenticTone,
            title: String,
            summary: String,
            body: String
        ) {
            self.id = id
            self.runID = runID
            self.stepID = stepID
            self.tone = tone
            self.title = title
            self.summary = summary
            self.body = body
        }
    }
}

extension AgenticHostConsole {
    public struct Snapshot:
        Sendable,
        Codable,
        Hashable
    {
        public var title: String
        public var context: String?
        public var runs: [AgenticHostConsole.Run]
        public var interruptions: [AgenticHostConsole.Interruption]
        public var documents: [AgenticHostConsole.Document]
        public var statuses: [AgenticHostConsole.Status]

        public init(
            title: String = "agentic host",
            context: String? = nil,
            runs: [AgenticHostConsole.Run] = [],
            interruptions: [AgenticHostConsole.Interruption] = [],
            documents: [AgenticHostConsole.Document] = [],
            statuses: [AgenticHostConsole.Status] = []
        ) {
            self.title = title
            self.context = context
            self.runs = runs
            self.interruptions = interruptions
            self.documents = documents
            self.statuses = statuses
        }
    }
}
