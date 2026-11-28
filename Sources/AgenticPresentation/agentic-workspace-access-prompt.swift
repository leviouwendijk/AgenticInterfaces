public struct AgenticWorkspaceAccessPrompt:
    Sendable,
    Codable,
    Hashable
{
    public var title: String
    public var summary: String
    public var fields: [AgenticHostConsole.Field]

    public init(
        title: String = "Workspace access requested",
        summary: String,
        fields: [AgenticHostConsole.Field] = []
    ) {
        self.title = title
        self.summary = summary
        self.fields = fields
    }
}
