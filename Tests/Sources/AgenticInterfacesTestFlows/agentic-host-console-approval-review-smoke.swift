@_spi(Testing) import AgenticInterfaces
import AgenticPresentation
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
        try runMissingDocumentRequestProbe()
    }

    private static func runActionProbe() throws {
        var console = AgenticHostConsole.Workflow.Control(
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

    private static func runMissingDocumentRequestProbe() throws {
        var snapshot = fixture()
        snapshot.documents = []

        var console = AgenticHostConsole.Workflow.Control(
            snapshot: snapshot
        )

        try moveToRunsWithDrift(
            &console
        )

        let event = console.handle(
            .char("f")
        )

        guard event == .documentRequested(
            runID: "approval-run",
            stepID: "reviewed-step",
            kind: .preview
        ),
              console.focus.current == .base else {
            throw Failure.unexpectedDiffShortcut
        }
    }

    private static func runDiffProbe() throws {
        var console = AgenticHostConsole.Workflow.Control(
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
                kind: .preview
              ) else {
            throw Failure.unexpectedDiffShortcut
        }
    }

    private static func moveToRunsWithDrift(
        _ console: inout AgenticHostConsole.Workflow.Control
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

    private static func fixture() -> AgenticHostConsole.Snapshot {
        AgenticHostConsole.Snapshot(
            runs: [
                AgenticHostConsole.Run(
                    id: "approval-run",
                    title: "Mutation approval",
                    summary: "Review the pending mutation before execution.",
                    state: .awaitingApproval,
                    steps: [
                        AgenticHostConsole.Step(
                            id: "reviewed-step",
                            title: "Earlier observation",
                            state: .completed
                        ),
                        AgenticHostConsole.Step(
                            id: "mutate-step",
                            title: "mutate",
                            state: .active
                        ),
                    ]
                ),
            ],
            interruptions: [
                AgenticHostConsole.Interruption(
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
                AgenticHostConsole.Document(
                    id: "approval-diff",
                    runID: "approval-run",
                    stepID: "mutate-step",
                    kind: .preview,
                    title: "Diff preview",
                    body: "--- a/file.swift\n+++ b/file.swift\n-old\n+new"
                ),
            ]
        )
    }
}
