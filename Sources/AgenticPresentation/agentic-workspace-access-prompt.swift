public struct AgenticWorkspaceAccessPrompt:
    Sendable,
    Codable,
    Hashable
{
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

    public var title: String
    public var summary: String
    public var fields: [Field]

    public init(
        title: String = "Workspace access requested",
        summary: String,
        fields: [Field] = []
    ) {
        self.title = title
        self.summary = summary
        self.fields = fields
    }
}
