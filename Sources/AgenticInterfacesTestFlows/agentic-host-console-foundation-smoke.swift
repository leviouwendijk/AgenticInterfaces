import AgenticInterfaces
import Terminal

enum AgenticHostConsoleFoundationSmoke {
    enum Failure:
        Error
    {
        case unexpectedInitialSelection
        case unexpectedFocus
        case unexpectedStepSelection
        case unexpectedInspectorFocus
        case unexpectedInspectorReturn
        case unexpectedRunSelection
    }

    static func run() throws {
        var console = AgenticHostConsoleControl(
            snapshot: AgenticHostConsoleLab.fixture()
        )

        guard console.currentRunID == "persistent-host-console",
              console.currentStepID == "aitest",
              console.focus.current == .runs else {
            throw Failure.unexpectedInitialSelection
        }

        _ = console.handle(
            .char("l")
        )

        guard console.focus.current == .timeline else {
            throw Failure.unexpectedFocus
        }

        let stepEvent = console.handle(
            .char("k")
        )

        guard console.currentStepID == "build",
              stepEvent == .stepSelectionChanged(
                runID: "persistent-host-console",
                stepID: "build"
              ) else {
            throw Failure.unexpectedStepSelection
        }

        _ = console.handle(
            .enter
        )

        guard console.focus.current == .inspector else {
            throw Failure.unexpectedInspectorFocus
        }

        _ = console.handle(
            .escape
        )

        guard console.focus.current == .timeline else {
            throw Failure.unexpectedInspectorReturn
        }

        _ = console.handle(
            .char("h")
        )
        let runEvent = console.handle(
            .char("j")
        )

        guard console.focus.current == .runs,
              console.currentRunID == "recovery",
              console.currentStepID == "failed-mutate",
              runEvent == .runSelectionChanged(
                "recovery"
              ) else {
            throw Failure.unexpectedRunSelection
        }
    }
}
