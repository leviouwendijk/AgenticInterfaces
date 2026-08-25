import Agentic
import Foundation

public enum AgenticToolHostAction: String, Sendable, Codable, Hashable {
    case list
    case describe
    case preflight
    case invoke
}

public struct AgenticToolHostRequest: Sendable, Codable, Hashable {
    public let action: AgenticToolHostAction
    public let name: String?
    public let call: AgentToolCall?

    public init(
        action: AgenticToolHostAction,
        name: String? = nil,
        call: AgentToolCall? = nil
    ) {
        self.action = action
        self.name = name
        self.call = call
    }
}

public struct AgenticToolHostEnvelope: Sendable, Codable, Hashable {
    public let action: AgenticToolHostAction
    public let definitions: [AgentToolDefinition]?
    public let definition: AgentToolDefinition?
    public let review: ToolInvocation.Review?
    public let invocation: ToolInvocation.Result?

    public init(
        action: AgenticToolHostAction,
        definitions: [AgentToolDefinition]? = nil,
        definition: AgentToolDefinition? = nil,
        review: ToolInvocation.Review? = nil,
        invocation: ToolInvocation.Result? = nil
    ) {
        self.action = action
        self.definitions = definitions
        self.definition = definition
        self.review = review
        self.invocation = invocation
    }
}

public enum AgenticToolHostError: Error, LocalizedError, Sendable, Equatable {
    case missingTool(String)
    case missingName(AgenticToolHostAction)
    case missingCall(AgenticToolHostAction)

    public var errorDescription: String? {
        switch self {
        case .missingTool(let name):
            return "No registered Agentic tool named '\(name)'."

        case .missingName(let action):
            return "Tool host action '\(action.rawValue)' requires a tool name."

        case .missingCall(let action):
            return "Tool host action '\(action.rawValue)' requires an AgentToolCall."
        }
    }
}

public struct AgenticToolHost {
    public let registry: ToolRegistry
    public let invoker: ToolInvoker
    public let context: AgentToolExecutionContext
    public let approvalHandler: (any ToolApprovalHandler)?

    public init(
        registry: ToolRegistry,
        policy: ToolExecutionPolicy,
        context: AgentToolExecutionContext = .init(),
        approvalHandler: (any ToolApprovalHandler)? = nil
    ) {
        self.registry = registry
        self.invoker = ToolInvoker(
            registry: registry,
            policy: policy
        )
        self.context = context
        self.approvalHandler = approvalHandler
    }

    public func execute(
        _ request: AgenticToolHostRequest
    ) async throws -> AgenticToolHostEnvelope {
        switch request.action {
        case .list:
            return list()

        case .describe:
            guard let name = request.name else {
                throw AgenticToolHostError.missingName(
                    request.action
                )
            }

            return try describe(
                name
            )

        case .preflight:
            guard let call = request.call else {
                throw AgenticToolHostError.missingCall(
                    request.action
                )
            }

            return try await preflight(
                call
            )

        case .invoke:
            guard let call = request.call else {
                throw AgenticToolHostError.missingCall(
                    request.action
                )
            }

            return try await invoke(
                call
            )
        }
    }

    public func list() -> AgenticToolHostEnvelope {
        .init(
            action: .list,
            definitions: registry.definitions
        )
    }

    public func describe(
        _ name: String
    ) throws -> AgenticToolHostEnvelope {
        guard let definition = registry.definitions.first(
            where: {
                $0.name == name
            }
        ) else {
            throw AgenticToolHostError.missingTool(
                name
            )
        }

        return .init(
            action: .describe,
            definition: definition
        )
    }

    public func preflight(
        _ call: AgentToolCall
    ) async throws -> AgenticToolHostEnvelope {
        let review = try await invoker.review(
            call,
            context: context
        )

        return .init(
            action: .preflight,
            review: review
        )
    }

    public func invoke(
        _ call: AgentToolCall
    ) async throws -> AgenticToolHostEnvelope {
        let invocation = try await invoker.invoke(
            call,
            context: context,
            approvalHandler: approvalHandler
        )

        return .init(
            action: .invoke,
            review: invocation.review,
            invocation: invocation
        )
    }
}
