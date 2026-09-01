import Terminal

public enum AgenticHostConsoleWorkflowFocus:
    Sendable,
    Hashable
{
    case base
    case runControls
    case actions
    case document
    case runInspector
    case diagnostic
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
    case runControlsOpened(
        runID: String
    )
    case runControlsClosed(
        runID: String
    )
    case runControlRequested(
        runID: String,
        control: AgenticHostConsoleRunControl
    )
    case documentRequested(
        runID: String,
        stepID: String,
        kind: AgenticHostConsoleDocumentKind
    )
    case documentOpened(
        documentID: String,
        kind: AgenticHostConsoleDocumentKind
    )
    case documentClosed(
        documentID: String,
        kind: AgenticHostConsoleDocumentKind
    )
    case statusOpened(
        statusID: String
    )
    case statusClosed(
        statusID: String
    )
    case feedbackRequested(
        message: String
    )
    case copyRequested(
        text: String,
        title: String
    )
    case runInspectionOpened(
        runID: String
    )
    case runInspectionClosed(
        runID: String
    )
    case runInputCopyRequested(
        runID: String
    )
    case runOutputCopyRequested(
        runID: String
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
    private var runControls: TerminalListControl<
        AgenticHostConsoleRunControl,
        String
    >
    private var document: TerminalScrollableDocument
    private var runInspector: TerminalScrollableDocument
    private var diagnostic: TerminalScrollableDocument
    private var openedRunControlRunID: String?
    private var openedInterruptionID: String?
    private var openedDocumentID: String?
    private var openedRunInspectorRunID: String?
    private var openedStatusID: String?

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
        self.runControls = TerminalListControl(
            items: [],
            id: {
                $0.rawValue
            }
        )
        self.document = TerminalScrollableDocument()
        self.runInspector = TerminalScrollableDocument()
        self.diagnostic = TerminalScrollableDocument()
        self.openedRunControlRunID = nil
        self.openedInterruptionID = nil
        self.openedDocumentID = nil
        self.openedRunInspectorRunID = nil
        self.openedStatusID = nil
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

    public var currentRunControl: AgenticHostConsoleRunControl? {
        runControls.currentItem
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

    public var currentStatus: AgenticHostConsoleStatusPresentation? {
        guard let openedStatusID else {
            return console.currentStatus
        }

        return console.snapshot.statuses.first {
            $0.id == openedStatusID
        }
    }

    public mutating func update(
        _ snapshot: AgenticHostConsoleSnapshot
    ) {
        console.update(
            snapshot
        )

        if let openedRunControlRunID {
            guard let run = snapshot.runs.first(
                where: {
                    $0.id == openedRunControlRunID
                }
            ), !run.state.executionControls.isEmpty else {
                self.openedRunControlRunID = nil
                runControls.updateItems(
                    [],
                    preservingCurrent: false
                )
                focus.reset(
                    to: .base
                )
                return
            }

            runControls.updateItems(
                run.state.executionControls,
                preservingCurrent: true
            )
        }

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

        if let openedStatusID,
           !snapshot.statuses.contains(
            where: {
                $0.id == openedStatusID
            }
           ) {
            self.openedStatusID = nil
            focus.reset(
                to: .base
            )
        }

        if let openedRunInspectorRunID,
           !snapshot.runs.contains(
            where: {
                $0.id == openedRunInspectorRunID
            }
           ) {
            self.openedRunInspectorRunID = nil
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

        case .runControls:
            return handleRunControls(
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

        case .runInspector:
            return handleRunInspector(
                key
            )

        case .diagnostic:
            return handleDiagnostic(
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

        if openedRunControlRunID != nil {
            renderRunControls(
                into: &frame,
                in: region
            )
        }

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

        if openedRunInspectorRunID != nil {
            renderRunInspector(
                into: &frame,
                in: region
            )
        }

        if openedStatusID != nil {
            renderDiagnostic(
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
        if key == .char("x") {
            guard let run = console.currentRun,
                  !run.state.executionControls.isEmpty else {
                return .feedbackRequested(
                    message: "No run controls available."
                )
            }

            openRunControls(
                run
            )

            return .runControlsOpened(
                runID: run.id
            )
        }

        if key == .char("a") {
            guard let interruption = matchingInterruption() else {
                return .feedbackRequested(
                    message: "No actions available."
                )
            }

            openInterruption(
                interruption
            )

            return .interruptionOpened(
                id: interruption.id,
                kind: interruption.kind
            )
        }

        if let kind = documentKind(
            for: key
        ) {
            if let document = matchingDocument(
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

            if let currentRunID,
               let currentStepID {
                return .documentRequested(
                    runID: currentRunID,
                    stepID: currentStepID,
                    kind: kind
                )
            }

            return .feedbackRequested(
                message: "No document available for the current selection."
            )
        }

        guard let event = console.handle(
            key
        ) else {
            return nil
        }

        if case .runInspectionOpened(let runID) = event {
            guard let run = console.snapshot.runs.first(
                where: {
                    $0.id == runID
                }
            ) else {
                return .feedbackRequested(
                    message: "Run is no longer available."
                )
            }

            openRunInspector(
                run
            )

            return .runInspectionOpened(
                runID: run.id
            )
        }

        if case .statusInspectionOpened(let statusID) = event {
            guard let status = console.snapshot.statuses.first(
                where: {
                    $0.id == statusID
                }
            ) else {
                return .feedbackRequested(
                    message: "Status is no longer available."
                )
            }

            openDiagnostic(
                status
            )

            return .statusOpened(
                statusID: status.id
            )
        }

        return .base(
            event
        )
    }

    mutating func handleRunControls(
        _ key: TerminalKey
    ) -> AgenticHostConsoleWorkflowEvent? {
        if key == .escape || key == .char("q") {
            return closeRunControls()
        }

        guard let event = runControls.handle(
            key
        ) else {
            return nil
        }

        switch event {
        case .currentChanged:
            return nil

        case .accepted(let rawValue):
            guard let control = AgenticHostConsoleRunControl(
                rawValue: rawValue
            ), let runID = openedRunControlRunID else {
                return nil
            }

            self.openedRunControlRunID = nil
            runControls.updateItems(
                [],
                preservingCurrent: false
            )
            _ = focus.pop()

            return .runControlRequested(
                runID: runID,
                control: control
            )

        case .cancelRequested:
            return closeRunControls()
        }
    }

    mutating func handleActions(
        _ key: TerminalKey
    ) -> AgenticHostConsoleWorkflowEvent? {
        if key == .escape || key == .char("q") {
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
        if key == .escape || key == .char("q") {
            return closeDocument()
        }

        if let currentDocument,
           let siblingKind = siblingDocumentKind(
            from: currentDocument.kind,
            key: key
           ) {
            if let sibling = matchingDocument(
                runID: currentDocument.runID,
                stepID: currentDocument.stepID,
                kind: siblingKind
            ) {
                switchDocument(
                    sibling
                )

                return .documentOpened(
                    documentID: sibling.id,
                    kind: sibling.kind
                )
            }

            return .documentRequested(
                runID: currentDocument.runID,
                stepID: currentDocument.stepID,
                kind: siblingKind
            )
        }

        if key == .char("c"),
           let currentDocument {
            return .copyRequested(
                text: currentDocument.body,
                title: currentDocument.title
            )
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

    mutating func handleRunInspector(
        _ key: TerminalKey
    ) -> AgenticHostConsoleWorkflowEvent? {
        if key == .escape || key == .char("q") {
            return closeRunInspector()
        }

        guard let openedRunInspectorRunID else {
            return nil
        }

        if key == .char("i") {
            return .runInputCopyRequested(
                runID: openedRunInspectorRunID
            )
        }

        if key == .char("o") {
            return .runOutputCopyRequested(
                runID: openedRunInspectorRunID
            )
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
            _ = runInspector.handle(
                .motion(
                    motion
                )
            )
        }

        return nil
    }

    mutating func handleDiagnostic(
        _ key: TerminalKey
    ) -> AgenticHostConsoleWorkflowEvent? {
        if key == .escape || key == .char("q") {
            return closeDiagnostic()
        }

        if key == .char("c"),
           let currentStatus {
            return .copyRequested(
                text: currentStatus.body,
                title: currentStatus.title
            )
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
            _ = diagnostic.handle(
                .motion(
                    motion
                )
            )
        }

        return nil
    }

    func matchingInterruption() -> AgenticHostConsoleInterruptionPresentation? {
        guard let currentRunID else {
            return nil
        }

        if let currentStepID,
           let exact = console.snapshot.interruptions.first(where: {
            $0.runID == currentRunID
                && $0.stepID == currentStepID
           }) {
            return exact
        }

        return console.snapshot.interruptions.first {
            $0.runID == currentRunID
        }
    }

    func matchingDocument(
        kind: AgenticHostConsoleDocumentKind
    ) -> AgenticHostConsoleDocumentPresentation? {
        guard let currentRunID else {
            return nil
        }

        if let currentStepID,
           let exact = console.snapshot.documents.first(where: {
            $0.runID == currentRunID
                && $0.stepID == currentStepID
                && $0.kind == kind
           }) {
            return exact
        }

        guard let interruptedStepID = console.snapshot.interruptions.first(
            where: {
                $0.runID == currentRunID
            }
        )?.stepID else {
            return nil
        }

        return console.snapshot.documents.first {
            $0.runID == currentRunID
                && $0.stepID == interruptedStepID
                && $0.kind == kind
        }
    }

    func matchingDocument(
        runID: String,
        stepID: String,
        kind: AgenticHostConsoleDocumentKind
    ) -> AgenticHostConsoleDocumentPresentation? {
        console.snapshot.documents.first {
            $0.runID == runID
                && $0.stepID == stepID
                && $0.kind == kind
        }
    }

    func siblingDocumentKind(
        from kind: AgenticHostConsoleDocumentKind,
        key: TerminalKey
    ) -> AgenticHostConsoleDocumentKind? {
        switch key {
        case .char("h"):
            switch kind {
            case .details:
                return nil

            case .diff:
                return .details

            case .stdout:
                return .diff

            case .stderr:
                return .stdout
            }

        case .char("l"):
            switch kind {
            case .details:
                return .diff

            case .diff:
                return .stdout

            case .stdout:
                return .stderr

            case .stderr:
                return nil
            }

        default:
            return nil
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

    mutating func openRunControls(
        _ run: AgenticHostConsoleRunPresentation
    ) {
        openedRunControlRunID = run.id
        runControls.updateItems(
            run.state.executionControls,
            preservingCurrent: false
        )
        focus.push(
            .runControls
        )
    }

    mutating func closeRunControls() -> AgenticHostConsoleWorkflowEvent? {
        guard let openedRunControlRunID else {
            return nil
        }

        self.openedRunControlRunID = nil
        runControls.updateItems(
            [],
            preservingCurrent: false
        )
        _ = focus.pop()

        return .runControlsClosed(
            runID: openedRunControlRunID
        )
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

    mutating func switchDocument(
        _ document: AgenticHostConsoleDocumentPresentation
    ) {
        openedDocumentID = document.id
        self.document.moveToStart()
    }

    mutating func openDocument(
        _ document: AgenticHostConsoleDocumentPresentation
    ) {
        switchDocument(
            document
        )
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

    mutating func openRunInspector(
        _ run: AgenticHostConsoleRunPresentation
    ) {
        openedRunInspectorRunID = run.id
        runInspector.moveToStart()
        focus.push(
            .runInspector
        )
    }

    mutating func closeRunInspector() -> AgenticHostConsoleWorkflowEvent? {
        guard let openedRunInspectorRunID else {
            return nil
        }

        self.openedRunInspectorRunID = nil
        _ = focus.pop()

        return .runInspectionClosed(
            runID: openedRunInspectorRunID
        )
    }

    mutating func openDiagnostic(
        _ status: AgenticHostConsoleStatusPresentation
    ) {
        openedStatusID = status.id
        diagnostic.moveToStart()
        focus.push(
            .diagnostic
        )
    }

    mutating func closeDiagnostic() -> AgenticHostConsoleWorkflowEvent? {
        guard let openedStatusID else {
            return nil
        }

        self.openedStatusID = nil
        _ = focus.pop()

        return .statusClosed(
            statusID: openedStatusID
        )
    }

    mutating func closeAllWorkflowSurfaces() {
        openedRunControlRunID = nil
        openedInterruptionID = nil
        openedDocumentID = nil
        openedRunInspectorRunID = nil
        openedStatusID = nil
        runControls.updateItems(
            [],
            preservingCurrent: false
        )
        actions.updateItems(
            [],
            preservingCurrent: false
        )
        focus.reset(
            to: .base
        )
    }

    mutating func renderRunControls(
        into frame: inout TerminalFrame,
        in region: TerminalRegion
    ) {
        guard let openedRunControlRunID,
              let run = console.snapshot.runs.first(
                where: {
                    $0.id == openedRunControlRunID
                }
              ) else {
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
        let runSummaryLines = run.summary.map {
            wrappedProseLines(
                $0,
                columns: contentColumns,
                style: .dim
            )
        } ?? []
        let controlRows = runControls.rows()
        let maximumControlSummaryRows = run.state.executionControls
            .map {
                wrappedProseLines(
                    $0.summary,
                    columns: contentColumns
                ).count
            }
            .max() ?? 0
        let controlSummaryLines = currentRunControl.map {
            wrappedProseLines(
                $0.summary,
                columns: contentColumns,
                style: .dim
            )
        } ?? []

        var desiredContentRows =
            1
            + runSummaryLines.count
            + 1
            + controlRows.count

        if currentRunControl != nil {
            desiredContentRows += 1 + maximumControlSummaryRows
        }

        let rows = min(
            max(
                10,
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
            title: "Run control",
            zIndex: .overlay
        )

        var lines = [
            TerminalStyle.bold.apply(
                run.title
            ),
        ]

        if !runSummaryLines.isEmpty {
            lines.append(
                contentsOf: runSummaryLines
            )
        }

        lines.append("")
        lines.append(
            contentsOf: controlRows.map(
                runControlLine
            )
        )

        if currentRunControl != nil {
            lines.append("")
            lines.append(
                contentsOf: controlSummaryLines
            )
        }

        frame.write(
            lines,
            in: content,
            zIndex: .overlay
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

    mutating func renderRunInspector(
        into frame: inout TerminalFrame,
        in region: TerminalRegion
    ) {
        guard let openedRunInspectorRunID,
              let run = console.snapshot.runs.first(
                where: {
                    $0.id == openedRunInspectorRunID
                }
              ) else {
            return
        }

        let overlay =
            AgenticHostConsoleInspectionSurface.overlay(
                in: region
            )
        let runInspectorLayer = TerminalZIndex(
            220
        )
        let content = overlay.render(
            into: &frame,
            in: region,
            title: "Run · \(run.title)",
            zIndex: runInspectorLayer
        )

        var lines = [
            "run        \(run.id)",
            "state      \(run.state.rawValue)",
        ]

        if let summary = run.summary,
           !summary.isEmpty {
            lines.append(
                "summary    \(summary)"
            )
        }

        lines.append(
            ""
        )
        lines.append(
            "Authored steps"
        )

        if run.steps.isEmpty {
            lines.append(
                "No authored steps."
            )
        } else {
            for (
                index,
                step
            ) in run.steps.enumerated() {
                lines.append(
                    "\(index + 1). \(step.title)  [\(step.state.rawValue)]"
                )

                if let detail = step.detail,
                   !detail.isEmpty {
                    lines.append(
                        "   \(detail)"
                    )
                }
            }
        }

        runInspector.update(
            text: lines.joined(
                separator: "\n"
            ),
            columns: content.columns,
            visibleRows: content.rows,
            wrapping: .word
        )
        runInspector.render(
            into: &frame,
            in: content,
            zIndex: runInspectorLayer
        )
    }

    mutating func renderDiagnostic(
        into frame: inout TerminalFrame,
        in region: TerminalRegion
    ) {
        guard let currentStatus else {
            return
        }

        let overlay =
            AgenticHostConsoleInspectionSurface.overlay(
                in: region
            )
        let diagnosticLayer = TerminalZIndex(
            210
        )
        let content = overlay.render(
            into: &frame,
            in: region,
            title: currentStatus.title,
            zIndex: diagnosticLayer
        )

        diagnostic.update(
            text: currentStatus.body,
            columns: content.columns,
            visibleRows: content.rows,
            wrapping: .word
        )
        diagnostic.render(
            into: &frame,
            in: content,
            zIndex: diagnosticLayer
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
        case .runControls:
            text = "j/k select  enter choose  q back  ctrl-c quit"

        case .actions:
            text = "j/k select  enter choose  d details  f diff  o stdout  e stderr  q back  ctrl-c quit"

        case .document:
            text = "h/l view  j/k scroll  pgup/pgdn  home/end  c copy  q back  ctrl-c quit"

        case .runInspector:
            text = "j/k scroll  pgup/pgdn  home/end  i input  o output  q back  ctrl-c quit"

        case .diagnostic:
            text = "j/k scroll  pgup/pgdn  home/end  c copy  q back  ctrl-c quit"

        case .base:
            if console.focus.current == .inspector {
                text = "j/k scroll  d details  f diff  o stdout  e stderr  q back  ctrl-c quit"
            } else {
                text = "tab focus  j/k select  h/← previous  l/→ next  enter inspect  x run  a actions  d/f/o/e docs  ctrl-c quit"
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

    func runControlLine(
        _ row: TerminalListControlRow<
            AgenticHostConsoleRunControl,
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

        return text
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
             .continueRun,
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
