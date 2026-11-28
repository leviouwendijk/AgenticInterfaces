@_spi(Testing) import AgenticInterfaces
import AgenticPresentation
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
        case unexpectedRunMotion
        case unexpectedExecutionFollow
        case unexpectedManualSelectionPreservation
        case unexpectedExecutionControls
    }

    static func run() throws {
        var console = AgenticHostConsole.Control(
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

        // Motions reach the runs list, and its last run stays put on `j`.
        _ = console.handle(.char("G"))
        let lastRunID = console.currentRunID
        _ = console.handle(.char("j"))
        guard lastRunID == "terminal-foundation",
              console.currentRunID == lastRunID else {
            throw Failure.unexpectedRunMotion
        }
        _ = console.handle(.char("g"))
        _ = console.handle(.char("g"))
        guard console.currentRunID == "persistent-host-console" else {
            throw Failure.unexpectedRunMotion
        }

        try runExecutionControlPolicyProbe()
        try runExecutionFollowProbe()
        try AgenticNativeDifferenceRenderSmoke.run()
        try AgenticHostConsoleTraceNavigationSmoke.run()
    }

    private static func runExecutionControlPolicyProbe() throws {
        guard AgenticHostConsole.Run.Control.execute_run.rawValue == "execute_run",
              AgenticHostConsole.Run.Control.execute_step_and_wait.rawValue == "execute_step_and_wait",
              AgenticHostConsole.Run.Control.pause.rawValue == "pause",
              AgenticHostConsole.Run.Control.execute_run.title == "Execute Run",
              AgenticHostConsole.Run.Control.execute_step_and_wait.title == "Execute Step and Wait",
              AgenticHostConsole.Run.Control.startControls == [
                .execute_run,
                .execute_step_and_wait,
              ],
              AgenticHostConsole.Run.State.ready.executionControls == [
                .execute_run,
                .execute_step_and_wait,
              ],
              AgenticHostConsole.Run.State.active.executionControls == [
                .pause,
                .stop_after_iteration,
                .stop_urgent,
              ],
              AgenticHostConsole.Run.State.paused.executionControls == [
                .execute_run,
                .execute_step_and_wait,
                .stop_urgent,
              ],
              AgenticHostConsole.Run.State.pause_pending.executionControls == [
                .stop_urgent,
              ],
              AgenticHostConsole.Run.State.awaitingApproval.executionControls == [
                .stop_urgent,
              ],
              AgenticHostConsole.Run.State.onHold.executionControls == [
                .stop_urgent,
              ],
              AgenticHostConsole.Run.State.interrupted.executionControls.isEmpty,
              AgenticHostConsole.Run.State.completed.executionControls.isEmpty,
              AgenticHostConsole.Run.State.failed.executionControls.isEmpty
        else {
            throw Failure.unexpectedExecutionControls
        }
    }

    private static func runExecutionFollowProbe() throws {
        var console = AgenticHostConsole.Control(
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
        states: [AgenticHostConsole.Step.State]
    ) -> AgenticHostConsole.Snapshot {
        let ids = [
            "first",
            "second",
            "third",
        ]

        return AgenticHostConsole.Snapshot(
            runs: [
                AgenticHostConsole.Run(
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

                        AgenticHostConsole.Step(
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
