import Agentic

public extension Array where Element == ToolPreflight.Preview.Section {
    /// The menu entry for a set of sections: `Event`, or `Diff · Command`.
    var previewTitle: String {
        isEmpty
            ? AgenticHostConsoleDocumentKind.preview.title
            : map(\.title).joined(separator: " · ")
    }
}
