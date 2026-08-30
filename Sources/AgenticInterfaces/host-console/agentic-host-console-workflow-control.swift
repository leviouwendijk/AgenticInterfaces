import Terminal

public enum AgenticHostConsoleWorkflowFocus:
    Sendable,
    Hashable
{
    case base
    case actions
    case document
}

public enum AgenticHostConsoleWorkflowEvent:
    Sendable,
    Hashable
{
    case base(AgenticHostConsoleEvent)
    case interruptionOpened(
        id: String,
        kind: AgenticHostConsoleInterruptionKind
    )
    case interruptionClosed(
        id: String
    )
    case actionRequested(
        interruptionID: String,
        runID: String,
        stepID: String,
        action: AgenticHostConsoleAction
    )
    case documentOpened(
        documentID: String,
        kind: AgenticHostConsoleDocumentKind
    )
    case documentClosed(
        documentID: String,
        kind: AgenticHostConsoleDocumentKind
    )

    public var requestsExit: Bool {
        if case .base(.exitRequested) = self {
            return true
        }

        return false
    }
}

public struct AgenticHostConsoleWorkflowControl:
    Sendable
{
    public private(set) var console: AgenticHostConsoleControl
    public private(set) var focus: TerminalFocusStack<AgenticHostConsoleWorkflowFocus>

    private var actions: TerminalListControl<
        AgenticHostConsoleAction,
        String
    >
    private var document: TerminalScrollableDocument
    private var openedInterruptionID: String?
    private var openedDocumentID: String?

    public init(
        snapshot: AgenticHostConsoleSnapshot,
        currentRunID: String? = nil,
        currentStepID: String? = nil
    ) {
        self.console = AgenticHostConsoleControl(
            snapshot: snapshot,
            currentRunID: currentRunID,
            currentStepID: currentStepID
        )
        self.focus = TerminalFocusStack(
            .base
        )
        self.actions = TerminalListControl(
            items: [],
            id: {
                $0.rawValue
            }
        )
        self.document = TerminalScrollableDocument()
        self.openedInterruptionID = nil
        self.openedDocumentID = nil
    }

    public var currentRunID: String? {
        console.currentRunID
    }

    public var currentStepID: String? {
        console.currentStepID
    }

    public var currentAction: AgenticHostConsoleAction? {
        actions.currentItem
    }

    public var currentInterruption: AgenticHostConsoleInterruptionPresentation? {
        if let openedInterruptionID {
            return console.snapshot.interruptions.first {
                $0.id == openedInterruptionID
            }
        }

        guard let currentRunID,
              let currentStepID else {
            return nil
        }

        return console.snapshot.interruptions.first {
            $0.runID == currentRunID
                && $0.stepID == currentStepID
        }
    }

    public var currentDocument: AgenticHostConsoleDocumentPresentation? {
        guard let openedDocumentID else {
            return nil
        }

        return console.snapshot.documents.first {
            $0.id == openedDocumentID
        }
    }

    public mutating func update(
        _ snapshot: AgenticHostConsoleSnapshot
    ) {
        console.update(
            snapshot
        )

        if let openedInterruptionID,
           !snapshot.interruptions.contains(
            where: {
                $0.id == openedInterruptionID
            }
           ) {
            closeAllWorkflowSurfaces()
            return
        }

        if let openedDocumentID,
           !snapshot.documents.contains(
            where: {
                $0.id == openedDocumentID
            }
           ) {
            self.openedDocumentID = nil
            focus.reset(
                to: .base
            )
        }
    }

    public mutating func handle(
        _ key: TerminalKey
    ) -> AgenticHostConsoleWorkflowEvent? {
        if key == .control("C") {
            return .base(
                .exitRequested
            )
        }

        switch focus.current {
        case .base:
            return handleBase(
                key
            )

        case .actions:
            return handleActions(
                key
            )

        case .document:
            return handleDocument(
                key
            )
        }
    }

    public mutating func render(
        into frame: inout TerminalFrame,
        in region: TerminalRegion
    ) {
        console.render(
            into: &frame,
            in: region
        )

        if openedInterruptionID != nil {
            renderInterruption(
                into: &frame,
                in: region
            )
        }

        if openedDocumentID != nil {
            renderDocument(
                into: &frame,
                in: region
            )
        }

        renderFooter(
            into: &frame,
            in: region
        )
    }
}

private extension AgenticHostConsoleWorkflowControl {
    mutating func handleBase(
        _ key: TerminalKey
    ) -> AgenticHostConsoleWorkflowEvent? {
        if key == .char("a"),
           console.focus.current != .runs,
           let interruption = matchingInterruption() {
            openInterruption(
                interruption
            )

            return .interruptionOpened(
                id: interruption.id,
                kind: interruption.kind
            )
        }

        if console.focus.current != .runs,
           let kind = documentKind(
            for: key
           ),
           let document = matchingDocument(
            kind: kind
           ) {
            openDocument(
                document
            )

            return .documentOpened(
                documentID: document.id,
                kind: document.kind
            )
        }

        guard let event = console.handle(
            key
        ) else {
            return nil
        }

        return .base(
            event
        )
    }

    mutating func handleActions(
        _ key: TerminalKey
    ) -> AgenticHostConsoleWorkflowEvent? {
        if key == .escape {
            return closeInterruption()
        }

        if let kind = documentKind(
            for: key
        ),
           let document = matchingDocument(
            kind: kind
           ) {
            openDocument(
                document
            )

            return .documentOpened(
                documentID: document.id,
                kind: document.kind
            )
        }

        guard let event = actions.handle(
            key
        ) else {
            return nil
        }

        switch event {
        case .currentChanged:
            return nil

        case .accepted(let rawValue):
            guard let action = AgenticHostConsoleAction(
                rawValue: rawValue
            ),
                  let interruption = currentInterruption else {
                return nil
            }

            return .actionRequested(
                interruptionID: interruption.id,
                runID: interruption.runID,
                stepID: interruption.stepID,
                action: action
            )

        case .cancelRequested:
            return closeInterruption()
        }
    }

    mutating func handleDocument(
        _ key: TerminalKey
    ) -> AgenticHostConsoleWorkflowEvent? {
        if key == .escape {
            return closeDocument()
        }

        let motion: TerminalMotion?

        switch key {
        case .up,
             .char("k"):
            motion = .up

        case .down,
             .char("j"):
            motion = .down

        case .pageUp:
            motion = .pageUp

        case .pageDown:
            motion = .pageDown

        case .home:
            motion = .documentStart

        case .end:
            motion = .documentEnd

        default:
            motion = nil
        }

        if let motion {
            _ = document.handle(
                .motion(
                    motion
                )
            )
        }

        return nil
    }

    func matchingInterruption() -> AgenticHostConsoleInterruptionPresentation? {
        guard let currentRunID,
              let currentStepID else {
            return nil
        }

        return console.snapshot.interruptions.first {
            $0.runID == currentRunID
                && $0.stepID == currentStepID
        }
    }

    func matchingDocument(
        kind: AgenticHostConsoleDocumentKind
    ) -> AgenticHostConsoleDocumentPresentation? {
        guard let currentRunID,
              let currentStepID else {
            return nil
        }

        return console.snapshot.documents.first {
            $0.runID == currentRunID
                && $0.stepID == currentStepID
                && $0.kind == kind
        }
    }

    func documentKind(
        for key: TerminalKey
    ) -> AgenticHostConsoleDocumentKind? {
        switch key {
        case .char("d"):
            return .details

        case .char("f"):
            return .diff

        case .char("o"):
            return .stdout

        case .char("e"):
            return .stderr

        default:
            return nil
        }
    }

    mutating func openInterruption(
        _ interruption: AgenticHostConsoleInterruptionPresentation
    ) {
        openedInterruptionID = interruption.id
        actions.updateItems(
            interruption.actions,
            preservingCurrent: false
        )
        focus.push(
            .actions
        )
    }

    mutating func closeInterruption() -> AgenticHostConsoleWorkflowEvent? {
        guard let openedInterruptionID else {
            return nil
        }

        self.openedInterruptionID = nil
        actions.updateItems(
            [],
            preservingCurrent: false
        )
        _ = focus.pop()

        return .interruptionClosed(
            id: openedInterruptionID
        )
    }

    mutating func openDocument(
        _ document: AgenticHostConsoleDocumentPresentation
    ) {
        openedDocumentID = document.id
        self.document.moveToStart()
        focus.push(
            .document
        )
    }

    mutating func closeDocument() -> AgenticHostConsoleWorkflowEvent? {
        guard let document = currentDocument else {
            return nil
        }

        openedDocumentID = nil
        _ = focus.pop()

        return .documentClosed(
            documentID: document.id,
            kind: document.kind
        )
    }

    mutating func closeAllWorkflowSurfaces() {
        openedInterruptionID = nil
        openedDocumentID = nil
        actions.updateItems(
            [],
            preservingCurrent: false
        )
        focus.reset(
            to: .base
        )
    }

    mutating func renderInterruption(
        into frame: inout TerminalFrame,
        in region: TerminalRegion
    ) {
        guard let interruption = currentInterruption else {
            return
        }

        let columns = min(
            max(
                36,
                region.columns / 2
            ),
            max(
                1,
                region.columns - 4
            )
        )
        let contentInsets = TerminalInsets(
            vertical: 1,
            horizontal: 2
        )
        let contentColumns = max(
            1,
            columns
                - 2
                - contentInsets.leading
                - contentInsets.trailing
        )
        let interruptionSummaryLines = wrappedProseLines(
            interruption.summary,
            columns: contentColumns,
            style: .dim
        )
        let actionRows = actions.rows()
        let maximumActionSummaryRows = interruption.actions
            .map {
                wrappedProseLines(
                    $0.summary,
                    columns: contentColumns
                ).count
            }
            .max() ?? 0
        let actionSummaryLines = currentAction.map {
            wrappedProseLines(
                $0.summary,
                columns: contentColumns,
                style: .dim
            )
        } ?? []

        var desiredContentRows =
            1
            + interruptionSummaryLines.count
            + 1
            + actionRows.count

        if currentAction != nil {
            desiredContentRows += 1 + maximumActionSummaryRows
        }

        let rows = min(
            max(
                12,
                desiredContentRows
                    + 2
                    + contentInsets.top
                    + contentInsets.bottom
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
            contentInsets: contentInsets
        )
        let content = overlay.render(
            into: &frame,
            in: region,
            title: interruption.title,
            zIndex: .overlay
        )
        var lines = [
            TerminalStyle.bold.apply(
                interruption.kind.displayTitle
            ),
        ]

        lines.append(
            contentsOf: interruptionSummaryLines
        )
        lines.append(
            ""
        )
        lines.append(
            contentsOf: actionRows.map(
                actionLine
            )
        )

        if currentAction != nil {
            lines.append(
                ""
            )
            lines.append(
                contentsOf: actionSummaryLines
            )
        }

        frame.write(
            lines,
            in: content,
            zIndex: .overlay
        )
    }

    mutating func renderDocument(
        into frame: inout TerminalFrame,
        in region: TerminalRegion
    ) {
        guard let currentDocument else {
            return
        }

        let columns = min(
            max(
                40,
                region.columns * 2 / 3
            ),
            max(
                1,
                region.columns - 4
            )
        )
        let overlay = TerminalOverlay(
            placement: .trailing(
                columns: columns
            ),
            outerInsets: TerminalInsets(
                vertical: 1,
                horizontal: 1
            ),
            contentInsets: TerminalInsets(
                vertical: 1,
                horizontal: 2
            )
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
        document.render(
            into: &frame,
            in: content,
            zIndex: documentLayer
        )
    }

    func renderFooter(
        into frame: inout TerminalFrame,
        in region: TerminalRegion
    ) {
        guard region.rows > 0 else {
            return
        }

        let footer = TerminalRegion(
            top: region.top + region.rows - 1,
            leading: region.leading,
            rows: 1,
            columns: region.columns
        )
        let text: String

        switch focus.current {
        case .actions:
            text = "j/k select  enter choose  d details  f diff  o stdout  e stderr  esc back  ctrl-c quit"

        case .document:
            text = "j/k scroll  pgup/pgdn  home/end  esc back  ctrl-c quit"

        case .base:
            if console.focus.current == .inspector {
                text = "j/k scroll  d details  f diff  o stdout  e stderr  esc back  ctrl-c quit"
            } else {
                text = "j/k select  h/← runs  l/→ plan  enter inspect  a actions  d/f/o/e docs  ctrl-c quit"
            }
        }

        frame.write(
            TerminalStyle.dim.apply(
                text
            ),
            in: footer,
            zIndex: .overlay
        )
    }

    func wrappedProseLines(
        _ text: String,
        columns: Int,
        style: TerminalStyle? = nil
    ) -> [String] {
        let lines = TerminalTextWrap.lines(
            text,
            width: max(
                1,
                columns
            )
        )

        guard let style else {
            return lines
        }

        return style.apply(
            lines: lines
        )
    }

    func actionLine(
        _ row: TerminalListControlRow<
            AgenticHostConsoleAction,
            String
        >
    ) -> String {
        let text = (row.isCurrent ? "> " : "  ")
            + row.item.title

        if row.isCurrent {
            return TerminalStyle(
                .inverse
            ).apply(
                text
            )
        }

        switch row.item {
        case .approve,
             .retry,
             .createFixBranch:
            return TerminalStyle.bold.apply(
                text
            )

        case .deny,
             .stopRun:
            return TerminalStyle(
                .red
            ).apply(
                text
            )

        case .skip:
            return TerminalStyle.dim.apply(
                text
            )
        }
    }
}

private extension AgenticHostConsoleInterruptionKind {
    var displayTitle: String {
        switch self {
        case .approval:
            return "approval required"

        case .recovery:
            return "run on hold"
        }
    }
}
