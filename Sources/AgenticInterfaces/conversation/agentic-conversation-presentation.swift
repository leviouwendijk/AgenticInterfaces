import Agentic
import AgenticPrograms

public enum AgenticConversationContentKind: String, Sendable, Hashable {
    case pasted = "pasted_content"
    case transcribed = "transcribed_content"
}

public enum AgenticConversationInputOrigin: String, Sendable, Hashable {
    case typed
    case transcribed
}

public enum AgenticConversationToolExposure:
    String,
    Sendable,
    Hashable,
    CaseIterable
{
    case discovery
    case all
    case skill_seeded
    case custom

    public var title: String {
        switch self {
        case .discovery:
            return "Discovery"

        case .all:
            return "All tools"

        case .skill_seeded:
            return "Skill seeded"

        case .custom:
            return "Custom"
        }
    }
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

public struct AgenticConversationContentPresentation: Sendable, Hashable {
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

public enum AgenticConversationAttachmentPresentation: Sendable, Hashable {
    case content(AgenticConversationContentPresentation)
    case program(AgenticConversationProgramExecutionPresentation)
    case run(runID: String)

    public var id: String {
        switch self {
        case .content(let content):
            return content.id
        case .program(let program):
            return program.id
        case .run(let runID):
            return runID
        }
    }

    public func title(in hostConsole: AgenticHostConsoleSnapshot) -> String {
        switch self {
        case .content(let content):
            return content.title
        case .program(let program):
            return program.title
        case .run(let runID):
            return hostConsole.runs.first { $0.id == runID }?.title ?? "Run"
        }
    }

    public func summary(in hostConsole: AgenticHostConsoleSnapshot) -> String {
        switch self {
        case .content(let content):
            return content.summary
        case .program(let program):
            return "program · \(program.program.rawValue) · \(program.outcome.rawValue)"
        case .run(let runID):
            guard let run = hostConsole.runs.first(where: { $0.id == runID }) else {
                return "run · \(runID) · unavailable"
            }
            return "run · \(runID) · \(run.state.rawValue)"
        }
    }
}

public enum AgenticConversationRunCardTone:
    String,
    Sendable,
    Hashable
{
    case neutral
    case active
    case warning
    case success
    case failure
}

public struct AgenticConversationRunCardPresentation:
    Sendable,
    Hashable
{
    public var title: String
    public var body: String
    public var hint: String
    public var tone: AgenticConversationRunCardTone

    public init(
        title: String,
        body: String,
        hint: String,
        tone: AgenticConversationRunCardTone = .neutral
    ) {
        self.title = title
        self.body = body
        self.hint = hint
        self.tone = tone
    }

    public static func project(
        run: AgenticHostConsoleRunPresentation,
        hostConsole: AgenticHostConsoleSnapshot
    ) -> Self {
        let interruption = hostConsole.interruptions.first { interruption in
            interruption.runID == run.id
        }
        let isTerminal =
            run.state == .completed
                || run.state == .failed
        let step: AgenticHostConsoleStepPresentation?

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

        return Self(
            title: title(
                for: run.state
            ),
            body: body.joined(
                separator: "\n"
            ),
            hint: hint(
                for: run.state,
                interruption: interruption
            ),
            tone: tone(
                for: run.state
            )
        )
    }

    private static func tone(
        for state: AgenticHostConsoleRunState
    ) -> AgenticConversationRunCardTone {
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

        case .failed:
            return .failure
        }
    }

    private static func title(
        for state: AgenticHostConsoleRunState
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

        case .completed:
            return "Run · completed"

        case .failed:
            return "Run · failed"
        }
    }

    private static func hint(
        for state: AgenticHostConsoleRunState,
        interruption: AgenticHostConsoleInterruptionPresentation?
    ) -> String {
        if interruption != nil {
            return "Enter for actions"
        }

        switch state {
        case .completed,
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

public struct AgenticConversationMessagePresentation: Sendable, Hashable {
    public var id: String
    public var role: AgentRole
    public var body: String
    public var attachments: [AgenticConversationAttachmentPresentation]

    public init(
        id: String,
        role: AgentRole,
        body: String,
        attachments: [AgenticConversationAttachmentPresentation] = []
    ) {
        self.id = id
        self.role = role
        self.body = body
        self.attachments = attachments
    }
}

public struct AgenticConversationModelPresentation: Sendable, Hashable {
    public var id: AgentModelProfileIdentifier
    public var title: String
    public var detail: String
    public var isAvailable: Bool
    public var supportsStreaming: Bool

    public init(
        id: AgentModelProfileIdentifier,
        title: String,
        detail: String,
        isAvailable: Bool = true,
        supportsStreaming: Bool = true
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.isAvailable = isAvailable
        self.supportsStreaming = supportsStreaming
    }
}

public struct AgenticConversationSkillPresentation: Sendable, Hashable {
    public var id: AgentSkillIdentifier
    public var title: String
    public var summary: String
    public var toolNames: [String]

    public init(
        id: AgentSkillIdentifier,
        title: String,
        summary: String,
        toolNames: [String]
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.toolNames = toolNames
    }
}

public struct AgenticConversationSubmission: Sendable, Hashable {
    public var body: String
    public var origin: AgenticConversationInputOrigin
    public var contents: [AgenticConversationContentPresentation]
    public var preferredModelProfileID: AgentModelProfileIdentifier
    public var skillIDs: [AgentSkillIdentifier]
    public var toolExposure: AgenticConversationToolExposure
    public var customToolSelection: AgenticConversationToolSelection
    public var responseDelivery: AgentModelResponseDelivery
    public var invocationoptions: AgentModelInvocationOptions
    public var autonomyMode: AutonomyMode

    public init(
        body: String,
        origin: AgenticConversationInputOrigin = .typed,
        contents: [AgenticConversationContentPresentation],
        preferredModelProfileID: AgentModelProfileIdentifier,
        skillIDs: [AgentSkillIdentifier],
        toolExposure: AgenticConversationToolExposure = .discovery,
        customToolSelection: AgenticConversationToolSelection = .init(),
        responseDelivery: AgentModelResponseDelivery = .stream,
        invocationoptions: AgentModelInvocationOptions = .default,
        autonomyMode: AutonomyMode = .auto_observe
    ) {
        self.body = body
        self.origin = origin
        self.contents = contents
        self.preferredModelProfileID = preferredModelProfileID
        self.skillIDs = skillIDs
        self.toolExposure = toolExposure
        self.customToolSelection = customToolSelection
        self.responseDelivery = responseDelivery
        self.invocationoptions = invocationoptions
        self.autonomyMode = autonomyMode
    }
}

public struct AgenticConversationSnapshot: Sendable, Hashable {
    public var title: String
    public var workspace: String
    public var activity: String?
    public var voiceAvailability: AgenticConversationVoice.Availability
    public var voiceState: AgenticConversationVoice.State
    public var voiceStatus: AgenticConversationVoice.Status?
    public var messages: [AgenticConversationMessagePresentation]
    public var models: [AgenticConversationModelPresentation]
    public var programs: [AgentProgramDescriptor]
    public var preferredModelProfileID: AgentModelProfileIdentifier
    public var selectedResponseDelivery: AgentModelResponseDelivery
    public var selectedInvocationOptions: AgentModelInvocationOptions
    public var selectedAutonomyMode: AutonomyMode
    public var skills: [AgenticConversationSkillPresentation]
    public var selectedSkillIDs: [AgentSkillIdentifier]
    public var selectedToolExposure: AgenticConversationToolExposure
    public var toolCollections: [AgenticConversationToolCollectionPresentation]
    public var customToolSelection: AgenticConversationToolSelection
    public var hostConsole: AgenticHostConsoleSnapshot

    public init(
        title: String = "agentic conversation",
        workspace: String,
        activity: String? = nil,
        voiceAvailability: AgenticConversationVoice.Availability = .unconfigured,
        voiceState: AgenticConversationVoice.State = .idle,
        voiceStatus: AgenticConversationVoice.Status? = nil,
        messages: [AgenticConversationMessagePresentation] = [],
        models: [AgenticConversationModelPresentation],
        programs: [AgentProgramDescriptor] = [],
        preferredModelProfileID: AgentModelProfileIdentifier,
        selectedResponseDelivery: AgentModelResponseDelivery = .stream,
        selectedInvocationOptions: AgentModelInvocationOptions = .default,
        selectedAutonomyMode: AutonomyMode = .auto_observe,
        skills: [AgenticConversationSkillPresentation] = [],
        selectedSkillIDs: [AgentSkillIdentifier] = [],
        selectedToolExposure: AgenticConversationToolExposure = .discovery,
        toolCollections: [AgenticConversationToolCollectionPresentation] = [],
        customToolSelection: AgenticConversationToolSelection = .init(),
        hostConsole: AgenticHostConsoleSnapshot = .init()
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
        self.selectedResponseDelivery = selectedResponseDelivery
        self.selectedInvocationOptions = selectedInvocationOptions
        self.selectedAutonomyMode = selectedAutonomyMode
        self.skills = skills
        self.selectedSkillIDs = selectedSkillIDs
        self.selectedToolExposure = selectedToolExposure
        self.toolCollections = toolCollections
        self.customToolSelection = customToolSelection
        self.hostConsole = hostConsole
    }
}