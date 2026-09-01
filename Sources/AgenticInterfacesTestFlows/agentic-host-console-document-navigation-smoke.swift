import AgenticInterfaces
import Terminal

enum AgenticHostConsoleDocumentNavigationSmoke {
    enum Failure:
        Error
    {
        case unexpectedDetailsOpen
        case unexpectedExistingSibling
        case unexpectedLazyStdoutRequest
        case unexpectedLazyStdoutOpen
        case unexpectedLazyStderrRequest
        case unexpectedLazyStderrOpen
        case unexpectedRightBoundary
        case unexpectedLeftNavigation
        case unexpectedLeftBoundary
        case unexpectedDocumentClose
        case unexpectedSelectionPreservation
        case unexpectedActiveFollow
    }

    static func run() throws {
        try runDocumentNavigationProbe()
        try runSelectionPreservationProbe()

        print(
            "host console document navigation smoke passed"
        )
    }

    private static func runDocumentNavigationProbe() throws {
        var snapshot = AgenticHostConsoleSnapshot(
            runs: [
                AgenticHostConsoleRunPresentation(
                    id: "nav-run",
                    title: "Navigation fixture",
                    state: .ready,
                    steps: [
                        AgenticHostConsoleStepPresentation(
                            id: "nav-step",
                            title: "mutate_files",
                            state: .pending
                        ),
                        AgenticHostConsoleStepPresentation(
                            id: "other-step",
                            title: "swift_parse",
                            state: .pending
                        ),
                    ]
                ),
            ],
            documents: [
                document(
                    id: "nav-details",
                    stepID: "nav-step",
                    kind: .details
                ),
                document(
                    id: "nav-diff",
                    stepID: "nav-step",
                    kind: .diff
                ),
                document(
                    id: "other-stdout",
                    stepID: "other-step",
                    kind: .stdout
                ),
            ]
        )
        var workflow = AgenticHostConsoleWorkflowControl(
            snapshot: snapshot,
            currentRunID: "nav-run",
            currentStepID: "nav-step"
        )

        guard workflow.handle(
            .char("d")
        ) == .documentOpened(
            documentID: "nav-details",
            kind: .details
        ),
              workflow.currentDocument?.kind == .details else {
            throw Failure.unexpectedDetailsOpen
        }

        guard workflow.handle(
            .char("l")
        ) == .documentOpened(
            documentID: "nav-diff",
            kind: .diff
        ),
              workflow.currentDocument?.kind == .diff else {
            throw Failure.unexpectedExistingSibling
        }

        guard workflow.handle(
            .char("l")
        ) == .documentRequested(
            runID: "nav-run",
            stepID: "nav-step",
            kind: .stdout
        ) else {
            throw Failure.unexpectedLazyStdoutRequest
        }

        snapshot.documents.append(
            document(
                id: "nav-stdout",
                stepID: "nav-step",
                kind: .stdout
            )
        )
        workflow.update(
            snapshot
        )

        guard workflow.handle(
            .char("l")
        ) == .documentOpened(
            documentID: "nav-stdout",
            kind: .stdout
        ),
              workflow.currentDocument?.kind == .stdout else {
            throw Failure.unexpectedLazyStdoutOpen
        }

        guard workflow.handle(
            .char("l")
        ) == .documentRequested(
            runID: "nav-run",
            stepID: "nav-step",
            kind: .stderr
        ) else {
            throw Failure.unexpectedLazyStderrRequest
        }

        snapshot.documents.append(
            document(
                id: "nav-stderr",
                stepID: "nav-step",
                kind: .stderr
            )
        )
        workflow.update(
            snapshot
        )

        guard workflow.handle(
            .char("l")
        ) == .documentOpened(
            documentID: "nav-stderr",
            kind: .stderr
        ),
              workflow.currentDocument?.kind == .stderr else {
            throw Failure.unexpectedLazyStderrOpen
        }

        guard workflow.handle(
            .char("l")
        ) == nil,
              workflow.currentDocument?.kind == .stderr else {
            throw Failure.unexpectedRightBoundary
        }

        guard workflow.handle(
            .char("h")
        ) == .documentOpened(
            documentID: "nav-stdout",
            kind: .stdout
        ),
              workflow.currentDocument?.kind == .stdout else {
            throw Failure.unexpectedLeftNavigation
        }

        guard workflow.handle(
            .char("h")
        ) == .documentOpened(
            documentID: "nav-diff",
            kind: .diff
        ),
              workflow.currentDocument?.kind == .diff else {
            throw Failure.unexpectedLeftNavigation
        }

        guard workflow.handle(
            .char("h")
        ) == .documentOpened(
            documentID: "nav-details",
            kind: .details
        ),
              workflow.currentDocument?.kind == .details else {
            throw Failure.unexpectedLeftNavigation
        }

        guard workflow.handle(
            .char("h")
        ) == nil,
              workflow.currentDocument?.kind == .details else {
            throw Failure.unexpectedLeftBoundary
        }

        guard workflow.handle(
            .escape
        ) == .documentClosed(
            documentID: "nav-details",
            kind: .details
        ),
              workflow.focus.current == .base else {
            throw Failure.unexpectedDocumentClose
        }
    }

    private static func runSelectionPreservationProbe() throws {
        var selection = AgenticHostConsoleControl(
            snapshot: selectionSnapshot(
                runState: .ready,
                first: .pending,
                second: .pending
            )
        )

        _ = selection.handle(
            .tab
        )
        _ = selection.handle(
            .down
        )

        guard selection.currentStepID == "selection-second" else {
            throw Failure.unexpectedSelectionPreservation
        }

        selection.update(
            selectionSnapshot(
                runState: .paused,
                first: .completed,
                second: .pending
            )
        )

        guard selection.currentStepID == "selection-second" else {
            throw Failure.unexpectedSelectionPreservation
        }

        var active = AgenticHostConsoleControl(
            snapshot: selectionSnapshot(
                runState: .active,
                first: .active,
                second: .pending
            )
        )

        _ = active.handle(
            .tab
        )

        guard active.currentStepID == "selection-first" else {
            throw Failure.unexpectedActiveFollow
        }

        active.update(
            selectionSnapshot(
                runState: .active,
                first: .completed,
                second: .active
            )
        )

        guard active.currentStepID == "selection-second" else {
            throw Failure.unexpectedActiveFollow
        }
    }

    private static func document(
        id: String,
        stepID: String,
        kind: AgenticHostConsoleDocumentKind
    ) -> AgenticHostConsoleDocumentPresentation {
        AgenticHostConsoleDocumentPresentation(
            id: id,
            runID: "nav-run",
            stepID: stepID,
            kind: kind,
            body: "\(kind.rawValue) body"
        )
    }

    private static func selectionSnapshot(
        runState: AgenticHostConsoleRunState,
        first: AgenticHostConsoleStepState,
        second: AgenticHostConsoleStepState
    ) -> AgenticHostConsoleSnapshot {
        AgenticHostConsoleSnapshot(
            runs: [
                AgenticHostConsoleRunPresentation(
                    id: "selection-run",
                    title: "Selection fixture",
                    state: runState,
                    steps: [
                        AgenticHostConsoleStepPresentation(
                            id: "selection-first",
                            title: "first",
                            state: first
                        ),
                        AgenticHostConsoleStepPresentation(
                            id: "selection-second",
                            title: "second",
                            state: second
                        ),
                    ]
                ),
            ]
        )
    }
}
