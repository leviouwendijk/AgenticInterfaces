import Agentic
import Difference

/// Text the conversation engine keeps beside the data it projects: bodies an
/// interface may show verbatim, copy or export. The data (documents, previews,
/// layouts) stays the source of truth; each interface supplies its own text.
public protocol AgenticConversationTextRendering: Sendable {
    /// A structured result laid out at `columns`.
    func rows(
        _ content: AgenticConversationStructuredPresentation.Content,
        columns: Int,
        includeTitle: Bool
    ) -> [String]

    /// A tool's staged change.
    func text(
        _ difference: ToolPreflight.Preview.Difference
    ) -> String

    /// How an execution trace changed between two projections.
    func text(
        _ layout: TreeDifferenceLayout
    ) -> String
}
