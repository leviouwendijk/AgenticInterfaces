import AgenticInterfaces
import Terminal

enum AgenticHostConsoleRunHeaderSmoke {
    enum Failure:
        Error
    {
        case unexpectedTimelineFocus
        case unexpectedHeaderSelection
        case unexpectedRunInspection
        case unexpectedStepSelection
        case unexpectedStepInspection
        case unexpectedStepClose
    }

    static func run() throws {
        var console = AgenticHostConsoleControl(
            snapshot: AgenticHostConsoleSnapshot(
                runs: [
                    AgenticHostConsoleRunPresentation(
                        id: "run-header",
                        title: "Run header fixture",
                        state: .ready,
                        steps: [
                            AgenticHostConsoleStepPresentation(
                                id: "step-1",
                                title: "first",
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

        _ = console.handle(
            .tab
        )

        guard console.focus.current == .timeline,
              console.currentStepID == "step-1" else {
            throw Failure.unexpectedTimelineFocus
        }

        _ = console.handle(
            .char("k")
        )

        guard console.runHeaderSelected,
              console.currentStepID == nil else {
            throw Failure.unexpectedHeaderSelection
        }

        guard console.handle(
            .enter
        ) == .runInspectionOpened(
            runID: "run-header"
        ) else {
            throw Failure.unexpectedRunInspection
        }

        _ = console.handle(
            .char("j")
        )

        guard !console.runHeaderSelected,
              console.currentStepID == "step-1" else {
            throw Failure.unexpectedStepSelection
        }

        guard console.handle(
            .enter
        ) == .stepInspectionOpened(
            runID: "run-header",
            stepID: "step-1"
        ),
              console.focus.current == .inspector else {
            throw Failure.unexpectedStepInspection
        }

        guard console.handle(
            .char("q")
        ) == .stepInspectionClosed,
              console.focus.current == .timeline else {
            throw Failure.unexpectedStepClose
        }

        print(
            "host console run header smoke passed"
        )
    }
}
