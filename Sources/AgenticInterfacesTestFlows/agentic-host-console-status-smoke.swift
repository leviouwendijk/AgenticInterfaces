import AgenticInterfaces
import Terminal

enum AgenticHostConsoleStatusSmoke {
    enum Failure:
        Error
    {
        case unexpectedInitialFocus
        case unexpectedTimelineFocus
        case unexpectedStatusFocus
        case unexpectedStatusOpen
        case unexpectedCopyRequest
        case unexpectedStatusClose
        case unexpectedActionFeedback
        case unexpectedRunControlFeedback
        case unexpectedDocumentRequest
    }

    static func run() throws {
        let diagnosticBody = """
        Execution attempt failed.

        Automatic continuation from 'root.sequence[1]' is not supported because
        this authored branch requires a fresh execution decision.

        The complete diagnostic remains inspectable and copyable.
        """
        let snapshot = AgenticHostConsoleSnapshot(
            runs: [
                AgenticHostConsoleRunPresentation(
                    id: "status-run",
                    title: "Status fixture",
                    state: .pause_pending,
                    steps: [
                        AgenticHostConsoleStepPresentation(
                            id: "status-step",
                            title: "mutate_files",
                            state: .pending
                        ),
                    ]
                ),
            ],
            statuses: [
                AgenticHostConsoleStatusPresentation(
                    id: "status-1",
                    runID: "status-run",
                    stepID: "status-step",
                    kind: .error,
                    title: "Execution attempt failed",
                    summary: "Enter to inspect full diagnostic.",
                    body: diagnosticBody
                ),
            ]
        )
        var workflow = AgenticHostConsoleWorkflowControl(
            snapshot: snapshot
        )

        guard workflow.console.focus.current == .runs else {
            throw Failure.unexpectedInitialFocus
        }

        _ = workflow.handle(
            .tab
        )

        guard workflow.console.focus.current == .timeline else {
            throw Failure.unexpectedTimelineFocus
        }

        _ = workflow.handle(
            .tab
        )

        guard workflow.console.focus.current == .status else {
            throw Failure.unexpectedStatusFocus
        }

        guard workflow.handle(
            .enter
        ) == .statusOpened(
            statusID: "status-1"
        ),
              workflow.focus.current == .diagnostic else {
            throw Failure.unexpectedStatusOpen
        }

        guard workflow.handle(
            .char("c")
        ) == .copyRequested(
            text: diagnosticBody,
            title: "Execution attempt failed"
        ) else {
            throw Failure.unexpectedCopyRequest
        }

        guard workflow.handle(
            .char("q")
        ) == .statusClosed(
            statusID: "status-1"
        ),
              workflow.focus.current == .base,
              workflow.console.focus.current == .status else {
            throw Failure.unexpectedStatusClose
        }

        guard workflow.handle(
            .char("a")
        ) == .feedbackRequested(
            message: "No actions available."
        ) else {
            throw Failure.unexpectedActionFeedback
        }

        guard workflow.handle(
            .char("x")
        ) == .feedbackRequested(
            message: "No run controls available."
        ) else {
            throw Failure.unexpectedRunControlFeedback
        }

        guard workflow.handle(
            .char("d")
        ) == .documentRequested(
            runID: "status-run",
            stepID: "status-step",
            kind: .details
        ) else {
            throw Failure.unexpectedDocumentRequest
        }

        var frame = TerminalFrame(
            rows: 24,
            columns: 120
        )
        workflow.render(
            into: &frame,
            in: TerminalRegion(
                rows: 24,
                columns: 120
            )
        )

        print(
            "host console status smoke passed"
        )
    }
}
