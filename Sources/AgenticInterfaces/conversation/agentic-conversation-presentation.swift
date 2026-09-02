import Agentic

public struct AgenticConversationContentPresentation: Sendable, Hashable {
    public var id: String
    public var title: String
    public var summary: String
    public var body: String

    public init(id: String, title: String, summary: String, body: String) {
        self.id = id
        self.title = title
        self.summary = summary
        self.body = body
    }
}

public enum AgenticConversationAttachmentPresentation: Sendable, Hashable {
    case content(AgenticConversationContentPresentation)
    case run(runID: String)

    public var id: String {
        switch self {
        case .content(let content):
            return content.id
        case .run(let runID):
            return runID
        }
    }

    public func title(in hostConsole: AgenticHostConsoleSnapshot) -> String {
        switch self {
        case .content(let content):
            return content.title
        case .run(let runID):
            return hostConsole.runs.first { $0.id == runID }?.title ?? "Run"
        }
    }

    public func summary(in hostConsole: AgenticHostConsoleSnapshot) -> String {
        switch self {
        case .content(let content):
            return content.summary
        case .run(let runID):
            guard let run = hostConsole.runs.first(where: { $0.id == runID }) else {
                return "run · \(runID) · unavailable"
            }
            return "run · \(runID) · \(run.state.rawValue)"
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

    public init(
        id: AgentModelProfileIdentifier,
        title: String,
        detail: String,
        isAvailable: Bool = true
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.isAvailable = isAvailable
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
    public var contents: [AgenticConversationContentPresentation]
    public var modelProfileID: AgentModelProfileIdentifier
    public var skillIDs: [AgentSkillIdentifier]

    public init(
        body: String,
        contents: [AgenticConversationContentPresentation],
        modelProfileID: AgentModelProfileIdentifier,
        skillIDs: [AgentSkillIdentifier]
    ) {
        self.body = body
        self.contents = contents
        self.modelProfileID = modelProfileID
        self.skillIDs = skillIDs
    }
}

public struct AgenticConversationSnapshot: Sendable, Hashable {
    public var title: String
    public var workspace: String
    public var activity: String?
    public var messages: [AgenticConversationMessagePresentation]
    public var models: [AgenticConversationModelPresentation]
    public var selectedModelProfileID: AgentModelProfileIdentifier
    public var skills: [AgenticConversationSkillPresentation]
    public var selectedSkillIDs: [AgentSkillIdentifier]
    public var hostConsole: AgenticHostConsoleSnapshot

    public init(
        title: String = "agentic conversation",
        workspace: String,
        activity: String? = nil,
        messages: [AgenticConversationMessagePresentation] = [],
        models: [AgenticConversationModelPresentation],
        selectedModelProfileID: AgentModelProfileIdentifier,
        skills: [AgenticConversationSkillPresentation] = [],
        selectedSkillIDs: [AgentSkillIdentifier] = [],
        hostConsole: AgenticHostConsoleSnapshot = .init()
    ) {
        self.title = title
        self.workspace = workspace
        self.activity = activity
        self.messages = messages
        self.models = models
        self.selectedModelProfileID = selectedModelProfileID
        self.skills = skills
        self.selectedSkillIDs = selectedSkillIDs
        self.hostConsole = hostConsole
    }
}
