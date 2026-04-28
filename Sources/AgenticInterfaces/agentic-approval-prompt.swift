import Agentic

public struct AgenticApprovalPrompt: Sendable, Codable, Hashable {
    public var title: String
    public var toolCall: AgentToolCall?
    public var preflight: ToolPreflight
    public var requirement: ApprovalRequirement
    public var metadata: [String: String]

    public init(
        title: String? = nil,
        toolCall: AgentToolCall? = nil,
        preflight: ToolPreflight,
        requirement: ApprovalRequirement,
        metadata: [String: String] = [:]
    ) {
        self.title = title ?? "Tool approval requested"
        self.toolCall = toolCall
        self.preflight = preflight
        self.requirement = requirement
        self.metadata = metadata
    }

    public init(
        pendingApproval: PendingApproval,
        title: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.init(
            title: title,
            toolCall: pendingApproval.toolCall,
            preflight: pendingApproval.preflight,
            requirement: pendingApproval.requirement,
            metadata: metadata
        )
    }

    public var toolName: String {
        toolCall?.name ?? preflight.toolName
    }
}

