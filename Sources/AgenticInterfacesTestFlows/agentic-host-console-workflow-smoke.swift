import AgenticInterfaces
import Terminal

enum AgenticHostConsoleWorkflowSmoke {
    enum Failure:
        Error
    {
        case unexpectedDocumentOpen
        case unexpectedDocumentReturn
        case unexpectedRecoverySelection
        case unexpectedRecoveryOpen
        case unexpectedRecoveryAction
        case unexpectedRecoveryDetails
        case unexpectedRecoveryReturn
        case unexpectedWrappedInterruption
        case unexpectedWrappedActionSummary
        case unexpectedNestedDocumentPresentation
        case unexpectedContinueAction
        case unexpectedRunControlOpen
        case unexpectedRunControlClose
        case unexpectedRunControlRequest
        case unexpectedRunControlPresentation
        case unexpectedUnavailableRunControl
    }

    static func run() throws {
        guard AgenticHostConsoleAction.continueRun.rawValue == "continue_run",
              AgenticHostConsoleAction.continueRun.title == "Continue ToolPlan",
              AgenticHostConsoleAction.continueRun.summary
                == "Continue the remaining ToolPlan after the resolved step."
        else {
            throw Failure.unexpectedContinueAction
        }

        var console = AgenticHostConsoleWorkflowControl(
            snapshot: AgenticHostConsoleWorkflowFixture.make()
        )

        _ = console.handle(
            .char("l")
        )

        let stdoutEvent = console.handle(
            .char("o")
        )

        guard console.focus.current == .document,
              stdoutEvent == .documentOpened(
                documentID: "aitest-stdout",
                kind: .stdout
              ) else {
            throw Failure.unexpectedDocumentOpen
        }

        _ = console.handle(
            .char("q")
        )

        guard console.focus.current == .base,
              console.console.focus.current == .timeline else {
            throw Failure.unexpectedDocumentReturn
        }

        _ = console.handle(
            .char("h")
        )
        _ = console.handle(
            .char("j")
        )
        _ = console.handle(
            .char("l")
        )

        guard console.currentRunID == "recovery",
              console.currentStepID == "failed-mutate" else {
            throw Failure.unexpectedRecoverySelection
        }

        let interruptionEvent = console.handle(
            .char("a")
        )

        guard console.focus.current == .actions,
              console.currentAction == .retry,
              interruptionEvent == .interruptionOpened(
                id: "recovery-failure",
                kind: .recovery
              ) else {
            throw Failure.unexpectedRecoveryOpen
        }

        let interruptionText = renderedText(
            &console,
            columns: 64
        )

        guard interruptionText.contains(
            "proceed."
        ) else {
            throw Failure.unexpectedWrappedInterruption
        }

        _ = console.handle(
            .char("j")
        )
        _ = console.handle(
            .char("j")
        )

        guard console.currentAction == .createFixBranch,
              renderedText(
                &console,
                columns: 64
              ).contains(
                "failed step."
              ) else {
            throw Failure.unexpectedWrappedActionSummary
        }

        _ = console.handle(
            .char("k")
        )
        _ = console.handle(
            .char("k")
        )

        let actionEvent = console.handle(
            .enter
        )

        guard actionEvent == .actionRequested(
            interruptionID: "recovery-failure",
            runID: "recovery",
            stepID: "failed-mutate",
            action: .retry
        ) else {
            throw Failure.unexpectedRecoveryAction
        }

        let detailsEvent = console.handle(
            .char("d")
        )

        guard console.focus.current == .document,
              detailsEvent == .documentOpened(
                documentID: "recovery-details",
                kind: .details
              ) else {
            throw Failure.unexpectedRecoveryDetails
        }

        guard renderedText(
            &console,
            columns: 64
        ).contains(
            "chosen."
        ) else {
            throw Failure.unexpectedNestedDocumentPresentation
        }

        _ = console.handle(
            .char("q")
        )

        guard console.focus.current == .actions else {
            throw Failure.unexpectedRecoveryReturn
        }

        _ = console.handle(
            .char("q")
        )

        guard console.focus.current == .base,
              console.console.focus.current == .timeline else {
            throw Failure.unexpectedRecoveryReturn
        }

        try runExecutionControlProbe()
        try AgenticHostConsoleApprovalReviewSmoke.run()
        try AgenticHostConsoleStatusSmoke.run()
        try AgenticHostConsoleDocumentNavigationSmoke.run()
        try AgenticHostConsoleRunHeaderSmoke.run()
        try AgenticHostConsoleRunInspectionSmoke.run()
    }

    private static func runExecutionControlProbe() throws {
        var paused = AgenticHostConsoleWorkflowControl(
            snapshot: AgenticHostConsoleSnapshot(
                runs: [
                    AgenticHostConsoleRunPresentation(
                        id: "paused-run",
                        title: "Paused ToolPlan",
                        summary: "Stopped at a safe ToolPlan boundary.",
                        state: .paused
                    ),
                ]
            )
        )

        let opened = paused.handle(
            .char("x")
        )

        guard paused.focus.current == .runControls,
              paused.currentRunControl == .execute_run,
              opened == .runControlsOpened(
                runID: "paused-run"
              ) else {
            throw Failure.unexpectedRunControlOpen
        }

        let presentation = renderedText(
            &paused,
            columns: 64
        )

        guard presentation.contains(
            "Run control"
        ), presentation.contains(
            "Execute Run"
        ), presentation.contains(
            "Execute Step and Wait"
        ) else {
            throw Failure.unexpectedRunControlPresentation
        }

        let closed = paused.handle(
            .char("q")
        )

        guard paused.focus.current == .base,
              closed == .runControlsClosed(
                runID: "paused-run"
              ) else {
            throw Failure.unexpectedRunControlClose
        }

        _ = paused.handle(
            .char("x")
        )
        _ = paused.handle(
            .down
        )

        let stepped = paused.handle(
            .enter
        )

        guard paused.focus.current == .base,
              stepped == .runControlRequested(
                runID: "paused-run",
                control: .execute_step_and_wait
              ) else {
            throw Failure.unexpectedRunControlRequest
        }

        var active = AgenticHostConsoleWorkflowControl(
            snapshot: AgenticHostConsoleSnapshot(
                runs: [
                    AgenticHostConsoleRunPresentation(
                        id: "active-run",
                        title: "Active ToolPlan",
                        state: .active
                    ),
                ]
            )
        )

        _ = active.handle(
            .char("x")
        )

        guard active.focus.current == .runControls,
              active.currentRunControl == .pause else {
            throw Failure.unexpectedRunControlOpen
        }

        let pause = active.handle(
            .enter
        )

        guard active.focus.current == .base,
              pause == .runControlRequested(
                runID: "active-run",
                control: .pause
              ) else {
            throw Failure.unexpectedRunControlRequest
        }

        var pending = AgenticHostConsoleWorkflowControl(
            snapshot: AgenticHostConsoleSnapshot(
                runs: [
                    AgenticHostConsoleRunPresentation(
                        id: "pending-run",
                        title: "Pause pending ToolPlan",
                        state: .pause_pending
                    ),
                ]
            )
        )

        guard pending.handle(
            .char("x")
        ) == .feedbackRequested(
            message: "No run controls available."
        ),
              pending.focus.current == .base else {
            throw Failure.unexpectedUnavailableRunControl
        }
    }

    private static func renderedText(
        _ console: inout AgenticHostConsoleWorkflowControl,
        rows: Int = 24,
        columns: Int
    ) -> String {
        var frame = TerminalFrame(
            rows: rows,
            columns: columns
        )

        console.render(
            into: &frame,
            in: TerminalRegion(
                rows: rows,
                columns: columns
            )
        )

        return frame
            .resolved()
            .spans
            .map(\.content)
            .joined(
                separator: "\n"
            )
    }
}
