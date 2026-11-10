import Agentic
import Difference
import Terminal

/// Presentation only. A staged preview is not observed filesystem state.
public enum AgenticMutationDifferenceRenderer {
    public static func render(
        _ difference: ToolPreflight.Preview.Difference,
        options: TerminalDifferenceRenderOptions = .review
    ) -> String {
        if options.presentation != .legacy,
           let sections = difference.sections,
           !sections.isEmpty {
            let structural = TerminalDifferenceRenderer.render(
                DifferencePresentation(
                    text: .init(lines: []),
                    tree: difference.tree,
                    graph: difference.graph
                ),
                options: options
            )
            let text = sections.map { section in
                TerminalDifferenceRenderer.render(
                    section.projection,
                    options: options
                )
            }.filter { !$0.isEmpty }.joined(separator: "\n\n")
            return [structural, text]
                .filter { !$0.isEmpty }
                .joined(separator: "\n\n")
        }

        // Layout-only previews retain the established compact gutters.
        // Never infer source text from an already-projected layout.
        guard let source = difference.source,
              difference.layout == DifferenceLayout.make(source, options: .full) else {
            var fallback = options
            if fallback.presentation == .review {
                fallback.base = .unified
                fallback.wrap = .characters
                fallback.presentation = .legacy
            }
            return TerminalDifferenceRenderer.render(
                difference.presentation,
                options: fallback
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
