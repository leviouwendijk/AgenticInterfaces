import Agentic
import AgenticPresentation
import Difference
import Terminal
import TerminalReporting

/// The terminal's text for conversation data: styled rows and diffs with gutters.
public struct TerminalConversationTextRendering: AgenticConversationTextRendering {
    public init() {}

    public func rows(
        _ content: AgenticConversationStructuredPresentation.Content,
        columns: Int,
        includeTitle: Bool
    ) -> [String] {
        let width = max(1, columns)
        switch content {
        case .document(let document):
            return TerminalReporting.Renderer().rows(document, columns: width, includeTitle: includeTitle)
        case .call_tree(let output):
            return AgenticConversationCallTreeRenderer.rows(output, columns: width, includeTitle: includeTitle)
        }
    }

    public func text(
        _ difference: ToolPreflight.Preview.Difference
    ) -> String {
        AgenticMutationDifferenceRenderer.render(difference)
    }

    public func text(
        _ layout: TreeDifferenceLayout
    ) -> String {
        TerminalDifferenceRenderer.render(layout)
    }
}
