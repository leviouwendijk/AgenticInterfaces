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

    /// Physical diff rows are already measured and must not be rewrapped.
    /// The parent owns all border/padding calculations and supplies its region.
    public static func rows(
        _ difference: ToolPreflight.Preview.Difference,
        in region: TerminalRegion,
        prelude: String? = nil
    ) -> [String] {
        guard !region.isEmpty else { return [] }
        let output = render(
            difference,
            options: TerminalDifferenceRenderOptions.review.constrained(to: region)
        )
        let physical = output.components(separatedBy: "\n")
        guard let prelude, !prelude.isEmpty else { return physical }
        let heading = TerminalTextLayout(
            text: prelude,
            columns: region.columns
        ).rows.map(\.content)
        return heading + [""] + physical
    }

    /// Compatibility for consumers that only have an allocated column count.
    public static func rows(
        _ difference: ToolPreflight.Preview.Difference,
        columns: Int,
        prelude: String? = nil
    ) -> [String] {
        rows(
            difference,
            in: TerminalRegion(rows: 1, columns: columns),
            prelude: prelude
        )
    }
}
