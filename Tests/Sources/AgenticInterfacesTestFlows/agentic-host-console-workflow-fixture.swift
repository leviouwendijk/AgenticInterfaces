@_spi(Testing) import AgenticInterfaces
import AgenticPresentation
import DSL

enum AgenticHostConsoleWorkflowFixture {
    static func make() -> AgenticHostConsole.Snapshot {
        var snapshot = AgenticHostConsoleLab.fixture()

        snapshot.interruptions = [
            AgenticHostConsole.Interruption(
                id: "recovery-failure",
                runID: "recovery",
                stepID: "failed-mutate",
                kind: .recovery,
                title: "Recovery",
                summary: "The current step failed. Choose how this run should proceed.",
                actions: [
                    .retry,
                    .skip,
                    .create_fix_branch,
                    .stop_run,
                ]
            ),
            AgenticHostConsole.Interruption(
                id: "repository-approval",
                runID: "approval",
                stepID: "prepare",
                kind: .approval,
                title: "Approval",
                summary: "This staged repository mutation requires human review.",
                actions: [
                    .approve,
                    .deny,
                    .skip,
                    .stop_run,
                ]
            ),
        ]

        snapshot.documents = [
            AgenticHostConsole.Document(
                id: "aitest-stdout",
                runID: "persistent-host-console",
                stepID: "aitest",
                kind: .stdout,
                body: "Building for debugging...\nBuild complete.\nagentic host console foundation smoke passed"
            ),
            AgenticHostConsole.Document(
                id: "aitest-stderr",
                runID: "persistent-host-console",
                stepID: "aitest",
                kind: .stderr,
                body: "<empty>"
            ),
            AgenticHostConsole.Document(
                id: "recovery-details",
                runID: "recovery",
                stepID: "failed-mutate",
                kind: .details,
                title: "Failure details",
                body: "tool        mutate\nstate       failed\ntarget      Sources/AgenticInterfaces\nerror       edit match not found\n\nThe parent run remains on hold until an explicit recovery action is chosen.\nraw canonical failure detail",
                structuredBody: .group(
                    role: "agentic.test.failure",
                    title: [
                        .text("Failure")
                    ],
                    content: .collection([
                        .paragraph([
                            .text("structured projection visible")
                        ]),
                        .paragraph([
                            .text("The parent run remains on hold until an explicit recovery action is chosen.")
                        ]),
                    ])
                )
            ),
            AgenticHostConsole.Document(
                id: "recovery-stderr",
                runID: "recovery",
                stepID: "failed-mutate",
                kind: .stderr,
                body: "Edit match not found: expected unique mutation anchor."
            ),
            AgenticHostConsole.Document(
                id: "approval-details",
                runID: "approval",
                stepID: "prepare",
                kind: .details,
                title: "Staged intent details",
                body: "tool          git_tool_prepare_commit\nrequirement   needs_human_review\nrisk          boundedmutate\nworkspace     AgenticInterfaces"
            ),
            AgenticHostConsole.Document(
                id: "approval-diff",
                runID: "approval",
                stepID: "prepare",
                kind: .preview,
                title: "Diff preview",
                body: "--- a/Sources/AgenticInterfaces/example.swift\n+++ b/Sources/AgenticInterfaces/example.swift\n@@\n-old behavior\n+new behavior"
            ),
        ]

        return snapshot
    }
}
