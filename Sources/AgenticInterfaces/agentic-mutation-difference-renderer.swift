import Agentic
import Terminal

/// Renders text, tree, and graph previews using canonical Terminal projections.
/// A staged preview is not a claim about observed state.
public enum AgenticMutationDifferenceRenderer {
    public static func render(
        _ difference: ToolPreflight.Preview.Difference
    ) -> String {
        return TerminalDifferenceRenderer.render(difference.presentation)
    }
}
