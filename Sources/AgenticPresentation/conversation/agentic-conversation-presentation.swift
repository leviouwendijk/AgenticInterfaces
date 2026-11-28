import Agentic
import Foundation


public enum AgenticConversationContentKind: String, Sendable, Hashable {
    case pasted = "pasted_content"
    case transcribed = "transcribed_content"
}

public enum AgenticConversationInputOrigin: String, Sendable, Hashable {
    case typed
    case transcribed
}

public enum AgenticConversationTranscriptionDisposition:
    String,
    Sendable,
    Hashable
{
    case draft
    case pinned
}

public struct AgenticConversationTranscription: Sendable, Hashable {
    public var text: String
    public var localeIdentifier: String?

    public init(
        text: String,
        localeIdentifier: String? = nil
    ) {
        self.text = text
        self.localeIdentifier = localeIdentifier
    }
}

public struct AgenticConversationContent: Sendable, Hashable {
    public var id: String
    public var kind: AgenticConversationContentKind
    public var title: String
    public var summary: String
    public var body: String

    public init(
        id: String,
        kind: AgenticConversationContentKind = .pasted,
        title: String,
        summary: String,
        body: String
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.summary = summary
        self.body = body
    }
}

public enum AgenticConversationAttachment: Sendable, Hashable {
    case content(AgenticConversationContent)
    case program(AgenticConversationProgramExecution)
    case structured(AgenticConversationStructured)
    case trace(runID: String)
    case run(runID: String)
    case command(AgenticCommandOutcome)
    case change(AgenticChange)

    public var id: String {
        switch self {
        case .content(let content):
            return content.id
        case .program(let program):
            return program.id
        case .structured(let value):
            return value.id
        case .trace(let runID):
            return "trace-" + runID
        case .run(let runID):
            return runID
        case .command(let command):
            return command.id
        case .change(let change):
            return change.id
        }
    }

    public func title(in hostConsole: AgenticHostConsole.Snapshot) -> String {
        switch self {
        case .content(let content):
            return content.title
        case .program(let program):
            return program.title
        case .structured(let value):
            return value.title
        case .trace:
            return "Execution trace"
        case .run(let runID):
            return hostConsole.runs.first { $0.id == runID }?.title ?? "Run"
        case .command(let command):
            return command.transcriptTitle
        case .change(let change):
            return change.transcriptTitle
        }
    }

    public func summary(in hostConsole: AgenticHostConsole.Snapshot) -> String {
        switch self {
        case .content(let content):
            return content.summary
        case .program(let program):
            return "program · \(program.program.rawValue) · \(program.outcome.rawValue)"
        case .structured(let value):
            return value.summary
        case .trace:
            return "recorded iterations and events"
        case .run(let runID):
            guard let run = hostConsole.runs.first(where: { $0.id == runID }) else {
                return "run · \(runID) · unavailable"
            }
            return "run · \(runID) · \(run.state.rawValue)"
        case .command(let command):
            return "command · \(command.isRefused ? "refused" : "done") · \(command.trace.count) traced"
        case .change(let change):
            return "change · \(change.kind.title) · \(change.items.count) items"
        }
    }
}

public struct AgenticConversationRunCard:
    Sendable,
    Hashable
{
    public var title: String
    public var body: String
    public var hint: String
    public var tone: AgenticTone

    public init(
        title: String,
        body: String,
        hint: String,
        tone: AgenticTone = .neutral
    ) {
        self.title = title
        self.body = body
        self.hint = hint
        self.tone = tone
    }

    public static func project(
        run: AgenticHostConsole.Run,
        hostConsole: AgenticHostConsole.Snapshot,
        pendingUserInput: AgenticConversationUserInput? = nil
    ) -> Self {
        if let pendingUserInput,
           pendingUserInput.runID == run.id
        {
            var body = [
                pendingUserInput.request.prompt,
            ]

            if let reason = pendingUserInput.request.reason,
               !reason.isEmpty
            {
                body.append(
                    reason
                )
            }

            return Self(
                title: "Run · awaiting input",
                body: body.joined(
                    separator: "\n"
                ),
                hint: "Enter to answer · r run details",
                tone: .warning
            )
        }

        let interruption = hostConsole.interruptions.first { interruption in
            interruption.runID == run.id
        }
        let isTerminal =
            run.state == .interrupted
                || run.state == .completed
                || run.state == .failed
        let step: AgenticHostConsole.Step?

        if isTerminal {
            step = nil
        } else {
            step =
                interruption.flatMap { interruption in
                    run.steps.first { step in
                        step.id == interruption.stepID
                    }
                }
                ?? run.steps.first { step in
                    step.state == .active
                }
                ?? run.steps.first { step in
                    step.state == .failed
                }
                ?? run.steps.first { step in
                    step.state == .pending
                }
                ?? run.steps.last
        }

        var body: [String] = []

        if let iteration = run.iteration {
            body.append(
                "Iteration \(iteration)"
            )
        }

        if isTerminal,
           !run.steps.isEmpty
        {
            let warningCount = run.steps.filter { step in
                step.state == .warning
            }.count
            var outcome =
                run.steps.count == 1
                    ? "1 step"
                    : "\(run.steps.count) steps"

            if warningCount > 0 {
                outcome +=
                    warningCount == 1
                        ? " · 1 warning"
                        : " · \(warningCount) warnings"
            }

            body.append(
                outcome
            )
        } else if let step,
                  let index = run.steps.firstIndex(where: { candidate in
                      candidate.id == step.id
                  })
        {
            body.append(
                "Stage \(index + 1) of \(run.steps.count) · \(step.title)"
            )
        }

        let delegates = run.agents.count > 1
        if delegates {
            body.append(contentsOf: agentLines(run.agents))
        }

        let summary: String?
        if let interruption {
            summary = interruption.summary
        } else {
            summary = run.summary
        }

        if let summary,
           !summary.isEmpty
        {
            body.append(
                summary
            )
        }

        if body.isEmpty {
            body.append(
                run.title
            )
        }

        body.append(contentsOf: run.notes)

        var cardTitle = title(
            for: run.state
        )
        var cardTone = tone(
            for: run.state
        )
        let workers = run.agents.filter { $0.parentID != nil }
        if delegates, !isTerminal {
            // The root's own state lags while its workers run: it is only
            // republished when the root resumes.
            let reviewing = workers.first {
                $0.state == .awaitingReview || $0.state == .awaitingInput
            }
            let running = workers.filter { $0.state == .running }.count
            if interruption != nil || reviewing != nil {
                cardTitle = "Run · awaiting review"
                    + (reviewing.map { " · " + $0.title } ?? "")
                cardTone = .warning
            } else if running > 0 {
                cardTitle = "Run · running · \(running) of \(workers.count) workers"
                cardTone = .active
            }
        }

        return Self(
            title: cardTitle,
            body: body.joined(
                separator: "\n"
            ),
            hint: hint(
                for: run.state,
                interruption: interruption
            ),
            tone: cardTone
        )
    }

    /// The delegation tree, one line per Agent:
    /// `├ ● implementer  running · deepseek-v4-flash · iteration 3/12`.
    static func agentLines(
        _ agents: [AgenticHostConsole.Agent]
    ) -> [String] {
        // Whether another row at `depth` follows before the tree climbs
        // above it, i.e. whether that level's branch continues.
        func continues(after index: Int, depth: Int) -> Bool {
            for later in agents[(index + 1)...] {
                if later.depth < depth { return false }
                if later.depth == depth { return true }
            }
            return false
        }
        let base = agents.map(\.depth).min() ?? 0
        return agents.indices.map { index in
            let agent = agents[index]
            let depth = agent.depth - base
            var prefix = ""
            if depth > 0 {
                for level in 1..<depth {
                    prefix += continues(after: index, depth: level + base) ? "│ " : "  "
                }
                prefix += continues(after: index, depth: agent.depth) ? "├ " : "└ "
            }
            let usage = agent.usageLine
            return prefix + agent.state.mark + " " + agent.title + "  " + agent.state.title
                + (usage.isEmpty ? "" : " · " + usage)
        }
    }

    private static func tone(
        for state: AgenticHostConsole.Run.State
    ) -> AgenticTone {
        switch state {
        case .ready,
             .pause_pending,
             .paused:
            return .neutral

        case .active:
            return .active

        case .awaitingApproval,
             .onHold:
            return .warning

        case .completed:
            return .success

        case .interrupted:
            return .neutral

        case .failed:
            return .failure
        }
    }

    private static func title(
        for state: AgenticHostConsole.Run.State
    ) -> String {
        switch state {
        case .ready:
            return "Run · ready"

        case .active:
            return "Run · running"

        case .pause_pending:
            return "Run · pause pending"

        case .paused:
            return "Run · paused"

        case .awaitingApproval:
            return "Run · awaiting review"

        case .onHold:
            return "Run · recovery required"

        case .interrupted:
            return "Run · interrupted"

        case .completed:
            return "Run · completed"

        case .failed:
            return "Run · failed"
        }
    }

    private static func hint(
        for state: AgenticHostConsole.Run.State,
        interruption: AgenticHostConsole.Interruption?
    ) -> String {
        if let interruption {
            switch interruption.kind {
            case .approval, .workspace_access, .run_limit:
                return "a review · Enter inspect"
            case .publication:
                return "staged changes · Enter to review"
            case .recovery:
                return "Enter for run details"
            }
        }

        switch state {
        case .interrupted,
             .completed,
             .failed:
            return "Enter for run details"

        case .ready,
             .active,
             .pause_pending,
             .paused,
             .awaitingApproval,
             .onHold:
            return "Enter to inspect"
        }
    }
}

public struct AgenticConversationMessage: Sendable, Hashable {
    public var id: String
    public var role: MessageRole
    public var body: String
    public var attachments: [AgenticConversationAttachment]
    public var iterations: [AgenticConversationIteration]
    /// Accepted but not yet part of a run, and why, e.g. "pending · after
    /// the current run". Cleared once the message is applied.
    public var pending: String?
    /// For an answer: the model that gave it.
    public var route: AgenticModelRoute?

    public init(
        id: String,
        role: MessageRole,
        body: String,
        attachments: [AgenticConversationAttachment] = [],
        iterations: [AgenticConversationIteration] = [],
        pending: String? = nil,
        route: AgenticModelRoute? = nil
    ) {
        self.route = route
        self.id = id
        self.role = role
        self.body = body
        self.attachments = attachments
        self.iterations = iterations
        self.pending = pending
    }
}

/// One workspace root as the conversation shows it.
public struct AgenticWorkspaceRoot: Sendable, Hashable, Identifiable {
    public struct Restriction: Sendable, Hashable, Identifiable {
        public var id: String
        public var pattern: String

        public init(id: String, pattern: String) {
            self.id = id
            self.pattern = pattern
        }
    }

    public var id: String
    public var label: String
    /// The directory, or the single files it grants.
    public var path: String
    /// "list, read, scan · session", or "ask".
    public var access: String
    /// "configured", "added", "model request", "settings".
    public var source: String
    public var isDefault: Bool
    /// Configured roots stay; everything added this session can go.
    public var isRemovable: Bool
    public var restrictions: [Restriction]

    public init(
        id: String,
        label: String,
        path: String,
        access: String,
        source: String,
        isDefault: Bool,
        isRemovable: Bool,
        restrictions: [Restriction] = []
    ) {
        self.id = id
        self.label = label
        self.path = path
        self.access = access
        self.source = source
        self.isDefault = isDefault
        self.isRemovable = isRemovable
        self.restrictions = restrictions
    }
}

/// What a message sent while a run is active does. `:queue` sets it.
public enum AgenticQueuePolicy: String, Sendable, Codable, Hashable, CaseIterable {
    /// Stop the run at the earliest safe boundary, then send.
    case force
    /// Join the run at its next model request (steering).
    case next
    /// Send once the run has settled.
    case await

    /// The pending label of a message held under this policy.
    public var pendingLabel: String {
        switch self {
        case .force: return "pending · stopping the run, then sends"
        case .next: return "pending · next model request"
        case .await: return "pending · after the current run"
        }
    }
}

public struct AgenticConversationModel: Sendable, Hashable {
    public var id: AgentModelProfileIdentifier
    public var title: String
    public var detail: String
    public var isAvailable: Bool
    public var supportsStreaming: Bool
    /// `frontier`, `strong`, … when declared.
    public var tier: String?
    /// Who serves it, e.g. `anthropic_messages`.
    public var provider: String?
    /// Why it cannot be selected here, e.g. "is standard; the role needs at
    /// least strong". Nil when it can.
    public var unavailableReason: String?
    /// False when its provider lacks configuration, such as an API key.
    public var isConfigured: Bool

    public init(
        id: AgentModelProfileIdentifier,
        title: String,
        detail: String,
        isAvailable: Bool = true,
        supportsStreaming: Bool = true,
        tier: String? = nil,
        provider: String? = nil,
        unavailableReason: String? = nil,
        isConfigured: Bool = true
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.isAvailable = isAvailable
        self.supportsStreaming = supportsStreaming
        self.tier = tier
        self.provider = provider
        self.unavailableReason = unavailableReason
        self.isConfigured = isConfigured
    }
}

/// Which model answered, against what was selected.
public struct AgenticModelRoute: Sendable, Hashable {
    public var title: String
    public var provider: String
    /// The selected model's title when the answer came from another one.
    public var selectedTitle: String?
    public var reason: String?

    public init(
        title: String,
        provider: String,
        selectedTitle: String? = nil,
        reason: String? = nil
    ) {
        self.title = title
        self.provider = provider
        self.selectedTitle = selectedTitle
        self.reason = reason
    }

    public var isRerouted: Bool { selectedTitle != nil }
}

public struct AgenticConversationInstruction: Sendable, Hashable {
    public var id: InstructionIdentifier
    public var title: String
    public var summary: String

    public init(id: InstructionIdentifier, title: String, summary: String) {
        self.id = id
        self.title = title
        self.summary = summary
    }
}

public struct AgenticConversationSubmission: Sendable, Hashable {
    /// Identifies the transcript message a queued submission shows as.
    public var id: String
    public var body: String
    public var origin: AgenticConversationInputOrigin
    public var contents: [AgenticConversationContent]
    public var preferredModelProfileID: AgentModelProfileIdentifier
    public var instructionIDs: [InstructionIdentifier]
    public var availableCapabilities: AgentCapabilitySet
    public var visibleCapabilities: AgentCapabilitySet
    public var responseDelivery: AgentModelResponseDelivery
    public var invocationoptions: AgentModelInvocationOptions
    public var autonomyMode: AutonomyMode

    public init(
        body: String,
        origin: AgenticConversationInputOrigin = .typed,
        contents: [AgenticConversationContent],
        preferredModelProfileID: AgentModelProfileIdentifier,
        instructionIDs: [InstructionIdentifier],
        availableCapabilities: AgentCapabilitySet = .none,
        visibleCapabilities: AgentCapabilitySet = .none,
        responseDelivery: AgentModelResponseDelivery = .stream,
        invocationoptions: AgentModelInvocationOptions = .default,
        autonomyMode: AutonomyMode = .auto_observe,
        id: String = UUID().uuidString
    ) {
        self.id = id
        self.body = body
        self.origin = origin
        self.contents = contents
        self.preferredModelProfileID = preferredModelProfileID
        self.instructionIDs = instructionIDs
        self.availableCapabilities = availableCapabilities
        self.visibleCapabilities = visibleCapabilities.intersecting(availableCapabilities)
        self.responseDelivery = responseDelivery
        self.invocationoptions = invocationoptions
        self.autonomyMode = autonomyMode
    }
}

public struct AgenticConversationUserInput: Sendable, Hashable {
    public var interactionID: String
    public var runID: String
    public var request: UserInputRequest

    public init(
        interactionID: String,
        runID: String,
        request: UserInputRequest
    ) {
        self.interactionID = interactionID
        self.runID = runID
        self.request = request
    }
}

public struct AgenticConversationSnapshot: Sendable, Hashable {
    public var title: String
    public var workspace: String
    public var activity: String?
    public var voiceAvailability: AgenticConversationVoice.Availability
    public var voiceState: AgenticConversationVoice.State
    public var voiceStatus: AgenticConversationVoice.Status?
    public var messages: [AgenticConversationMessage]
    public var models: [AgenticConversationModel]
    public var programs: [ProgramDefinition]
    public var preferredModelProfileID: AgentModelProfileIdentifier
    public var pendingUserInput: AgenticConversationUserInput?
    public var selectedResponseDelivery: AgentModelResponseDelivery
    public var selectedInvocationOptions: AgentModelInvocationOptions
    public var selectedAutonomyMode: AutonomyMode
    public var instructions: [AgenticConversationInstruction]
    public var selectedInstructionIDs: [InstructionIdentifier]
    public var capabilityEntries: [AgenticConversationCapabilityEntry]
    public var availableCapabilities: AgentCapabilitySet
    public var visibleCapabilities: AgentCapabilitySet
    public var hostConsole: AgenticHostConsole.Snapshot
    public var usage: AgenticConversationUsage
    /// What a message sent during a run does.
    public var queuePolicy: AgenticQueuePolicy
    /// The session's roots, restrictions included; empty until known.
    public var workspaceRoots: [AgenticWorkspaceRoot] = []
    /// Where relative paths resolve.
    public var workingDirectory: String?
    /// Standing remarks shown under the header, such as a `settings.frame`
    /// that is behind its template.
    public var notices: [String] = []

    public init(
        title: String = "agentic conversation",
        workspace: String,
        activity: String? = nil,
        voiceAvailability: AgenticConversationVoice.Availability = .unconfigured,
        voiceState: AgenticConversationVoice.State = .idle,
        voiceStatus: AgenticConversationVoice.Status? = nil,
        messages: [AgenticConversationMessage] = [],
        models: [AgenticConversationModel],
        programs: [ProgramDefinition] = [],
        preferredModelProfileID: AgentModelProfileIdentifier,
        pendingUserInput: AgenticConversationUserInput? = nil,
        selectedResponseDelivery: AgentModelResponseDelivery = .stream,
        selectedInvocationOptions: AgentModelInvocationOptions = .default,
        selectedAutonomyMode: AutonomyMode = .auto_observe,
        instructions: [AgenticConversationInstruction] = [],
        selectedInstructionIDs: [InstructionIdentifier] = [],
        capabilityEntries: [AgenticConversationCapabilityEntry] = [],
        availableCapabilities: AgentCapabilitySet = .none,
        visibleCapabilities: AgentCapabilitySet = .none,
        hostConsole: AgenticHostConsole.Snapshot = .init(),
        usage: AgenticConversationUsage = .init(),
        queuePolicy: AgenticQueuePolicy = .await
    ) {
        self.title = title
        self.workspace = workspace
        self.activity = activity
        self.voiceAvailability = voiceAvailability
        self.voiceState = voiceState
        self.voiceStatus = voiceStatus
        self.messages = messages
        self.models = models
        self.programs = programs
        self.preferredModelProfileID = preferredModelProfileID
        self.pendingUserInput = pendingUserInput
        self.selectedResponseDelivery = selectedResponseDelivery
        self.selectedInvocationOptions = selectedInvocationOptions
        self.selectedAutonomyMode = selectedAutonomyMode
        self.instructions = instructions
        self.selectedInstructionIDs = selectedInstructionIDs
        self.capabilityEntries = capabilityEntries
        self.availableCapabilities = availableCapabilities
        self.visibleCapabilities = visibleCapabilities.intersecting(availableCapabilities)
        self.hostConsole = hostConsole
        self.usage = usage
        self.queuePolicy = queuePolicy
    }
}
