import AgenticInterfaces
import Terminal

enum AgenticConversationWorkspaceAccessReviewSmoke {
    enum Failure:
        Error
    {
        case compactChoicePresentationChanged
        case compactPromptChanged
        case reviewDidNotOpen
        case reviewPresentationMissing
        case exactWorkspaceAccessEventChanged
        case reviewDidNotCloseAfterAction
    }

    static func run() throws {
        let prompt = AgenticWorkspaceAccessPrompt(
            summary: "Allow temporary workspace access.",
            fields: [
                .init(
                    "root",
                    "/tmp/external"
                ),
                .init(
                    "mode",
                    "read_write"
                ),
            ]
        )

        guard AgenticWorkspaceAccessChoice.allCases == [
            .grant_for_turn,
            .grant_for_session,
            .deny,
        ],
              AgenticWorkspaceAccessChoice.grant_for_turn.title == "This turn",
              AgenticWorkspaceAccessChoice.grant_for_session.title == "This session",
              AgenticWorkspaceAccessChoice.deny.title == "Deny"
        else {
            throw Failure.compactChoicePresentationChanged
        }

        guard prompt.title == "Workspace access requested",
              prompt.summary == "Allow temporary workspace access.",
              prompt.fields == [
                .init(
                    "root",
                    "/tmp/external"
                ),
                .init(
                    "mode",
                    "read_write"
                ),
              ]
        else {
            throw Failure.compactPromptChanged
        }

        var snapshot = AgenticConversationSmoke.fixture()
        snapshot.hostConsole = AgenticHostConsoleSnapshot(
            runs: [
                AgenticHostConsoleRunPresentation(
                    id: "conversation-run",
                    title: "Workspace access",
                    summary: "Workspace access awaits resolution",
                    state: .onHold,
                    steps: [
                        AgenticHostConsoleStepPresentation(
                            id: "workspace-access-step",
                            title: "request_path_grant",
                            state: .pending
                        ),
                    ]
                ),
            ],
            interruptions: [
                AgenticHostConsoleInterruptionPresentation(
                    id: "conversation-workspace-access",
                    runID: "conversation-run",
                    stepID: "workspace-access-step",
                    kind: .workspace_access,
                    title: "Workspace access requested",
                    summary: "Allow read-write access to /tmp/external?",
                    actions: [
                        .grant_for_turn,
                        .grant_for_session,
                        .deny,
                    ]
                ),
            ],
            documents: [
                AgenticHostConsoleDocumentPresentation(
                    id: "conversation-workspace-access-details",
                    runID: "conversation-run",
                    stepID: "workspace-access-step",
                    kind: .details,
                    title: "Workspace access details",
                    body: "root /tmp/external\nmode read_write\nreason fixture"
                ),
            ]
        )

        var control = AgenticConversationControl(
            snapshot: snapshot
        )
        _ = control.handle(
            .escape
        )
        _ = control.handle(
            .escape
        )

        guard control.handle(
            .enter
        ) == nil,
              control.focus.current == .runReview
        else {
            throw Failure.reviewDidNotOpen
        }

        var frame = TerminalFrame(
            rows: 24,
            columns: 80
        )
        control.render(
            into: &frame,
            in: TerminalRegion(
                rows: 24,
                columns: 80
            )
        )
        let menu = frame.resolved().spans
            .map(\.content)
            .joined(separator: "\n")

        guard menu.contains("Workspace access requested"),
              menu.contains("Allow read-write access to /tmp/external?"),
              menu.contains("Details"),
              menu.contains("This turn"),
              menu.contains("This session"),
              menu.contains("Deny"),
              menu.contains("Open run console")
        else {
            throw Failure.reviewPresentationMissing
        }

        _ = control.handle(
            .char("j")
        )

        guard control.handle(
            .enter
        ) == .run(
            .actionRequested(
                interruptionID: "conversation-workspace-access",
                runID: "conversation-run",
                stepID: "workspace-access-step",
                action: .grant_for_turn
            )
        ) else {
            throw Failure.exactWorkspaceAccessEventChanged
        }

        guard control.focus.current == .transcript else {
            throw Failure.reviewDidNotCloseAfterAction
        }
    }
}
