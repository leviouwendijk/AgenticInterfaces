import AgenticInterfaces

enum AgenticHostConsoleWorkflowFixture {
    static func make() -> AgenticHostConsoleSnapshot {
        var snapshot = AgenticHostConsoleLab.fixture()

        snapshot.interruptions = [
            AgenticHostConsoleInterruptionPresentation(
                id: "recovery-failure",
                runID: "recovery",
                stepID: "failed-mutate",
                kind: .recovery,
                title: "Recovery",
                summary: "The current step failed. Choose how this run should proceed.",
                actions: [
                    .retry,
                    .skip,
                    .createFixBranch,
                    .stopRun,
                ]
            ),
            AgenticHostConsoleInterruptionPresentation(
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
                    .stopRun,
                ]
            ),
        ]

        snapshot.documents = [
            AgenticHostConsoleDocumentPresentation(
                id: "aitest-stdout",
                runID: "persistent-host-console",
                stepID: "aitest",
                kind: .stdout,
                body: "Building for debugging...\nBuild complete.\nagentic host console foundation smoke passed"
            ),
            AgenticHostConsoleDocumentPresentation(
                id: "aitest-stderr",
                runID: "persistent-host-console",
                stepID: "aitest",
                kind: .stderr,
                body: "<empty>"
            ),
            AgenticHostConsoleDocumentPresentation(
                id: "recovery-details",
                runID: "recovery",
                stepID: "failed-mutate",
                kind: .details,
                title: "Failure details",
                body: "tool        mutate_files\nstate       failed\ntarget      Sources/AgenticInterfaces\nerror       edit match not found\n\nThe parent run remains on hold until an explicit recovery action is chosen."
            ),
            AgenticHostConsoleDocumentPresentation(
                id: "recovery-stderr",
                runID: "recovery",
                stepID: "failed-mutate",
                kind: .stderr,
                body: "Edit match not found: expected unique mutation anchor."
            ),
            AgenticHostConsoleDocumentPresentation(
                id: "approval-details",
                runID: "approval",
                stepID: "prepare",
                kind: .details,
                title: "Staged intent details",
                body: "tool          git_prepare_commit\nrequirement   needs_human_review\nrisk          boundedmutate\nworkspace     AgenticInterfaces"
            ),
            AgenticHostConsoleDocumentPresentation(
                id: "approval-diff",
                runID: "approval",
                stepID: "prepare",
                kind: .diff,
                title: "Diff preview",
                body: "--- a/Sources/AgenticInterfaces/example.swift\n+++ b/Sources/AgenticInterfaces/example.swift\n@@\n-old behavior\n+new behavior"
            ),
        ]

        return snapshot
    }
}
