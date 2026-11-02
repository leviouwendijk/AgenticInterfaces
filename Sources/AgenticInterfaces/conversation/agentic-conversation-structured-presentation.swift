import Foundation
import Primitives
import Reporting
import Terminal
import TerminalGraph
import TerminalReporting

/// A validated value with one independently selectable conversation identity.
/// This does not imply a file artifact or an authorized action.
public struct AgenticConversationStructuredPresentation: Sendable, Hashable, Codable {
    public enum Content: Sendable, Hashable, Codable {
        case graph(Graph<String, JSONValue, String, JSONValue>, ReferenceSet<String, String>)
        case report(ReportDocument)
    }

    public let id: String
    public let sourceCallID: String
    public let iteration: Int?
    public let content: Content

    public init(id: String, sourceCallID: String, iteration: Int?, content: Content) {
        self.id = id
        self.sourceCallID = sourceCallID
        self.iteration = iteration
        self.content = content
    }

    public var title: String {
        switch content {
        case .graph:
            return "Graph"
        case .report(let report):
            return report.title
        }
    }

    public var summary: String {
        switch content {
        case .graph(let graph, _):
            return "graph · \(graph.nodes.count) nodes · \(graph.edges.count) edges"
        case .report(let report):
            return "report · \(report.datasets.count) datasets · \(report.blocks.count) blocks"
        }
    }

    /// The same rows serve an inline preview and a full scrollable inspector.
    public func rows(columns: Int, includeTitle: Bool = true) -> [String] {
        let width = max(1, columns)
        switch content {
        case .report(let document):
            return TerminalReporting.Renderer().rows(document, columns: width, includeTitle: includeTitle)
        case .graph(let graph, let references):
            let labels = Dictionary(uniqueKeysWithValues: graph.nodes.map { node in
                (node.id, Self.valueLabel(node.value, fallback: node.id))
            })
            if let layout = try? graph.layout() {
                return TerminalGraph.Renderer().project(
                    layout,
                    columns: width,
                    label: { labels[$0] ?? $0 },
                    references: layout.place_references(references),
                    referenceLabel: { $0 }
                ).lines
            }
            // Arbitrary graphs can contain cycles. They remain inspectable;
            // the DAG-only multi-lane projection is not forced upon them.
            let descriptions = graph.nodes.map { "node \($0.id) · \(labels[$0.id] ?? $0.id)" }
                + graph.edges.map { "edge \($0.id) · \($0.source) -> \($0.destination)" }
                + references.references.map { "reference \($0.id) -> \($0.target)" }
            return descriptions.flatMap { TerminalTextWrap.lines($0, width: width) }
        }
    }

    /// Transcript previews are bounded and must explicitly disclose omitted rows.
    /// The surrounding conversation supplies the attachment title.
    public func previewRows(columns: Int, maxRows: Int = 12) -> [String] {
        let width = max(1, columns)
        let full = rows(columns: width, includeTitle: false)
        let limit = max(2, maxRows)
        guard full.count > limit else { return full }
        let displayed = limit - 1
        let more = full.count - displayed
        return Array(full.prefix(displayed)) + [
            TerminalDisplay.clipped("… \(more) more rows · Enter to inspect", columns: width)
        ]
    }

    private static func valueLabel(_ value: JSONValue, fallback: String) -> String {
        switch value {
        case .string(let text):
            return text
        case .object(let properties):
            if case .string(let text)? = properties["label"] {
                return text
            }
            return fallback
        default:
            return fallback
        }
    }
}
