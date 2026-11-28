import AgenticPresentation
import Terminal

public extension AgenticConversationStructured {
    /// The same rows serve an inline preview and a full scrollable inspector.
    func rows(columns: Int, includeTitle: Bool = true) -> [String] {
        TerminalConversationTextRendering().rows(content, columns: columns, includeTitle: includeTitle)
    }

    /// Transcript previews are bounded and must explicitly disclose omitted rows.
    /// The surrounding conversation supplies the attachment title.
    func previewRows(columns: Int, maxRows: Int = 12) -> [String] {
        let width = max(1, columns)
        let full = rows(columns: width, includeTitle: false)
        let limit = max(2, maxRows)
        guard full.count > limit else { return full }
        let displayed = limit - 1
        let more = full.count - displayed
        return Array(full.prefix(displayed)) + [
            TerminalDisplay.clipped("… \(more) more rows · Enter to inspect", columns: width)
        ]
    }
}
