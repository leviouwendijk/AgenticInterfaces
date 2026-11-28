import Agentic
import AgenticStandard
import Difference
import Reporting

/// Plain text for conversation data: no styling and no fixed width. For
/// interfaces that draw the data themselves and keep text only to show
/// verbatim, copy or export.
public struct PlainConversationTextRendering: AgenticConversationTextRendering {
    public init() {}

    public func rows(
        _ content: AgenticConversationStructured.Content,
        columns: Int,
        includeTitle: Bool
    ) -> [String] {
        switch content {
        case .document(let document):
            return ReportMarkdown.render(document)
                .components(separatedBy: "\n")
        case .call_tree(let output):
            let tree = AgenticExecutionTreeRenderer.render(output.tree) { occurrence in
                occurrence.label
            }
            return (includeTitle ? ["Call tree"] : [])
                + tree.components(separatedBy: "\n")
        }
    }

    public func text(
        _ difference: ToolPreflight.Preview.Difference
    ) -> String {
        if let source = difference.source {
            return DifferenceRenderer.Basic.plain(source)
        }
        return DifferenceRenderer.Basic.plain(difference.layout)
    }

    public func text(
        _ layout: TreeDifferenceLayout
    ) -> String {
        TreeDifferenceRenderer.render(.make(layout))
    }
}
