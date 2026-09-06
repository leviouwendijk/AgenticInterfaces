import AgenticInterfaces
import Terminal

enum AgenticConversationRunReviewSmoke {
    enum Failure:
        Error
    {
        case reviewDidNotOpen
        case reviewPresentationMissing
        case diffDidNotOpen
        case exactApprovalEventChanged
        case reviewDidNotCloseAfterAction
    }

    static func run() throws {
        var snapshot = AgenticConversationSmoke.fixture()
        snapshot.hostConsole = AgenticHostConsoleSnapshot(
            runs: [
                AgenticHostConsoleRunPresentation(
                    id: "conversation-run",
                    title: "Review mutation",
                    summary: "Mutation awaits review",
                    state: .awaitingApproval,
                    steps: [
                        AgenticHostConsoleStepPresentation(
                            id: "review-step",
                            title: "mutate_files",
                            state: .pending
                        ),
                    ]
                ),
            ],
            interruptions: [
                AgenticHostConsoleInterruptionPresentation(
                    id: "conversation-approval",
                    runID: "conversation-run",
                    stepID: "review-step",
                    kind: .approval,
                    title: "Approval required",
                    summary: "Review the exact staged mutation.",
                    actions: [
                        .approve,
                        .deny,
                        .skip,
                    ]
                ),
            ],
            documents: [
                AgenticHostConsoleDocumentPresentation(
                    id: "conversation-diff",
                    runID: "conversation-run",
                    stepID: "review-step",
                    kind: .diff,
                    title: "Mutation diff",
                    body: "diff --git a/a.swift b/a.swift\n+reviewed-change"
                ),
                AgenticHostConsoleDocumentPresentation(
                    id: "conversation-details",
                    runID: "conversation-run",
                    stepID: "review-step",
                    kind: .details,
                    title: "Mutation details",
                    body: "tool mutate_files\nrisk boundedmutate"
                ),
            ]
        )

        var control = AgenticConversationControl(
            snapshot: snapshot
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

        guard menu.contains("Approval required"),
              menu.contains("Review the exact staged mutation."),
              menu.contains("Diff"),
              menu.contains("Details"),
              menu.contains("Approve"),
              menu.contains("Deny"),
              menu.contains("Skip"),
              menu.contains("Open run console")
        else {
            throw Failure.reviewPresentationMissing
        }

        _ = control.handle(
            .enter
        )
        frame.removeAll()
        control.render(
            into: &frame,
            in: TerminalRegion(
                rows: 24,
                columns: 80
            )
        )
        let diff = frame.resolved().spans
            .map(\.content)
            .joined(separator: "\n")

        guard diff.contains("Mutation diff"),
              diff.contains("reviewed-change")
        else {
            throw Failure.diffDidNotOpen
        }

        _ = control.handle(
            .char("q")
        )
        _ = control.handle(
            .char("j")
        )
        _ = control.handle(
            .char("j")
        )

        guard control.handle(
            .enter
        ) == .run(
            .actionRequested(
                interruptionID: "conversation-approval",
                runID: "conversation-run",
                stepID: "review-step",
                action: .approve
            )
        ) else {
            throw Failure.exactApprovalEventChanged
        }

        guard control.focus.current == .transcript else {
            throw Failure.reviewDidNotCloseAfterAction
        }
    }
}
