import AgenticInterfaces
import Terminal

enum AgenticHostConsoleRunInspectionSmoke {
    enum Failure:
        Error
    {
        case unexpectedTimelineFocus
        case unexpectedHeaderSelection
        case unexpectedRunOpen
        case unexpectedInputCopyRequest
        case unexpectedOutputCopyRequest
        case unexpectedRunClose
        case unexpectedEscapeAlias
    }

    static func run() throws {
        var workflow = AgenticHostConsoleWorkflowControl(
            snapshot: AgenticHostConsoleSnapshot(
                runs: [
                    AgenticHostConsoleRunPresentation(
                        id: "run-inspection",
                        title: "Run inspection fixture",
                        summary: "ready for inspection",
                        state: .ready,
                        steps: [
                            AgenticHostConsoleStepPresentation(
                                id: "step-1",
                                title: "first",
                                detail: "first detail",
                                state: .pending
                            ),
                            AgenticHostConsoleStepPresentation(
                                id: "step-2",
                                title: "second",
                                state: .pending
                            ),
                        ]
                    ),
                ]
            )
        )

        _ = workflow.handle(
            .tab
        )

        guard workflow.console.focus.current == .timeline else {
            throw Failure.unexpectedTimelineFocus
        }

        _ = workflow.handle(
            .char("k")
        )

        guard workflow.console.runHeaderSelected,
              workflow.console.currentStepID == nil else {
            throw Failure.unexpectedHeaderSelection
        }

        guard workflow.handle(
            .enter
        ) == .runInspectionOpened(
            runID: "run-inspection"
        ),
              workflow.focus.current == .runInspector else {
            throw Failure.unexpectedRunOpen
        }

        guard workflow.handle(
            .char("i")
        ) == .runInputCopyRequested(
            runID: "run-inspection"
        ) else {
            throw Failure.unexpectedInputCopyRequest
        }

        guard workflow.handle(
            .char("o")
        ) == .runOutputCopyRequested(
            runID: "run-inspection"
        ) else {
            throw Failure.unexpectedOutputCopyRequest
        }

        guard workflow.handle(
            .char("q")
        ) == .runInspectionClosed(
            runID: "run-inspection"
        ),
              workflow.focus.current == .base,
              workflow.console.focus.current == .timeline,
              workflow.console.runHeaderSelected else {
            throw Failure.unexpectedRunClose
        }

        guard workflow.handle(
            .enter
        ) == .runInspectionOpened(
            runID: "run-inspection"
        ),
              workflow.handle(
                .escape
              ) == .runInspectionClosed(
                runID: "run-inspection"
              ),
              workflow.focus.current == .base else {
            throw Failure.unexpectedEscapeAlias
        }

        print(
            "host console run inspection smoke passed"
        )
    }
}
