import Agentic
import Terminal
import TerminalReporting

/// Lays out a tool's preview sections at the viewport's width. Each kind of
/// content keeps its own renderer; several sections stack under their titles.
public enum AgenticPreviewRenderer {
    public static func rows(
        _ sections: [ToolPreflight.Preview.Section],
        in region: TerminalRegion,
        prelude: String? = nil
    ) -> [String] {
        guard !region.isEmpty else { return [] }
        var output: [String] = []
        if let prelude, !prelude.isEmpty {
            output += prelude.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            output.append("")
        }
        let titled = sections.count > 1
        for (index, section) in sections.enumerated() {
            if index > 0 { output.append("") }
            if titled { output.append(TerminalStyle.bold.apply(section.title)) }
            output += rows(section.content, in: region)
        }
        return output
    }

    public static func rows(
        _ content: ToolPreflight.Preview.Content,
        in region: TerminalRegion
    ) -> [String] {
        switch content {
        case .difference(let difference):
            return AgenticMutationDifferenceRenderer.rows(difference, in: region)

        case .command(let command):
            let directory = command.workingDirectory.map {
                [TerminalStyle.dim.apply(TerminalDisplay.clipped("in " + $0, columns: region.columns))]
            } ?? []
            return directory + TerminalShellSyntax.rows(command.line, columns: region.columns)

        case .report(let document):
            return TerminalReporting.Renderer().rows(document, columns: region.columns, includeTitle: false)
        }
    }

    /// The menu entry for a set of sections: `Event`, or `Diff · Command`.
    public static func title(
        _ sections: [ToolPreflight.Preview.Section]
    ) -> String {
        sections.isEmpty
            ? AgenticHostConsoleDocumentKind.preview.title
            : sections.map(\.title).joined(separator: " · ")
    }
}
