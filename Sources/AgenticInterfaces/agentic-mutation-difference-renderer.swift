import Agentic
import Difference
import Terminal

/// Presentation only. A staged preview is not observed filesystem state.
public enum AgenticMutationDifferenceRenderer {
    public static func render(
        _ difference: ToolPreflight.Preview.Difference,
        options: TerminalDifferenceRenderOptions = .review
    ) -> String {
        // Existing layout-only previews retain their established render path.
        // Do not reconstruct a TextDifference from presentation rows.
        guard let source = difference.source,
              difference.layout == DifferenceLayout.make(source, options: .full) else {
            return TerminalDifferenceRenderer.render(
                difference.presentation,
                options: options
            )
        }

        // Preserve the canonical tree, graph, text section order.
        let structural = TerminalDifferenceRenderer.render(
            DifferencePresentation(
                text: .init(lines: []),
                tree: difference.tree,
                graph: difference.graph
            ),
            options: options
        )
        let text = TerminalDifferenceRenderer.render(source, options: options)
        return [structural, text]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }
}
