import Agentic
import AgenticExecution
import Foundation
import Primitives
import Schema

public enum AgenticToolHostJSON {
    public static func decodeRequest(
        _ data: Data
    ) throws -> AgenticToolHostRequest {
        try JSONDecoder().decode(
            AgenticToolHostRequest.self,
            from: data
        )
    }

    /// Decode only the canonical invocation forms advertised by the capability manifest.
    public static func decodeInvocationRequest(
        _ data: Data
    ) throws -> AgenticToolHostRequest {
        let decoder = JSONDecoder()

        if let invocation = try? decoder.decode(
            AgenticToolHostDirectInvocation.self,
            from: data
        ) {
            return .init(
                action: .invoke,
                call: invocation.call,
                execution: try invocation.execution?.toolExecution()
            )
        }

        if let calls = try? decoder.decode(
            [AgenticToolHostCall].self,
            from: data
        ), !calls.isEmpty {
            return .init(
                action: .invoke,
                calls: calls.map(\.agentToolCall)
            )
        }

        if let plan = try? decoder.decode(
            AgenticToolHostPlan.self,
            from: data
        ) {
            return .init(
                action: .invoke,
                plan: try plan.agentToolPlan()
            )
        }

        throw AgenticToolHostJSONError.invalidInvocationRequest
    }

    /// Decode and validate the raw envelope against the exact live registry schema.
    public static func decodeInvocationRequest(
        _ data: Data,
        capabilities: [AgentToolCapability]
    ) throws -> AgenticToolHostRequest {
        let value: JSONValue

        do {
            value = try JSONDecoder().decode(
                JSONValue.self,
                from: data
            )

            try AgenticToolHostInvocationContract.schema(
                capabilities: capabilities
            )
            .validate(
                value
            )
        } catch {
            throw AgenticToolHostJSONError.invalidInvocationRequest
        }

        return try decodeInvocationRequest(
            data
        )
    }

    public static func decodeEnvelope(
        _ data: Data
    ) throws -> AgenticToolHostEnvelope {
        try JSONDecoder().decode(
            AgenticToolHostEnvelope.self,
            from: data
        )
    }

    public static func encode(
        _ request: AgenticToolHostRequest,
        prettyPrinted: Bool = false
    ) throws -> Data {
        try encoder(
            prettyPrinted: prettyPrinted
        ).encode(
            request
        )
    }

    public static func encode(
        _ envelope: AgenticToolHostEnvelope,
        prettyPrinted: Bool = false
    ) throws -> Data {
        try encoder(
            prettyPrinted: prettyPrinted
        ).encode(
            envelope
        )
    }

    public static func encodeString(
        _ request: AgenticToolHostRequest,
        prettyPrinted: Bool = false
    ) throws -> String {
        try string(
            from: encode(
                request,
                prettyPrinted: prettyPrinted
            )
        )
    }

    public static func encodeString(
        _ envelope: AgenticToolHostEnvelope,
        prettyPrinted: Bool = false
    ) throws -> String {
        try string(
            from: encode(
                envelope,
                prettyPrinted: prettyPrinted
            )
        )
    }
}

private extension AgenticToolHostJSON {
    static func encoder(
        prettyPrinted: Bool
    ) -> JSONEncoder {
        let encoder = JSONEncoder()
        var formatting: JSONEncoder.OutputFormatting = [
            .sortedKeys
        ]

        if prettyPrinted {
            formatting.insert(
                .prettyPrinted
            )
        }

        encoder.outputFormatting = formatting

        return encoder
    }

    static func string(
        from data: Data
    ) throws -> String {
        guard let value = String(
            data: data,
            encoding: .utf8
        ) else {
            throw AgenticToolHostJSONError.invalidUTF8
        }

        return value
    }
}

public extension AgenticToolHost {
    /// Decode raw invocation JSON against this host's exact live registry.
    func decodeInvocationRequest(
        _ data: Data
    ) throws -> AgenticToolHostRequest {
        try AgenticToolHostJSON.decodeInvocationRequest(
            data,
            capabilities: registry.capabilities
        )
    }
}

public enum AgenticToolHostJSONError: Error, LocalizedError, Sendable {
    case invalidUTF8
    case invalidInvocationRequest

    public var errorDescription: String? {
        switch self {
        case .invalidUTF8:
            return "Encoded Agentic tool-host JSON was not valid UTF-8."

        case .invalidInvocationRequest:
            return "Expected canonical Agentic host invocation JSON matching the capability manifest: DirectInvocation, non-empty AgentToolCall array, or AgentToolPlan."
        }
    }
}
