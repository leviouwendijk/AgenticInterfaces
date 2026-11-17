import AgenticStandard
import Foundation
import Primitives
import Reporting
import Terminal
import TerminalReporting

/// A validated value with one independently selectable conversation identity.
/// This does not imply a file artifact or an authorized action.
public struct AgenticConversationStructuredPresentation: Sendable, Hashable, Codable {
    public enum Content: Sendable, Hashable, Codable {
        /// A tool's presentation (`ToolPresenting`): reports, graphs, schedules.
        case document(ReportDocument)
        case call_tree(Standard.Tools.CreateCallTree.Output)
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
        case .document(let document):
            return document.title
        case .call_tree:
            return "Call tree"
        }
    }

    public var summary: String {
        switch content {
        case .document(let document):
            return Self.summary(document)
        case .call_tree(let output):
            let occurrenceCount = output.tree.walk().reduce(0) { count, _ in count + 1 }
            return "call tree · \(occurrenceCount) occurrences · \(output.provenance.rawValue)"
        }
    }

    /// The same rows serve an inline preview and a full scrollable inspector.
    public func rows(columns: Int, includeTitle: Bool = true) -> [String] {
        let width = max(1, columns)
        switch content {
        case .document(let document):
            return TerminalReporting.Renderer().rows(document, columns: width, includeTitle: includeTitle)
        case .call_tree(let output):
            return AgenticConversationCallTreeRenderer.rows(output, columns: width, includeTitle: includeTitle)
        }
    }

    /// Names the document by what it shows: a lone graph is a graph;
    /// anything else is a report listing its kinds of block.
    private static func summary(_ document: ReportDocument) -> String {
        var kinds: [String] = []
        for block in document.blocks {
            let kind: String
            switch block {
            case .narrative: kind = "narrative"
            case .table: kind = "table"
            case .chart: kind = "chart"
            case .facts: kind = "facts"
            case .callout: kind = "callout"
            case .timeline: kind = "timeline"
            case .graph(let graph):
                if document.blocks.count == 1 {
                    return "graph · \(graph.nodes.count) nodes · \(graph.edges.count) edges"
                }
                kind = "graph"
            }
            if !kinds.contains(kind) { kinds.append(kind) }
        }
        return (["report"] + kinds.prefix(4)).joined(separator: " · ")
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
}
