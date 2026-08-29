import Agentic
import AgenticExecution
import Foundation

/// Parses untrusted invocation JSON through the live registered tool universe.
///
/// Codable establishes the wire variant. Every model-facing call is then
/// resolved through ToolRegistry and crosses the typed input parser captured
/// when that tool was registered.
public struct AgenticToolHostInvocationParser:
    Sendable
{
    public let registry: ToolRegistry

    public init(
        registry: ToolRegistry
    ) {
        self.registry = registry
    }

    public func parse(
        _ data: Data
    ) throws -> AgenticToolHostRequest {
        let decoder = JSONDecoder()

        if let invocation =
            try? decoder.decode(
                AgenticToolHostDirectInvocation.self,
                from: data
            )
        {
            let parsedCall = try registry
                .parseModelCall(
                    invocation.call
                )

            if invocation.execution != nil,
               !parsedCall
                    .capability
                    .supportsWorkspaceTargeting
            {
                throw AgenticToolHostJSONError
                    .invalidInvocationRequest
            }

            return AgenticToolHostRequest(
                action: .invoke,
                call: parsedCall.call,
                execution:
                    try invocation
                        .execution?
                        .toolExecution()
            )
        }

        if let calls =
            try? decoder.decode(
                [AgenticToolHostCall].self,
                from: data
            ),
           !calls.isEmpty
        {
            return AgenticToolHostRequest(
                action: .invoke,
                calls:
                    try calls.map {
                        try registry
                            .parseModelCall(
                                $0.agentToolCall
                            )
                            .call
                    }
            )
        }

        if let plan =
            try? decoder.decode(
                AgenticToolHostPlan.self,
                from: data
            )
        {
            return AgenticToolHostRequest(
                action: .invoke,
                plan:
                    try plan.agentToolPlan(
                        registry: registry
                    )
            )
        }

        throw AgenticToolHostJSONError
            .invalidInvocationRequest
    }
}
