import Agentic
import AgenticExecution
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
    public let calls: [AgentToolCall]?
    public let plan: AgentToolPlan?

    public init(
        action: AgenticToolHostAction,
        name: String? = nil,
        call: AgentToolCall? = nil,
        calls: [AgentToolCall]? = nil,
        plan: AgentToolPlan? = nil
    ) {
        self.action = action
        self.name = name
        self.call = call
        self.calls = calls
        self.plan = plan
    }
}

public struct AgenticToolHostEnvelope: Sendable, Codable, Hashable {
    public let action: AgenticToolHostAction
    public let definitions: [AgentToolDefinition]?
    public let definition: AgentToolDefinition?
    public let review: ToolInvocation.Review?
    public let invocation: ToolInvocation.Result?
    public let planResult: AgentToolPlanResult?

    public init(
        action: AgenticToolHostAction,
        definitions: [AgentToolDefinition]? = nil,
        definition: AgentToolDefinition? = nil,
        review: ToolInvocation.Review? = nil,
        invocation: ToolInvocation.Result? = nil,
        planResult: AgentToolPlanResult? = nil
    ) {
        self.action = action
        self.definitions = definitions
        self.definition = definition
        self.review = review
        self.invocation = invocation
        self.planResult = planResult
    }
}

public enum AgenticToolHostError: Error, LocalizedError, Sendable, Equatable {
    case missingTool(String)
    case missingName(AgenticToolHostAction)
    case missingCall(AgenticToolHostAction)
    case invalidInvocationPayload(String)

    public var errorDescription: String? {
        switch self {
        case .missingTool(let name):
            return "No registered Agentic tool named '\(name)'."

        case .missingName(let action):
            return "Tool host action '\(action.rawValue)' requires a tool name."

        case .missingCall(let action):
            return "Tool host action '\(action.rawValue)' requires an AgentToolCall."

        case .invalidInvocationPayload(let message):
            return message
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
            return try await invokePayload(
                request
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

    public func invoke(
        _ calls: [AgentToolCall]
    ) async throws -> AgenticToolHostEnvelope {
        guard !calls.isEmpty else {
            throw AgenticToolHostError.invalidInvocationPayload(
                "Tool host batch invocation requires at least one AgentToolCall."
            )
        }

        return try await invoke(
            AgentToolPlan(
                root: .batch(
                    calls.map {
                        .call(
                            $0
                        )
                    }
                )
            )
        )
    }

    public func invoke(
        _ plan: AgentToolPlan
    ) async throws -> AgenticToolHostEnvelope {
        let result = try await invoker.invoke(
            plan,
            context: context,
            approvalHandler: approvalHandler
        )

        return .init(
            action: .invoke,
            planResult: result
        )
    }
}

private extension AgenticToolHost {
    func invokePayload(
        _ request: AgenticToolHostRequest
    ) async throws -> AgenticToolHostEnvelope {
        let payloadCount = [
            request.call != nil,
            request.calls != nil,
            request.plan != nil,
        ].filter {
            $0
        }.count

        guard payloadCount == 1 else {
            throw AgenticToolHostError.invalidInvocationPayload(
                "Tool host invoke requires exactly one of call, calls, or plan."
            )
        }

        if let call = request.call {
            return try await invoke(
                call
            )
        }

        if let calls = request.calls {
            return try await invoke(
                calls
            )
        }

        if let plan = request.plan {
            return try await invoke(
                plan
            )
        }

        throw AgenticToolHostError.invalidInvocationPayload(
            "Tool host invoke requires an AgentToolCall, call batch, or AgentToolPlan."
        )
    }
}
