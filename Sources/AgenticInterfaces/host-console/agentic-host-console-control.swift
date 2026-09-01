import Terminal

public enum AgenticHostConsoleFocus:
    Sendable,
    Hashable
{
    case runs
    case timeline
    case status
    case inspector
}

public enum AgenticHostConsoleEvent:
    Sendable,
    Hashable
{
    case exitRequested
    case runSelectionChanged(String)
    case stepSelectionChanged(
        runID: String,
        stepID: String
    )
    case stepInspectionOpened(
        runID: String,
        stepID: String
    )
    case stepInspectionClosed
    case runInspectionOpened(
        runID: String
    )
    case statusInspectionOpened(
        statusID: String
    )
}

public struct AgenticHostConsoleControl:
    Sendable
{
    public private(set) var snapshot: AgenticHostConsoleSnapshot
    public private(set) var focus: TerminalFocusStack<AgenticHostConsoleFocus>

    private var runs: TerminalListControl<
        AgenticHostConsoleRunPresentation,
        String
    >
    private var steps: TerminalListControl<
        AgenticHostConsoleStepPresentation,
        String
    >
    private var statuses: TerminalListControl<
        AgenticHostConsoleStatusPresentation,
        String
    >
    private var runsDocument: TerminalScrollableDocument
    private var timelineDocument: TerminalScrollableDocument
    private var statusDocument: TerminalScrollableDocument
    private var inspectorDocument: TerminalScrollableDocument
    private var inspectedStepID: String?
    private var isRunHeaderSelected: Bool

    public init(
        snapshot: AgenticHostConsoleSnapshot,
        currentRunID: String? = nil,
        currentStepID: String? = nil
    ) {
        let runID = Self.preferredRunID(
            in: snapshot,
            requested: currentRunID
        )
        let run = snapshot.runs.first {
            $0.id == runID
        }
        let stepID = Self.preferredStepID(
            in: run,
            requested: currentStepID
        )

        self.snapshot = snapshot
        self.focus = TerminalFocusStack(
            .runs
        )
        self.runs = TerminalListControl(
            items: snapshot.runs,
            currentID: runID,
            id: {
                $0.id
            }
        )
        self.steps = TerminalListControl(
            items: run?.steps ?? [],
            currentID: stepID,
            id: {
                $0.id
            }
        )
        self.statuses = TerminalListControl(
            items: snapshot.statuses,
            id: {
                $0.id
            }
        )
        self.runsDocument = TerminalScrollableDocument()
        self.timelineDocument = TerminalScrollableDocument()
        self.statusDocument = TerminalScrollableDocument()
        self.inspectorDocument = TerminalScrollableDocument()
        self.inspectedStepID = nil
        self.isRunHeaderSelected = false
    }

    public var currentRunID: String? {
        runs.currentID
    }

    public var runHeaderSelected: Bool {
        isRunHeaderSelected
    }

    public var currentStepID: String? {
        isRunHeaderSelected
            ? nil
            : steps.currentID
    }

    public var currentRun: AgenticHostConsoleRunPresentation? {
        guard let currentRunID else {
            return nil
        }

        return snapshot.runs.first {
            $0.id == currentRunID
        }
    }

    public var currentStep: AgenticHostConsoleStepPresentation? {
        guard let currentStepID else {
            return nil
        }

        return currentRun?.steps.first {
            $0.id == currentStepID
        }
    }

    public var currentStatusID: String? {
        statuses.currentID
    }

    public var currentStatus: AgenticHostConsoleStatusPresentation? {
        statuses.currentItem
    }

    public mutating func update(
        _ snapshot: AgenticHostConsoleSnapshot
    ) {
        let previousRunID = currentRunID
        let previousStepID = currentStepID
        let wasFollowingActiveStep = currentStep?.state == .active
        let preferredRunID = Self.preferredRunID(
            in: snapshot,
            requested: previousRunID
        )

        self.snapshot = snapshot
        runs.updateItems(
            snapshot.runs,
            preservingCurrent: false
        )

        if let preferredRunID {
            _ = runs.select(
                id: preferredRunID
            )
        }

        let preservesStep = previousRunID == currentRunID
        let activeStepID = currentRun?.steps.first(
            where: {
                $0.state == .active
            }
        )?.id
        let requestedStepID: String?

        if preservesStep,
           wasFollowingActiveStep,
           let activeStepID {
            requestedStepID = activeStepID
        } else {
            requestedStepID = preservesStep
                ? previousStepID
                : nil
        }

        rebuildSteps(
            requestedStepID: requestedStepID
        )

        if previousRunID != currentRunID {
            isRunHeaderSelected = false
        }

        statuses.updateItems(
            snapshot.statuses,
            preservingCurrent: true
        )

        if snapshot.statuses.isEmpty,
           focus.current == .status {
            focus.replace(
                .timeline
            )
        }

        if let inspectedStepID,
           currentRun?.steps.contains(
            where: {
                $0.id == inspectedStepID
            }
           ) != true {
            self.inspectedStepID = nil

            if focus.current == .inspector {
                _ = focus.pop()
            }
        }
    }

    public mutating func handle(
        _ key: TerminalKey
    ) -> AgenticHostConsoleEvent? {
        if key == .control("C") {
            return .exitRequested
        }

        if key == .tab,
           focus.current != .inspector {
            cycleBaseFocus()
            return nil
        }

        switch focus.current {
        case .runs:
            return handleRuns(
                key
            )

        case .timeline:
            return handleTimeline(
                key
            )

        case .status:
            return handleStatus(
                key
            )

        case .inspector:
            return handleInspector(
                key
            )
        }
    }

    public mutating func render(
        into frame: inout TerminalFrame,
        in region: TerminalRegion
    ) {
        guard !region.isEmpty else {
            return
        }

        let vertical = TerminalLayout.vertical(
            in: region,
            [
                .fixed(3),
                .flex(1),
                .fixed(1),
            ]
        )

        guard vertical.count == 3 else {
            return
        }

        renderHeader(
            into: &frame,
            in: vertical[0]
        )
        renderBody(
            into: &frame,
            in: vertical[1]
        )
        renderFooter(
            into: &frame,
            in: vertical[2]
        )

        if focus.current == .inspector {
            renderInspector(
                into: &frame,
                in: vertical[1]
            )
        }
    }
}

private extension AgenticHostConsoleControl {
    mutating func handleRuns(
        _ key: TerminalKey
    ) -> AgenticHostConsoleEvent? {
        if key.isHorizontalNext {
            focus.replace(
                .timeline
            )
            return nil
        }

        guard let event = runs.handle(
            key
        ) else {
            return nil
        }

        switch event {
        case .currentChanged(let runID):
            rebuildSteps(
                requestedStepID: nil
            )
            isRunHeaderSelected = false

            return .runSelectionChanged(
                runID
            )

        case .accepted:
            focus.replace(
                .timeline
            )
            return nil

        case .cancelRequested:
            return .exitRequested
        }
    }

    mutating func handleTimeline(
        _ key: TerminalKey
    ) -> AgenticHostConsoleEvent? {
        if key.isHorizontalPrevious {
            focus.replace(
                .runs
            )
            return nil
        }

        if key.isHorizontalNext,
           !snapshot.statuses.isEmpty {
            focus.replace(
                .status
            )
            return nil
        }

        if isRunHeaderSelected {
            switch key {
            case .down,
                 .char("j"):
                guard let runID = currentRunID,
                      let stepID = steps.currentID else {
                    return nil
                }

                isRunHeaderSelected = false

                return .stepSelectionChanged(
                    runID: runID,
                    stepID: stepID
                )

            case .enter:
                guard let runID = currentRunID else {
                    return nil
                }

                return .runInspectionOpened(
                    runID: runID
                )

            case .up,
                 .char("k"):
                return nil

            default:
                return nil
            }
        }

        if (key == .up || key == .char("k")),
           steps.currentIndex == 0 {
            isRunHeaderSelected = true
            return nil
        }

        guard let event = steps.handle(
            key
        ) else {
            return nil
        }

        switch event {
        case .currentChanged(let stepID):
            isRunHeaderSelected = false

            guard let runID = currentRunID else {
                return nil
            }

            return .stepSelectionChanged(
                runID: runID,
                stepID: stepID
            )

        case .accepted(let stepID):
            isRunHeaderSelected = false

            guard let runID = currentRunID else {
                return nil
            }

            inspectedStepID = stepID
            inspectorDocument.moveToStart()
            focus.push(
                .inspector
            )

            return .stepInspectionOpened(
                runID: runID,
                stepID: stepID
            )

        case .cancelRequested:
            focus.replace(
                .runs
            )
            return nil
        }
    }

    mutating func handleStatus(
        _ key: TerminalKey
    ) -> AgenticHostConsoleEvent? {
        if key.isHorizontalPrevious {
            focus.replace(
                .timeline
            )
            return nil
        }

        guard let event = statuses.handle(
            key
        ) else {
            return nil
        }

        switch event {
        case .currentChanged:
            return nil

        case .accepted(let statusID):
            return .statusInspectionOpened(
                statusID: statusID
            )

        case .cancelRequested:
            focus.replace(
                .timeline
            )
            return nil
        }
    }

    mutating func handleInspector(
        _ key: TerminalKey
    ) -> AgenticHostConsoleEvent? {
        if key == .escape || key == .char("q") {
            inspectedStepID = nil
            _ = focus.pop()
            return .stepInspectionClosed
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
            _ = inspectorDocument.handle(
                .motion(
                    motion
                )
            )
        }

        return nil
    }

    mutating func rebuildSteps(
        requestedStepID: String?
    ) {
        let run = currentRun
        let preferred = Self.preferredStepID(
            in: run,
            requested: requestedStepID
        )

        steps.updateItems(
            run?.steps ?? [],
            preservingCurrent: false
        )

        if let preferred {
            _ = steps.select(
                id: preferred
            )
        }
    }

    func renderHeader(
        into frame: inout TerminalFrame,
        in region: TerminalRegion
    ) {
        var lines = [
            TerminalStyle.bold.apply(
                snapshot.title
            ),
        ]

        if let context = snapshot.context,
           !context.isEmpty {
            lines.append(
                TerminalStyle.dim.apply(
                    context
                )
            )
        }

        frame.write(
            lines,
            in: region
        )
    }

    mutating func renderBody(
        into frame: inout TerminalFrame,
        in region: TerminalRegion
    ) {
        let runColumns = min(
            30,
            max(
                18,
                region.columns / 4
            )
        )

        if snapshot.statuses.isEmpty {
            let horizontal = TerminalLayout.horizontal(
                in: region,
                [
                    .fixed(runColumns),
                    .flex(1),
                ],
                spacing: 3
            )

            guard horizontal.count == 2 else {
                return
            }

            renderRuns(
                into: &frame,
                in: horizontal[0]
            )
            renderTimeline(
                into: &frame,
                in: horizontal[1]
            )
            return
        }

        let statusColumns = min(
            34,
            max(
                22,
                region.columns / 4
            )
        )
        let horizontal = TerminalLayout.horizontal(
            in: region,
            [
                .fixed(runColumns),
                .flex(1),
                .fixed(statusColumns),
            ],
            spacing: 3
        )

        guard horizontal.count == 3 else {
            return
        }

        renderRuns(
            into: &frame,
            in: horizontal[0]
        )
        renderTimeline(
            into: &frame,
            in: horizontal[1]
        )
        renderStatus(
            into: &frame,
            in: horizontal[2]
        )
    }

    mutating func renderRuns(
        into frame: inout TerminalFrame,
        in region: TerminalRegion
    ) {
        let vertical = TerminalLayout.vertical(
            in: region,
            [
                .fixed(2),
                .flex(1),
            ]
        )

        guard vertical.count == 2 else {
            return
        }

        frame.write(
            TerminalStyle.bold.apply(
                "runs"
            ),
            in: vertical[0]
        )

        let lines = runs.rows().map {
            row in

            runLine(
                row
            )
        }

        runsDocument.update(
            lines: lines,
            visibleRows: vertical[1].rows
        )

        if let currentIndex = runs.currentIndex {
            runsDocument.reveal(
                row: currentIndex,
                margin: min(
                    1,
                    max(
                        0,
                        vertical[1].rows - 1
                    )
                )
            )
        }

        runsDocument.render(
            into: &frame,
            in: vertical[1]
        )
    }

    mutating func renderTimeline(
        into frame: inout TerminalFrame,
        in region: TerminalRegion
    ) {
        let vertical = TerminalLayout.vertical(
            in: region,
            [
                .fixed(3),
                .flex(1),
            ]
        )

        guard vertical.count == 2 else {
            return
        }

        guard let run = currentRun else {
            frame.write(
                [
                    TerminalStyle.bold.apply(
                        "ToolPlan"
                    ),
                    TerminalStyle.dim.apply(
                        "no runs"
                    ),
                ],
                in: vertical[0]
            )
            return
        }

        let runTitle: String

        if focus.current == .timeline,
           isRunHeaderSelected {
            runTitle = TerminalStyle(
                .inverse
            ).apply(
                run.title
            )
        } else {
            runTitle = TerminalStyle.bold.apply(
                run.title
            )
        }

        var heading = [
            runTitle,
            runStateStyle(
                run.state
            ).apply(
                run.state.displayTitle
            ),
        ]

        if let summary = run.summary,
           !summary.isEmpty {
            heading.append(
                TerminalStyle.dim.apply(
                    summary
                )
            )
        }

        frame.write(
            heading,
            in: vertical[0]
        )

        let timeline = TerminalTimeline(
            items: run.steps.map {
                TerminalTimelineItem(
                    id: $0.id,
                    title: $0.title,
                    detail: $0.detail,
                    state: $0.state.terminalState
                )
            }
        )
        let layout = timeline.layout(
            width: vertical[1].columns,
            selectedID: isRunHeaderSelected
                ? nil
                : currentStepID
        )

        timelineDocument.update(
            lines: layout.lines,
            visibleRows: vertical[1].rows
        )

        if !isRunHeaderSelected,
           let currentStepID,
           let rows = layout.itemRows[
            currentStepID
           ] {
            timelineDocument.reveal(
                row: rows.lowerBound,
                margin: min(
                    1,
                    max(
                        0,
                        vertical[1].rows - 1
                    )
                )
            )
        }

        timelineDocument.render(
            into: &frame,
            in: vertical[1]
        )
    }

    mutating func renderStatus(
        into frame: inout TerminalFrame,
        in region: TerminalRegion
    ) {
        let vertical = TerminalLayout.vertical(
            in: region,
            [
                .fixed(2),
                .flex(1),
            ]
        )

        guard vertical.count == 2 else {
            return
        }

        frame.write(
            TerminalStyle.bold.apply(
                "Status"
            ),
            in: vertical[0]
        )

        let lines = statuses.rows().map(
            statusLine
        )

        statusDocument.update(
            lines: lines,
            visibleRows: vertical[1].rows
        )

        if let currentIndex = statuses.currentIndex {
            statusDocument.reveal(
                row: currentIndex,
                margin: min(
                    1,
                    max(
                        0,
                        vertical[1].rows - 1
                    )
                )
            )
        }

        statusDocument.render(
            into: &frame,
            in: vertical[1]
        )
    }

    func renderFooter(
        into frame: inout TerminalFrame,
        in region: TerminalRegion
    ) {
        let text: String

        if focus.current == .inspector {
            text = "j/k scroll  q back  ctrl-c quit"
        } else {
            text = "tab focus  j/k select  h/← previous  l/→ next  enter inspect  ctrl-c quit"
        }

        frame.write(
            TerminalStyle.dim.apply(
                text
            ),
            in: region
        )
    }

    mutating func renderInspector(
        into frame: inout TerminalFrame,
        in region: TerminalRegion
    ) {
        guard let run = currentRun,
              let inspectedStepID,
              let step = run.steps.first(
                where: {
                    $0.id == inspectedStepID
                }
              ) else {
            return
        }

        let columns = min(
            max(
                24,
                region.columns / 2
            ),
            max(
                0,
                region.columns - 4
            )
        )
        let overlay = TerminalOverlay(
            placement: .trailing(
                columns: columns
            ),
            outerInsets: TerminalInsets(
                vertical: 0,
                horizontal: 1
            ),
            contentInsets: TerminalInsets(
                vertical: 1,
                horizontal: 2
            )
        )
        let content = overlay.render(
            into: &frame,
            in: region,
            title: step.title
        )
        let lines = inspectorLines(
            run: run,
            step: step
        )

        inspectorDocument.update(
            lines: lines,
            visibleRows: content.rows
        )
        inspectorDocument.render(
            into: &frame,
            in: content
        )
    }

    func runLine(
        _ row: TerminalListControlRow<
            AgenticHostConsoleRunPresentation,
            String
        >
    ) -> String {
        let text = row.item.state.marker
            + " "
            + row.item.title

        if row.isCurrent {
            return focus.current == .runs
                ? TerminalStyle(
                    .inverse
                ).apply(
                    text
                )
                : TerminalStyle.bold.apply(
                    text
                )
        }

        return runStateStyle(
            row.item.state
        ).apply(
            text
        )
    }

    func statusLine(
        _ row: TerminalListControlRow<
            AgenticHostConsoleStatusPresentation,
            String
        >
    ) -> String {
        let marker: String

        switch row.item.kind {
        case .info:
            marker = "·"

        case .warning:
            marker = "!"

        case .error:
            marker = "×"
        }

        let text = marker
            + " "
            + row.item.title
            + (row.item.summary.isEmpty
                ? ""
                : " · " + row.item.summary)

        if row.isCurrent {
            return focus.current == .status
                ? TerminalStyle(
                    .inverse
                ).apply(
                    text
                )
                : TerminalStyle.bold.apply(
                    text
                )
        }

        switch row.item.kind {
        case .info:
            return TerminalStyle.dim.apply(
                text
            )

        case .warning:
            return TerminalStyle(
                .yellow
            ).apply(
                text
            )

        case .error:
            return TerminalStyle(
                .bold,
                .red
            ).apply(
                text
            )
        }
    }

    mutating func cycleBaseFocus() {
        switch focus.current {
        case .runs:
            focus.replace(
                .timeline
            )

        case .timeline:
            focus.replace(
                snapshot.statuses.isEmpty
                    ? .runs
                    : .status
            )

        case .status:
            focus.replace(
                .runs
            )

        case .inspector:
            break
        }
    }

    func inspectorLines(
        run: AgenticHostConsoleRunPresentation,
        step: AgenticHostConsoleStepPresentation
    ) -> [String] {
        var fields = [
            AgenticHostConsoleField(
                "run",
                run.title
            ),
            AgenticHostConsoleField(
                "state",
                step.state.displayTitle
            ),
            AgenticHostConsoleField(
                "step id",
                step.id
            ),
        ]

        if let detail = step.detail,
           !detail.isEmpty {
            fields.append(
                AgenticHostConsoleField(
                    "target",
                    detail
                )
            )
        }

        fields.append(
            contentsOf: step.fields
        )

        let labelWidth = fields
            .map {
                $0.label.count
            }
            .max() ?? 0

        return fields.map {
            field in

            let padding = String(
                repeating: " ",
                count: max(
                    1,
                    labelWidth - field.label.count + 2
                )
            )

            return TerminalStyle.dim.apply(
                field.label
            )
                + padding
                + field.value
        }
    }

    func runStateStyle(
        _ state: AgenticHostConsoleRunState
    ) -> TerminalStyle {
        switch state {
        case .ready:
            return .dim

        case .active:
            return .bold

        case .pause_pending:
            return .bold

        case .paused:
            return .dim

        case .awaitingApproval:
            return TerminalStyle(
                .bold,
                .yellow
            )

        case .onHold:
            return .dim

        case .completed:
            return TerminalStyle(
                .green
            )

        case .failed:
            return TerminalStyle(
                .bold,
                .red
            )
        }
    }

    static func preferredRunID(
        in snapshot: AgenticHostConsoleSnapshot,
        requested: String?
    ) -> String? {
        if let requested,
           snapshot.runs.contains(
            where: {
                $0.id == requested
            }
           ) {
            return requested
        }

        return snapshot.runs.first(
            where: {
                switch $0.state {
                case .ready,
                     .active,
                     .pause_pending,
                     .paused,
                     .awaitingApproval,
                     .onHold:
                    return true

                case .completed,
                     .failed:
                    return false
                }
            }
        )?.id
            ?? snapshot.runs.first?.id
    }

    static func preferredStepID(
        in run: AgenticHostConsoleRunPresentation?,
        requested: String?
    ) -> String? {
        guard let run else {
            return nil
        }

        if let requested,
           run.steps.contains(
            where: {
                $0.id == requested
            }
           ) {
            return requested
        }

        return run.steps.first(
            where: {
                $0.state == .active
            }
        )?.id
            ?? run.steps.first(
                where: {
                    $0.state == .failed
                }
            )?.id
            ?? run.steps.first?.id
    }
}

private extension AgenticHostConsoleRunState {
    var marker: String {
        switch self {
        case .ready:
            return "▷"

        case .active:
            return "◉"

        case .pause_pending:
            return "◌"

        case .paused:
            return "○"

        case .awaitingApproval:
            return "◇"

        case .onHold:
            return "‖"

        case .completed:
            return "✓"

        case .failed:
            return "×"
        }
    }

    var displayTitle: String {
        switch self {
        case .ready:
            return "ready"

        case .active:
            return "active"

        case .pause_pending:
            return "pause pending"

        case .paused:
            return "paused"

        case .awaitingApproval:
            return "awaiting approval"

        case .onHold:
            return "on hold"

        case .completed:
            return "completed"

        case .failed:
            return "failed"
        }
    }
}

private extension AgenticHostConsoleStepState {
    var terminalState: TerminalTimelineItemState {
        switch self {
        case .pending:
            return .pending

        case .active:
            return .active

        case .completed:
            return .completed

        case .failed:
            return .failed

        case .skipped:
            return .skipped
        }
    }

    var displayTitle: String {
        rawValue
    }
}
