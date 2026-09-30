import Agentic
import AgenticExecution

public struct AgenticApprovalPrompt: Sendable, Codable, Hashable {
    public var title: String
    public var toolCall: ToolCall?
    public var preflight: ToolPreflight
    public var requirement: ApprovalRequirement
    public var review: ToolInvocation.Review?
    public var metadata: [String: String]

    public init(
        title: String? = nil,
        toolCall: ToolCall? = nil,
        preflight: ToolPreflight,
        requirement: ApprovalRequirement,
        review: ToolInvocation.Review? = nil,
        metadata: [String: String] = [:]
    ) {
        self.title = title ?? "Tool approval requested"
        self.toolCall = toolCall
        self.preflight = preflight
        self.requirement = requirement
        self.review = review
        self.metadata = metadata
    }

    public init(
        review: ToolInvocation.Review,
        title: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.init(
            title: title,
            toolCall: review.call,
            preflight: review.preflight,
            requirement: review.requirement,
            review: review,
            metadata: metadata
        )
    }

    public var toolName: String {
        toolCall?.tool.rawValue ?? preflight.tool.rawValue
    }

    public var guidelineReferences: [Reference.Guideline] {
        (review?.references ?? []).compactMap { reference in
            guard case .guideline(let guideline) = reference else {
                return nil
            }

            return guideline
        }
    }
}

