import Terminal

enum AgenticConversationPinnedContentEvent: Sendable, Hashable {
    case closeRequested
    case inclusionToggled(id: String)
    case removeRequested(id: String)
}

struct AgenticConversationPinnedContentControl: Sendable {
    private(set) var currentID: String?
    private(set) var inspectedID: String?
    private var document: TerminalScrollableDocument

    init(
        contents: [AgenticConversationContentPresentation]
    ) {
        self.currentID = contents.first?.id
        self.inspectedID = nil
        self.document = TerminalScrollableDocument()
    }

    var footer: String {
        inspectedID == nil
            ? "j/k pin  enter inspect  space include/exclude  d remove  q back"
            : "j/k scroll  pgup/pgdn scroll  home/end  q pins"
    }

    mutating func update(
        contents: [AgenticConversationContentPresentation]
    ) {
        let ids = Set(
            contents.map(\.id)
        )

        if let inspectedID,
           !ids.contains(inspectedID)
        {
            self.inspectedID = nil
            document.moveToStart()
        }

        if let currentID,
           ids.contains(currentID)
        {
            return
        }

        self.currentID = contents.first?.id
    }

    mutating func handle(
        _ key: TerminalKey,
        contents: [AgenticConversationContentPresentation]
    ) -> AgenticConversationPinnedContentEvent? {
        update(
            contents: contents
        )

        if inspectedID != nil {
            switch key {
            case .char("q"), .escape:
                inspectedID = nil
                document.moveToStart()

            case .char("j"), .down:
                document.scrollDown()

            case .char("k"), .up:
                document.scrollUp()

            case .pageUp:
                document.pageUp()

            case .pageDown:
                document.pageDown()

            case .home:
                document.moveToStart()

            case .end:
                document.moveToEnd()

            default:
                break
            }

            return nil
        }

        switch key {
        case .char("q"), .escape:
            return .closeRequested

        case .char("j"), .down:
            move(
                by: 1,
                contents: contents
            )

        case .char("k"), .up:
            move(
                by: -1,
                contents: contents
            )

        case .enter:
            guard currentID != nil else {
                return nil
            }
            inspectedID = currentID
            document.moveToStart()

        case .space:
            guard let currentID else {
                return nil
            }
            return .inclusionToggled(
                id: currentID
            )

        case .char("d"),
             .char("x"),
             .delete:
            guard let currentID else {
                return nil
            }
            return .removeRequested(
                id: currentID
            )

        default:
            break
        }

        return nil
    }

    mutating func render(
        into frame: inout TerminalFrame,
        in region: TerminalRegion,
        contents: [AgenticConversationContentPresentation],
        excludedIDs: Set<String>
    ) {
        update(
            contents: contents
        )

        if let inspectedID,
           let content = contents.first(where: {
               $0.id == inspectedID
           })
        {
            let state = excludedIDs.contains(content.id)
                ? "excluded"
                : "included"

            document.update(
                text: [
                    "Pinned content · \(content.title)",
                    "\(state) · \(content.summary)",
                    "",
                    content.body,
                ].joined(separator: "\n"),
                columns: region.columns,
                visibleRows: region.rows,
                wrapping: .display
            )
        } else {
            var lines = [
                "Pinned content",
                "",
            ]

            for content in contents {
                let cursor = content.id == currentID
                    ? ">"
                    : " "
                let inclusion = excludedIDs.contains(content.id)
                    ? "[ ]"
                    : "[x]"

                lines.append(
                    "\(cursor) \(inclusion) \(content.title) · \(content.summary)"
                )
            }

            if contents.isEmpty {
                lines.append("No pinned content.")
            }

            document.update(
                text: lines.joined(separator: "\n"),
                columns: region.columns,
                visibleRows: region.rows,
                wrapping: .word
            )
        }

        document.render(
            into: &frame,
            in: region,
            zIndex: .overlay
        )
    }

    private mutating func move(
        by delta: Int,
        contents: [AgenticConversationContentPresentation]
    ) {
        guard !contents.isEmpty else {
            currentID = nil
            return
        }

        let index = currentID.flatMap { id in
            contents.firstIndex(where: {
                $0.id == id
            })
        } ?? 0

        let next = min(
            max(
                index + delta,
                contents.startIndex
            ),
            contents.index(before: contents.endIndex)
        )

        currentID = contents[next].id
    }
}
