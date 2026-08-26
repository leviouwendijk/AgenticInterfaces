import Agentic
import Foundation

public enum AgenticToolHostJSON {
    public static func decodeRequest(
        _ data: Data
    ) throws -> AgenticToolHostRequest {
        try JSONDecoder().decode(
            AgenticToolHostRequest.self,
            from: data
        )
    }

    public static func decodeInvocationRequest(
        _ data: Data
    ) throws -> AgenticToolHostRequest {
        let decoder = JSONDecoder()

        if let request = try? decoder.decode(
            AgenticToolHostRequest.self,
            from: data
        ) {
            return request
        }

        if let call = try? decoder.decode(
            AgentToolCall.self,
            from: data
        ) {
            return .init(
                action: .invoke,
                call: call
            )
        }

        if let calls = try? decoder.decode(
            [AgentToolCall].self,
            from: data
        ), !calls.isEmpty {
            return .init(
                action: .invoke,
                calls: calls
            )
        }

        if let plan = try? decoder.decode(
            AgentToolPlan.self,
            from: data
        ) {
            return .init(
                action: .invoke,
                plan: plan
            )
        }

        throw AgenticToolHostJSONError.invalidInvocationRequest
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

public enum AgenticToolHostJSONError: Error, LocalizedError, Sendable {
    case invalidUTF8
    case invalidInvocationRequest

    public var errorDescription: String? {
        switch self {
        case .invalidUTF8:
            return "Encoded Agentic tool-host JSON was not valid UTF-8."

        case .invalidInvocationRequest:
            return "Expected Agentic tool-host invocation JSON as a host request, AgentToolCall, non-empty AgentToolCall array, or AgentToolPlan."
        }
    }
}
