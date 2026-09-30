import Agentic

public enum AgenticConversationToolSelectionRole:
    Sendable,
    Hashable
{
    case selectable
    case dynamicDiscovery
}

public struct AgenticConversationToolPresentation:
    Sendable,
    Hashable
{
    public var id: ToolIdentifier
    public var title: String
    public var summary: String
    public var selectionRole: AgenticConversationToolSelectionRole

    public init(
        id: ToolIdentifier,
        title: String,
        summary: String,
        selectionRole: AgenticConversationToolSelectionRole = .selectable
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.selectionRole = selectionRole
    }
}

public struct AgenticConversationToolCollectionPresentation:
    Sendable,
    Hashable
{
    public var id: String
    public var title: String
    public var tools: [AgenticConversationToolPresentation]

    public init(
        id: String,
        title: String,
        tools: [AgenticConversationToolPresentation]
    ) {
        self.id = id
        self.title = title
        self.tools = tools
    }
}

public struct AgenticConversationToolSelection:
    Sendable,
    Hashable
{
    public var identifiers: [ToolIdentifier]
    public var dynamicDiscovery: Bool

    public init(
        identifiers: [ToolIdentifier] = [],
        dynamicDiscovery: Bool = true
    ) {
        self.identifiers = identifiers
        self.dynamicDiscovery = dynamicDiscovery
    }
}
