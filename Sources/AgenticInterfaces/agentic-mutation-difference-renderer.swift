import Agentic
import Terminal

/// Renders both preflight layouts with the shared Terminal styling and geometry.
/// The structured tree describes the prepared plan, not observed filesystem state.
public enum AgenticMutationDifferenceRenderer {
    public static func render(
        _ difference: ToolPreflight.Preview.Difference
    ) -> String {
        let tree = difference.tree_layout.map {
            TerminalDifferenceRenderer.render($0)
        } ?? ""
        let text = difference.layout.isEmpty ? "" :
            TerminalDifferenceRenderer.render(difference.layout)
        return [tree, text].filter { !$0.isEmpty }.joined(separator: "\n\n")
    }
}
