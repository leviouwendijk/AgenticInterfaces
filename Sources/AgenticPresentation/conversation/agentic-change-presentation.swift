/// A change to what a run works with, shown where it happened in the
/// conversation: history the next request no longer carries in full, a
/// route that differs from the selection, a tool kept because something
/// still needs it. Nothing about a run changes out of sight.
public struct AgenticChangePresentation:
    Sendable,
    Hashable,
    Identifiable
{
    public enum Kind:
        String,
        Sendable,
        Hashable,
        CaseIterable
    {
        /// History selection: what a request carries.
        case context
        /// Model routing: the model a request went to.
        case route
        /// A tool or service kept or added because a feature requires it.
        case capability
        /// Roots, restrictions, working directory.
        case workspace

        public var title: String {
            switch self {
            case .context: "context"
            case .route: "route"
            case .capability: "capabilities"
            case .workspace: "workspace"
            }
        }
    }

    public struct Item:
        Sendable,
        Hashable,
        Identifiable
    {
        public var id: String
        /// `read · call_12`, or a message.
        public var subject: String
        /// `repeated result → see call_7`
        public var detail: String
        /// Whether the full content can be read back (e.g. through the
        /// history reader); `nil` when unknown.
        public var isRecoverable: Bool?

        public init(
            id: String,
            subject: String,
            detail: String,
            isRecoverable: Bool? = nil
        ) {
            self.id = id
            self.subject = subject
            self.detail = detail
            self.isRecoverable = isRecoverable
        }
    }

    public var id: String
    public var kind: Kind
    public var runID: String?
    public var iteration: Int?
    /// `3 results shortened`
    public var summary: String
    /// Why, readable: the policy or rule and its trigger.
    public var reason: String
    public var items: [Item]
    /// Losing content the model may need, as opposed to a neutral change.
    public var isLossy: Bool

    public init(
        id: String,
        kind: Kind,
        runID: String? = nil,
        iteration: Int? = nil,
        summary: String,
        reason: String,
        items: [Item] = [],
        isLossy: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.runID = runID
        self.iteration = iteration
        self.summary = summary
        self.reason = reason
        self.items = items
        self.isLossy = isLossy
    }

    public var transcriptTitle: String {
        "\(kind.title) · \(summary)"
            + (iteration.map { " · iteration \($0)" } ?? "")
    }

    public var transcriptBody: String {
        let shown = items.prefix(3).map { "\($0.subject)  \($0.detail)" }
        let more = items.count > 3 ? ["… \(items.count - 3) more"] : []
        return ([reason] + shown + more).joined(separator: "\n")
    }

    public var detailsBody: String {
        var lines = [transcriptTitle, "", reason]
        if let runID { lines += ["run  \(runID)"] }
        if !items.isEmpty {
            lines += [""]
            lines += items.map { item in
                let recovery = switch item.isRecoverable {
                case true?: "  · recoverable"
                case false?: "  · not recoverable"
                case nil: ""
                }
                return "\(item.subject)  \(item.detail)\(recovery)"
            }
        }
        return lines.joined(separator: "\n")
    }

    /// Readable text for a history-change reason, by its stable raw value
    /// (`ContextWindow.HistorySelection.Change.Reason`).
    public static func contextReason(
        _ raw: String
    ) -> String {
        switch raw {
        case "aged_result": "an older tool result, shortened by age"
        case "budget_result": "a tool result, shortened to fit the result budget"
        case "unseen_result": "a result the model has not used, shortened"
        case "repeated_result": "a repeat of an earlier result, replaced by a pointer to it"
        case "turn_budget": "an earlier turn, left out to fit the turn budget"
        case "exchange_budget": "an earlier exchange, left out to fit the exchange budget"
        case "working_set": "outside the current working set"
        default: raw.replacingOccurrences(of: "_", with: " ")
        }
    }

    /// One line for listings: `context · 3 results shortened · iteration 2`.
    public var line: String {
        transcriptTitle + (isLossy ? "  (lossy)" : "")
    }
}
