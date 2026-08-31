import AgenticInterfaces
import Terminal

enum AgenticHostConsoleApprovalReviewSmoke {
    enum Failure:
        Error
    {
        case unexpectedRunsFocus
        case unexpectedStepDrift
        case unexpectedActionShortcut
        case unexpectedDiffShortcut
    }

    static func run() throws {
        try runActionProbe()
        try runDiffProbe()
    }

    private static func runActionProbe() throws {
        var console = AgenticHostConsoleWorkflowControl(
            snapshot: fixture()
        )

        try moveToRunsWithDrift(
            &console
        )

        let event = console.handle(
            .char("a")
        )

        guard console.focus.current == .actions,
              console.currentInterruption?.id == "approval-interruption",
              event == .interruptionOpened(
                id: "approval-interruption",
                kind: .approval
              ) else {
            throw Failure.unexpectedActionShortcut
        }
    }

    private static func runDiffProbe() throws {
        var console = AgenticHostConsoleWorkflowControl(
            snapshot: fixture()
        )

        try moveToRunsWithDrift(
            &console
        )

        let event = console.handle(
            .char("f")
        )

        guard console.focus.current == .document,
              console.currentDocument?.id == "approval-diff",
              event == .documentOpened(
                documentID: "approval-diff",
                kind: .diff
              ) else {
            throw Failure.unexpectedDiffShortcut
        }
    }

    private static func moveToRunsWithDrift(
        _ console: inout AgenticHostConsoleWorkflowControl
    ) throws {
        _ = console.handle(
            .char("l")
        )
        _ = console.handle(
            .home
        )
        _ = console.handle(
            .char("h")
        )

        guard console.console.focus.current == .runs else {
            throw Failure.unexpectedRunsFocus
        }

        guard console.currentStepID == "reviewed-step" else {
            throw Failure.unexpectedStepDrift
        }
    }

    private static func fixture() -> AgenticHostConsoleSnapshot {
        AgenticHostConsoleSnapshot(
            runs: [
                AgenticHostConsoleRunPresentation(
                    id: "approval-run",
                    title: "Mutation approval",
                    summary: "Review the pending mutation before execution.",
                    state: .awaitingApproval,
                    steps: [
                        AgenticHostConsoleStepPresentation(
                            id: "reviewed-step",
                            title: "Earlier observation",
                            state: .completed
                        ),
                        AgenticHostConsoleStepPresentation(
                            id: "mutate-step",
                            title: "mutate_files",
                            state: .active
                        ),
                    ]
                ),
            ],
            interruptions: [
                AgenticHostConsoleInterruptionPresentation(
                    id: "approval-interruption",
                    runID: "approval-run",
                    stepID: "mutate-step",
                    kind: .approval,
                    title: "Approval",
                    summary: "Review the mutation before execution.",
                    actions: [
                        .approve,
                        .deny,
                        .skip,
                    ]
                ),
            ],
            documents: [
                AgenticHostConsoleDocumentPresentation(
                    id: "approval-diff",
                    runID: "approval-run",
                    stepID: "mutate-step",
                    kind: .diff,
                    title: "Diff preview",
                    body: "--- a/file.swift\n+++ b/file.swift\n-old\n+new"
                ),
            ]
        )
    }
}
