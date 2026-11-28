import AgenticPresentation
import Swim
import Terminal
import Surface

extension AgenticHostConsole {
    public enum Focus:
        Sendable,
        Hashable
    {
        case runs
        case timeline
        case status
        case inspector
    }
}

extension AgenticHostConsole {
    public enum Event:
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
}

extension AgenticHostConsole {
    public struct Control:
        Sendable
    {
        public private(set) var snapshot: AgenticHostConsole.Snapshot
        public private(set) var focus: SurfaceFocus.Stack<AgenticHostConsole.Focus>

        private var runs: SurfaceList.Control<
            AgenticHostConsole.Run,
            String
        >
        private var steps: SurfaceList.Control<
            AgenticHostConsole.Step,
            String
        >
        private var statuses: SurfaceList.Control<
            AgenticHostConsole.Status,
            String
        >
        private var runsDocument: TerminalScrollableDocument
        private var timelineDocument: TerminalScrollableDocument
        private var statusDocument: TerminalScrollableDocument
        private var inspectorDocument: TerminalScrollableDocument
        private var inspectedStepID: String?
        private var traceNavigation: AgenticHostConsole.Trace.Navigation?
        private var inspectedTraceDocumentIndex: Int
        private var isRunHeaderSelected: Bool
        private var navigator = AgenticListNavigator()

        public init(
            snapshot: AgenticHostConsole.Snapshot,
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
            self.focus = SurfaceFocus.Stack(
                .runs
            )
            self.runs = SurfaceList.Control(
                items: snapshot.runs,
                currentID: runID,
                wrapMode: .clamp,
                id: {
                    $0.id
                }
            )
            self.steps = SurfaceList.Control(
                items: run?.steps ?? [],
                currentID: stepID,
                wrapMode: .clamp,
                id: {
                    $0.id
                }
            )
            self.statuses = SurfaceList.Control(
                items: snapshot.statuses,
                wrapMode: .clamp,
                id: {
                    $0.id
                }
            )
            self.runsDocument = TerminalScrollableDocument()
            self.timelineDocument = TerminalScrollableDocument()
            self.statusDocument = TerminalScrollableDocument()
            self.inspectorDocument = TerminalScrollableDocument()
            self.inspectedStepID = nil
            self.traceNavigation = nil
            self.inspectedTraceDocumentIndex = 0
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

        public var currentRun: AgenticHostConsole.Run? {
            guard let currentRunID else {
                return nil
            }

            return snapshot.runs.first {
                $0.id == currentRunID
            }
        }

        public var currentStep: AgenticHostConsole.Step? {
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

        public var currentStatus: AgenticHostConsole.Status? {
            statuses.currentItem
        }

        /// A count or `g` typed towards a motion, for the footer.
        public var pendingMotion: String? {
            navigator.pendingText
        }

        public mutating func update(
            _ snapshot: AgenticHostConsole.Snapshot
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
               let roots = snapshot.documents.filter({
                   $0.runID == currentRunID && $0.stepID == inspectedStepID
                       && $0.traceRoots != nil
               }).dropFirst(inspectedTraceDocumentIndex).first?.traceRoots {
                if var navigation = traceNavigation {
                    try? navigation.update(roots: roots)
                    traceNavigation = navigation
                }
            }
            if let inspectedStepID,
               currentRun?.steps.contains(
                where: {
                    $0.id == inspectedStepID
                }
               ) != true {
                self.inspectedStepID = nil
                self.traceNavigation = nil
                self.inspectedTraceDocumentIndex = 0

                if focus.current == .inspector {
                    _ = focus.pop()
                }
            }
        }

        public mutating func handle(
            _ key: SurfaceInput.Key
        ) -> AgenticHostConsole.Event? {
            if key == .control("C") {
                return .exitRequested
            }

            if key == .tab,
               focus.current != .inspector {
                cycleBaseFocus()
                navigator.reset()
                return nil
            }

            let focused = focus.current
            let event: AgenticHostConsole.Event?

            switch focused {
            case .runs:
                event = handleRuns(
                    key
                )

            case .timeline:
                event = handleTimeline(
                    key
                )

            case .status:
                event = handleStatus(
                    key
                )

            case .inspector:
                event = handleInspector(
                    key
                )
            }

            // A pending count belongs to the pane it was typed in.
            if focus.current != focused {
                navigator.reset()
            }

            return event
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
}

private extension AgenticHostConsole.Control {
    mutating func cycleTraceDocument(_ delta: Int) {
        guard let runID = currentRunID, let stepID = inspectedStepID else { return }
        let documents = snapshot.documents.filter {
            $0.runID == runID && $0.stepID == stepID && $0.traceRoots != nil
        }
        guard !documents.isEmpty else { return }
        inspectedTraceDocumentIndex = (
            inspectedTraceDocumentIndex + delta + documents.count
        ) % documents.count
        traceNavigation = try? AgenticHostConsole.Trace.Navigation(
            roots: documents[inspectedTraceDocumentIndex].traceRoots ?? []
        )
        inspectorDocument.moveToStart()
    }

    mutating func handleRuns(
        _ key: SurfaceInput.Key
    ) -> AgenticHostConsole.Event? {
        if key.isHorizontalNext {
            focus.replace(
                .timeline
            )
            return nil
        }

        var motion: SurfaceList.Event<String>?
        let moved = navigator.handle(
            key,
            list: &runs,
            pageRows: runsDocument.viewport.visibleRows,
            event: &motion
        )
        guard let event = moved ? motion : runs.handle(
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
        _ key: SurfaceInput.Key
    ) -> AgenticHostConsole.Event? {
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
            navigator.reset()
            isRunHeaderSelected = true
            return nil
        }

        var motion: SurfaceList.Event<String>?
        let moved = navigator.handle(
            key,
            list: &steps,
            pageRows: timelineDocument.viewport.visibleRows,
            event: &motion
        )
        guard let event = moved ? motion : steps.handle(
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
            if let roots = snapshot.documents.first(where: {
                $0.runID == runID && $0.stepID == stepID && $0.traceRoots != nil
            })?.traceRoots {
                traceNavigation = try? AgenticHostConsole.Trace.Navigation(roots: roots)
            } else {
                traceNavigation = nil
            }
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
        _ key: SurfaceInput.Key
    ) -> AgenticHostConsole.Event? {
        if key.isHorizontalPrevious {
            focus.replace(
                .timeline
            )
            return nil
        }

        var motion: SurfaceList.Event<String>?
        let moved = navigator.handle(
            key,
            list: &statuses,
            pageRows: statusDocument.viewport.visibleRows,
            event: &motion
        )
        guard let event = moved ? motion : statuses.handle(
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
        _ key: SurfaceInput.Key
    ) -> AgenticHostConsole.Event? {
        if key == .escape || key == .char("q") {
            inspectedStepID = nil
            traceNavigation = nil
            inspectedTraceDocumentIndex = 0
            _ = focus.pop()
            return .stepInspectionClosed
        }

        if key == .char("[") { cycleTraceDocument(-1); return nil }
        if key == .char("]") { cycleTraceDocument(1); return nil }
        if var navigation = traceNavigation {
            switch key {
            case .up, .char("k"):
                navigation.move(-1)
            case .down, .char("j"):
                navigation.move(1)
            case .left, .char("h"):
                navigation.collapse()
            case .right, .char("l"):
                navigation.expand()
            case .enter, .char(" "):
                navigation.toggle()
            default:
                break
            }
            traceNavigation = navigation
            return nil
        }

        switch key {
        case .up,
             .char("k"):
            _ = inspectorDocument.scrollUp()

        case .down,
             .char("j"):
            _ = inspectorDocument.scrollDown()

        case .pageUp:
            _ = inspectorDocument.pageUp()

        case .pageDown:
            _ = inspectorDocument.pageDown()

        case .home:
            inspectorDocument.moveToStart()

        case .end:
            inspectorDocument.moveToEnd()

        default:
            break
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

        if let iteration = run.iteration {
            var progress = "iteration \(iteration)"

            if !run.steps.isEmpty {
                progress += " · stages \(run.steps.count)"
            }

            heading.append(
                TerminalStyle.dim.apply(
                    progress
                )
            )
        }

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
                    state: $0.state.terminalState,
                    groups: $0.groups
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
            text = (pendingMotion.map { "\($0)  " } ?? "")
                + "tab focus  j/k select  gg/G ends  h/← previous  l/→ next  enter inspect  ctrl-c quit"
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

        let overlay =
            AgenticHostConsole.Inspection.overlay(
                in: region
            )
        let content = overlay.render(
            into: &frame,
            in: region,
            title: step.title
        )
        let lines: [String]
        if let navigation = traceNavigation {
            lines = navigation.rows.map { row in
                let branch = row.node.children.isEmpty ? "·" : (row.is_expanded ? "▾" : "▸")
                let prefix = String(repeating: "  ", count: row.depth)
                let summary = prefix + branch + " " + row.node.title
                    + (row.node.detail.map { " · " + $0 } ?? "")
                return row.is_selected ? TerminalStyle(.inverse).apply(summary) : summary
            } + ["", "Selected reference: " + (navigation.selected_node?.reference_id ?? "<none>")]
              + (navigation.selected_node?.detail.map { [$0] } ?? [])
        } else {
            lines = inspectorLines(
                run: run,
                step: step,
                columns: content.columns
            )
        }

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
        _ row: SurfaceList.Row<
            AgenticHostConsole.Run,
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
        _ row: SurfaceList.Row<
            AgenticHostConsole.Status,
            String
        >
    ) -> String {
        let marker: String

        switch row.item.tone {
        case .neutral, .active:
            marker = "·"

        case .success:
            marker = "✓"

        case .warning:
            marker = "!"

        case .failure:
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

        switch row.item.tone {
        case .neutral, .active, .success:
            return TerminalStyle.dim.apply(
                text
            )

        case .warning:
            return TerminalStyle(
                .yellow
            ).apply(
                text
            )

        case .failure:
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
        run: AgenticHostConsole.Run,
        step: AgenticHostConsole.Step,
        columns: Int
    ) -> [String] {
        var fields = [
            AgenticHostConsole.Field(
                "run",
                run.title
            ),
            AgenticHostConsole.Field(
                "state",
                step.state.displayTitle
            ),
            AgenticHostConsole.Field(
                "step id",
                step.id
            ),
        ]

        if let detail = step.detail,
           !detail.isEmpty {
            fields.append(
                AgenticHostConsole.Field(
                    "target",
                    detail
                )
            )
        }

        fields.append(
            contentsOf: step.fields
        )

        return AgenticHostConsole.Inspection.fieldLines(
            fields,
            columns: columns
        )
    }

    func runStateStyle(
        _ state: AgenticHostConsole.Run.State
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

        case .interrupted:
            return .dim

        case .failed:
            return TerminalStyle(
                .bold,
                .red
            )
        }
    }

    static func preferredRunID(
        in snapshot: AgenticHostConsole.Snapshot,
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

                case .interrupted,
                     .completed,
                     .failed:
                    return false
                }
            }
        )?.id
            ?? snapshot.runs.first?.id
    }

    static func preferredStepID(
        in run: AgenticHostConsole.Run?,
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

private extension AgenticHostConsole.Run.State {
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

        case .interrupted:
            return "■"

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

        case .interrupted:
            return "interrupted"

        case .failed:
            return "failed"
        }
    }
}

private extension AgenticHostConsole.Step.State {
    var terminalState: TerminalTimelineItemState {
        switch self {
        case .pending:
            return .pending

        case .active:
            return .active

        case .completed:
            return .completed

        case .warning:
            return .warning

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
