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
        case unexpectedExecutionFollow
        case unexpectedManualSelectionPreservation
        case unexpectedExecutionControls
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

        try runExecutionControlPolicyProbe()
        try runExecutionFollowProbe()
    }

    private static func runExecutionControlPolicyProbe() throws {
        guard AgenticHostConsoleRunControl.execute_run.rawValue == "execute_run",
              AgenticHostConsoleRunControl.execute_step_and_wait.rawValue == "execute_step_and_wait",
              AgenticHostConsoleRunControl.pause.rawValue == "pause",
              AgenticHostConsoleRunControl.execute_run.title == "Execute Run",
              AgenticHostConsoleRunControl.execute_step_and_wait.title == "Execute Step and Wait",
              AgenticHostConsoleRunControl.startControls == [
                .execute_run,
                .execute_step_and_wait,
              ],
              AgenticHostConsoleRunState.ready.executionControls == [
                .execute_run,
                .execute_step_and_wait,
              ],
              AgenticHostConsoleRunState.active.executionControls == [
                .pause,
              ],
              AgenticHostConsoleRunState.paused.executionControls == [
                .execute_run,
                .execute_step_and_wait,
              ],
              AgenticHostConsoleRunState.pause_pending.executionControls.isEmpty,
              AgenticHostConsoleRunState.awaitingApproval.executionControls.isEmpty,
              AgenticHostConsoleRunState.onHold.executionControls.isEmpty,
              AgenticHostConsoleRunState.completed.executionControls.isEmpty,
              AgenticHostConsoleRunState.failed.executionControls.isEmpty
        else {
            throw Failure.unexpectedExecutionControls
        }
    }

    private static func runExecutionFollowProbe() throws {
        var console = AgenticHostConsoleControl(
            snapshot: followSnapshot(
                states: [
                    .active,
                    .pending,
                    .pending,
                ]
            )
        )

        guard console.currentStepID == "first" else {
            throw Failure.unexpectedExecutionFollow
        }

        console.update(
            followSnapshot(
                states: [
                    .completed,
                    .active,
                    .pending,
                ]
            )
        )

        guard console.currentStepID == "second" else {
            throw Failure.unexpectedExecutionFollow
        }

        _ = console.handle(
            .char("l")
        )
        _ = console.handle(
            .char("k")
        )

        guard console.currentStepID == "first" else {
            throw Failure.unexpectedManualSelectionPreservation
        }

        console.update(
            followSnapshot(
                states: [
                    .completed,
                    .completed,
                    .active,
                ]
            )
        )

        guard console.currentStepID == "first" else {
            throw Failure.unexpectedManualSelectionPreservation
        }
    }

    private static func followSnapshot(
        states: [AgenticHostConsoleStepState]
    ) -> AgenticHostConsoleSnapshot {
        let ids = [
            "first",
            "second",
            "third",
        ]

        return AgenticHostConsoleSnapshot(
            runs: [
                AgenticHostConsoleRunPresentation(
                    id: "execution-follow",
                    title: "execution follow",
                    summary: "active ToolPlan",
                    state: .active,
                    steps: zip(
                        ids,
                        states
                    ).map {
                        id,
                        state in

                        AgenticHostConsoleStepPresentation(
                            id: id,
                            title: id,
                            state: state
                        )
                    }
                ),
            ]
        )
    }
}
