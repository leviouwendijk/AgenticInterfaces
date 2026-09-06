import DSL
import Terminal
import TerminalStructuredContent

enum AgenticConversationRunReviewEvent:
    Sendable,
    Hashable
{
    case closed(
        runID: String
    )
    case actionRequested(
        interruptionID: String,
        runID: String,
        stepID: String,
        action: AgenticHostConsoleAction
    )
    case openRunConsole(
        runID: String
    )
}

struct AgenticConversationRunReviewControl:
    Sendable
{
    private enum Item:
        Sendable,
        Hashable
    {
        case document(
            AgenticHostConsoleDocumentKind
        )
        case action(
            AgenticHostConsoleAction
        )
        case openRunConsole

        var id: String {
            switch self {
            case .document(let kind):
                return "document:\(kind.rawValue)"

            case .action(let action):
                return "action:\(action.rawValue)"

            case .openRunConsole:
                return "run-console"
            }
        }

        var title: String {
            switch self {
            case .document(let kind):
                return kind.title

            case .action(let action):
                return action.title

            case .openRunConsole:
                return "Open run console"
            }
        }

        var summary: String {
            switch self {
            case .document(.diff):
                return "Inspect the exact staged diff for this approval."

            case .document(.details):
                return "Inspect the full staged intent and preflight details."

            case .document(.stdout):
                return "Inspect stdout for this stage."

            case .document(.stderr):
                return "Inspect stderr for this stage."

            case .action(let action):
                return action.summary

            case .openRunConsole:
                return "Open the full persistent run inspector for deeper controls and history."
            }
        }
    }

    private(set) var runID: String

    private let interruptionID: String
    private let stepID: String
    private var snapshot: AgenticHostConsoleSnapshot
    private var interruption: AgenticHostConsoleInterruptionPresentation
    private var items: [Item]
    private var selectedIndex: Int
    private var openedDocumentKind: AgenticHostConsoleDocumentKind?
    private var document: TerminalScrollableDocument

    init?(
        snapshot: AgenticHostConsoleSnapshot,
        runID: String
    ) {
        guard let interruption = snapshot.interruptions.first(where: {
            $0.runID == runID
                && $0.kind == .approval
        }) else {
            return nil
        }

        self.runID = runID
        self.interruptionID = interruption.id
        self.stepID = interruption.stepID
        self.snapshot = snapshot
        self.interruption = interruption
        self.items = Self.makeItems(
            snapshot: snapshot,
            interruption: interruption
        )
        self.selectedIndex = 0
        self.openedDocumentKind = nil
        self.document = TerminalScrollableDocument()
    }

    var footer: String {
        if openedDocumentKind != nil {
            return "j/k scroll  pgup/pgdn  home/end  q actions"
        }

        return "j/k choose  enter open  q back"
    }

    @discardableResult
    mutating func update(
        _ snapshot: AgenticHostConsoleSnapshot
    ) -> Bool {
        guard let interruption = snapshot.interruptions.first(where: {
            $0.id == interruptionID
                && $0.runID == runID
                && $0.stepID == stepID
                && $0.kind == .approval
        }) else {
            return false
        }

        let selectedID = currentItem?.id

        self.snapshot = snapshot
        self.interruption = interruption
        self.items = Self.makeItems(
            snapshot: snapshot,
            interruption: interruption
        )

        if let selectedID,
           let index = items.firstIndex(where: {
            $0.id == selectedID
           }) {
            selectedIndex = index
        } else {
            selectedIndex = min(
                selectedIndex,
                max(
                    0,
                    items.count - 1
                )
            )
        }

        if let openedDocumentKind,
           matchingDocument(
            kind: openedDocumentKind
           ) == nil {
            self.openedDocumentKind = nil
            document.moveToStart()
        }

        return true
    }

    mutating func handle(
        _ key: TerminalKey
    ) -> AgenticConversationRunReviewEvent? {
        if openedDocumentKind != nil {
            return handleDocument(
                key
            )
        }

        switch key {
        case .escape,
             .char("q"):
            return .closed(
                runID: runID
            )

        case .up,
             .char("k"):
            selectedIndex = max(
                0,
                selectedIndex - 1
            )
            return nil

        case .down,
             .char("j"):
            selectedIndex = min(
                max(
                    0,
                    items.count - 1
                ),
                selectedIndex + 1
            )
            return nil

        case .enter:
            guard let currentItem else {
                return nil
            }

            switch currentItem {
            case .document(let kind):
                guard matchingDocument(
                    kind: kind
                ) != nil else {
                    return nil
                }

                openedDocumentKind = kind
                document.moveToStart()
                return nil

            case .action(let action):
                return .actionRequested(
                    interruptionID: interruptionID,
                    runID: runID,
                    stepID: stepID,
                    action: action
                )

            case .openRunConsole:
                return .openRunConsole(
                    runID: runID
                )
            }

        default:
            return nil
        }
    }

    mutating func render(
        into frame: inout TerminalFrame,
        in region: TerminalRegion
    ) {
        if openedDocumentKind != nil {
            renderDocument(
                into: &frame,
                in: region
            )
            return
        }

        renderMenu(
            into: &frame,
            in: region
        )
    }
}

private extension AgenticConversationRunReviewControl {
    private var currentItem: Item? {
        guard !items.isEmpty else {
            return nil
        }

        return items[
            min(
                max(
                    0,
                    selectedIndex
                ),
                items.count - 1
            )
        ]
    }

    private static func makeItems(
        snapshot: AgenticHostConsoleSnapshot,
        interruption: AgenticHostConsoleInterruptionPresentation
    ) -> [Item] {
        var result: [Item] = []

        for kind in [
            AgenticHostConsoleDocumentKind.diff,
            .details,
        ] {
            if snapshot.documents.contains(where: {
                $0.runID == interruption.runID
                    && $0.stepID == interruption.stepID
                    && $0.kind == kind
            }) {
                result.append(
                    .document(
                        kind
                    )
                )
            }
        }

        result.append(
            contentsOf: interruption.actions.compactMap { action in
                switch action {
                case .approve,
                     .deny,
                     .skip:
                    return .action(
                        action
                    )

                case .continueRun,
                     .stopRun,
                     .retry,
                     .createFixBranch:
                    return nil
                }
            }
        )

        result.append(
            .openRunConsole
        )

        return result
    }

    func matchingDocument(
        kind: AgenticHostConsoleDocumentKind
    ) -> AgenticHostConsoleDocumentPresentation? {
        snapshot.documents.first {
            $0.runID == runID
                && $0.stepID == stepID
                && $0.kind == kind
        }
    }

    mutating func handleDocument(
        _ key: TerminalKey
    ) -> AgenticConversationRunReviewEvent? {
        switch key {
        case .escape,
             .char("q"):
            openedDocumentKind = nil
            document.moveToStart()

        case .up,
             .char("k"):
            _ = document.handle(
                .motion(
                    .up
                )
            )

        case .down,
             .char("j"):
            _ = document.handle(
                .motion(
                    .down
                )
            )

        case .pageUp:
            _ = document.handle(
                .motion(
                    .pageUp
                )
            )

        case .pageDown:
            _ = document.handle(
                .motion(
                    .pageDown
                )
            )

        case .home:
            document.moveToStart()

        case .end:
            document.moveToEnd()

        default:
            break
        }

        return nil
    }

    mutating func renderMenu(
        into frame: inout TerminalFrame,
        in region: TerminalRegion
    ) {
        let columns = min(
            max(
                44,
                region.columns * 2 / 3
            ),
            max(
                1,
                region.columns - 4
            )
        )
        let rows = min(
            max(
                10,
                items.count + 8
            ),
            max(
                1,
                region.rows - 4
            )
        )
        let overlay = TerminalOverlay(
            placement: .centered(
                columns: columns,
                rows: rows
            ),
            outerInsets: TerminalInsets(
                vertical: 1,
                horizontal: 2
            ),
            contentInsets: TerminalInsets(
                vertical: 1,
                horizontal: 2
            )
        )
        let overlayLayer = TerminalZIndex(
            190
        )
        let contentLayer = TerminalZIndex(
            191
        )
        let content = overlay.render(
            into: &frame,
            in: region,
            title: interruption.title,
            zIndex: overlayLayer
        )
        let width = max(
            1,
            content.columns
        )
        var lines = TerminalTextWrap.lines(
            interruption.summary,
            width: width
        )

        if !lines.isEmpty {
            lines.append("")
        }

        for index in items.indices {
            let prefix = index == selectedIndex
                ? "> "
                : "  "
            let line = TerminalDisplay.fitted(
                prefix + items[index].title,
                columns: width
            )

            lines.append(
                index == selectedIndex
                    ? TerminalStyle(
                        .inverse
                    ).apply(
                        line
                    )
                    : line
            )
        }

        if let currentItem {
            lines.append("")
            lines.append(
                contentsOf: TerminalTextWrap.lines(
                    currentItem.summary,
                    width: width
                ).map {
                    TerminalStyle.dim.apply(
                        $0
                    )
                }
            )
        }

        frame.write(
            Array(
                lines.prefix(
                    content.rows
                )
            ),
            in: content,
            zIndex: contentLayer
        )
    }

    mutating func renderDocument(
        into frame: inout TerminalFrame,
        in region: TerminalRegion
    ) {
        guard let openedDocumentKind,
              let currentDocument = matchingDocument(
                kind: openedDocumentKind
              ) else {
            return
        }

        let overlay =
            AgenticHostConsoleInspectionSurface.overlay(
                in: region
            )
        let documentLayer = TerminalZIndex(
            200
        )
        let content = overlay.render(
            into: &frame,
            in: region,
            title: currentDocument.title,
            zIndex: documentLayer
        )

        if let structuredBody = currentDocument.structuredBody {
            document.update(
                lines: TerminalStructuredContent.Renderer()
                    .rows(
                        structuredBody,
                        columns: content.columns
                    ),
                visibleRows: content.rows
            )
        } else {
            let wrapping: TerminalDocumentWrapping

            switch currentDocument.kind {
            case .details:
                wrapping = .word

            case .diff,
                 .stdout,
                 .stderr:
                wrapping = .display
            }

            document.update(
                text: currentDocument.body,
                columns: content.columns,
                visibleRows: content.rows,
                wrapping: wrapping
            )
        }

        document.render(
            into: &frame,
            in: content,
            zIndex: TerminalZIndex(
                201
            )
        )
    }
}
