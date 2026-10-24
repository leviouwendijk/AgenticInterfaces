import Agentic
import Difference

/// Renders both computed views from a single preflight Difference value.
/// The tree is an affected-path plan projection, not an observed filesystem diff.
public enum AgenticMutationDifferenceRenderer {
    public static func render(
        _ difference: ToolPreflight.Preview.Difference
    ) -> String {
        let tree = difference.tree_layout.map {
            TreeDifferenceRenderer.render(
                TreeDifferenceRenderPlan.make($0)
            )
        } ?? ""
        let text = difference.text_layout.isEmpty ? "" :
            TerminalDifferenceRenderer.render(difference.text_layout)
        return [tree, text].filter { !$0.isEmpty }.joined(separator: "\n\n")
    }
}
