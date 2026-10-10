import Agentic
import Foundation
import Search

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

    /// Searches the projected catalog only. Results retain their original
    /// identifiers and never alter installed or authorized capabilities.
    public static func search(
        _ query: String,
        in entries: [Self]
    ) -> [Self] {
        let terms = query.split(whereSeparator: \.isWhitespace)
            .map(String.init)
        guard !terms.isEmpty else {
            return entries
        }

        let corpus = SearchCorpus(
            documents: entries.map { entry in
                SearchDocument(
                    id: entry.id,
                    text: [
                        entry.identifier,
                        entry.title,
                        entry.summary,
                        entry.domain,
                        entry.kind.rawValue,
                    ].joined(separator: "\n")
                )
            }
        )
        let result = TextSearch.search(
            probes: terms.map { term in
                SearchProbe(term, role: .required, strategy: .fuzzy)
            },
            in: corpus,
            options: SearchOptions(
                mode: .ranked,
                strategy: .fuzzy,
                caseSensitive: false,
                minimumScore: 1,
                maximumResults: nil
            )
        )
        let byID = Dictionary(
            entries.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return result.hits.compactMap { byID[$0.documentID] }
    }
}
