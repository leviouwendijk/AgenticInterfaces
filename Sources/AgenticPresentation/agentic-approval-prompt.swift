import Agentic

public struct AgenticApprovalPrompt: Sendable, Codable, Hashable {
    public var title: String
    public var functionCall: FunctionCall?
    public var preflight: ToolPreflight
    public var requirement: ApprovalRequirement
    public var review: ToolInvocation.Review?
    public var metadata: [String: String]

    public init(
        title: String? = nil,
        functionCall: FunctionCall? = nil,
        preflight: ToolPreflight,
        requirement: ApprovalRequirement,
        review: ToolInvocation.Review? = nil,
        metadata: [String: String] = [:]
    ) {
        self.title = title ?? "Tool approval requested"
        self.functionCall = functionCall
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
            functionCall: FunctionCall(
                id: review.invocation.id,
                name: review.invocation.tool.rawValue,
                input: review.invocation.arguments
            ),
            preflight: review.preflight,
            requirement: review.requirement,
            review: review,
            metadata: metadata
        )
    }

    public var toolName: String {
        functionCall?.name ?? preflight.tool.rawValue
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

