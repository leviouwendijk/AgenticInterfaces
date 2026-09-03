import Agentic
import AgenticExecution
import Foundation
import Primitives

/// Parses untrusted invocation JSON through the live registered tool universe.
///
/// The raw JSON shape is classified and diagnosed before Codable construction.
/// Every admitted model-facing call is then resolved through ToolRegistry and
/// crosses the typed input parser captured when that tool was registered.
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
        let value: JSONValue

        do {
            value = try JSONCoding.default.decode(
                JSONValue.self,
                from: data
            )
        } catch {
            throw AgenticToolHostJSONError.malformedInvocation(
                error
            )
        }

        let diagnostics = AgenticToolHostInvocationContract.diagnostics(
            value,
            capabilities: registry.capabilities
        )

        guard diagnostics.isEmpty else {
            throw AgenticToolHostJSONError.invalidInvocation(
                diagnostics
            )
        }

        switch value {
        case .array:
            let calls = try JSONCoding.default.decode(
                [AgenticToolHostCall].self,
                from: data
            )

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

        case .object(let object):
            if object["root"] != nil {
                let plan = try JSONCoding.default.decode(
                    AgenticToolHostPlan.self,
                    from: data
                )

                return AgenticToolHostRequest(
                    action: .invoke,
                    plan:
                        try plan.agentToolPlan(
                            registry: registry
                        )
                )
            }

            let invocation = try JSONCoding.default.decode(
                AgenticToolHostDirectInvocation.self,
                from: data
            )
            let parsedCall = try registry.parseModelCall(
                invocation.call
            )

            if invocation.execution != nil,
               parsedCall.capability.execution.workingLocation
                    != .targetable
            {
                throw AgenticToolHostJSONError.invalidInvocation(
                    JSONDiagnostics(
                        [
                            JSONIssue(
                                kind: .invalidValue,
                                path: JSONCodingPath(
                                    [
                                        .key("execution"),
                                        .key("workspace"),
                                    ]
                                ),
                                reason: "Tool '\(parsedCall.call.name)' does not support workspace targeting."
                            ),
                        ]
                    )
                )
            }

            return AgenticToolHostRequest(
                action: .invoke,
                call: parsedCall.call,
                execution:
                    try invocation
                        .execution?
                        .toolExecution()
            )

        default:
            throw AgenticToolHostJSONError.invalidInvocation(
                JSONDiagnostics(
                    [
                        JSONIssue(
                            kind: .typeMismatch,
                            path: JSONCodingPath(),
                            reason: "Expected a direct invocation object, non-empty AgentToolCall array, or AgentToolPlan object."
                        ),
                    ]
                )
            )
        }
    }
}
