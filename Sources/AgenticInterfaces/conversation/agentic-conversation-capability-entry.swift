import Agentic
import Foundation

public struct AgenticConversationCapabilityEntry: Sendable, Hashable, Identifiable {
    public enum Kind: String, Sendable, Hashable, CaseIterable {
        case tool, program, inference, agent, instruction

        public var title: String { rawValue.capitalized + "s" }
    }

    public let kind: Kind
    public let identifier: String
    public let namespace: String?
    public let title: String
    public let summary: String

    public var id: String { "\(kind.rawValue):\(identifier)" }
    public var domain: String { namespace ?? "Unscoped" }

    public init(kind: Kind, identifier: String, namespace: String? = nil, title: String, summary: String) {
        self.kind = kind
        self.identifier = identifier
        self.namespace = namespace
        self.title = title
        self.summary = summary
    }

    public var capability: AgentCapabilitySet {
        switch kind {
        case .tool: .init(tools: [.init(rawValue: identifier)])
        case .program: .init(programs: [.init(rawValue: identifier)])
        case .inference: .init(inferences: [.init(rawValue: identifier)])
        case .agent: .init(agents: [.init(rawValue: identifier)])
        case .instruction: .none
        }
    }

    public func matches(_ query: String) -> Bool {
        let terms = query.split(whereSeparator: \.isWhitespace)
        return terms.allSatisfy { term in
            let value = String(term)
            return [identifier, title, summary, domain, kind.rawValue]
                .contains { $0.localizedCaseInsensitiveContains(value) }
        }
    }
}
