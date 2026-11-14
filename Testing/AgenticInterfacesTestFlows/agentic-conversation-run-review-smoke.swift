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
        case inspectionNavigationChanged
        case reviewShortcutDidNotOpen
        case reviewShortcutActionChanged
        case noPendingReviewFeedbackChanged
        case stagedReviewsChanged
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

        var multiAttachmentSnapshot = snapshot
        multiAttachmentSnapshot.messages[1].attachments = [
            .trace(runID: "conversation-run"),
            .run(runID: "conversation-run"),
        ]
        var shortcutControl = AgenticConversationControl(
            snapshot: multiAttachmentSnapshot
        )
        _ = shortcutControl.handle(.escape)
        _ = shortcutControl.handle(.escape)

        guard shortcutControl.handle(.enter) == .attachmentOpened(
            messageID: "assistant-run",
            attachmentID: "trace-conversation-run"
        ), shortcutControl.focus.current == .attachment else {
            throw Failure.inspectionNavigationChanged
        }

        _ = shortcutControl.handle(.char("q"))
        guard shortcutControl.focus.current == .transcript,
              shortcutControl.handle(.char("a")) == nil,
              shortcutControl.focus.current == .runReview else {
            throw Failure.reviewShortcutDidNotOpen
        }

        _ = shortcutControl.handle(.char("j"))
        _ = shortcutControl.handle(.char("j"))
        guard shortcutControl.handle(.enter) == .run(
            .actionRequested(
                interruptionID: "conversation-approval",
                runID: "conversation-run",
                stepID: "review-step",
                action: .approve
            )
        ), shortcutControl.focus.current == .transcript else {
            throw Failure.reviewShortcutActionChanged
        }

        try runStagedReviews()

        var noReviewControl = AgenticConversationControl(
            snapshot: AgenticConversationSmoke.fixture()
        )
        _ = noReviewControl.handle(.escape)
        _ = noReviewControl.handle(.escape)
        guard noReviewControl.handle(.char("a")) == .feedbackRequested(
            "Selected run has no pending review."
        ), noReviewControl.focus.current == .transcript else {
            throw Failure.noPendingReviewFeedbackChanged
        }

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

    /// One staged review per worker: `]` steps between them, and deciding
    /// one keeps the menu open on the next.
    static func runStagedReviews() throws {
        func review(_ worker: String) -> AgenticHostConsoleInterruptionPresentation {
            .init(
                id: "staged-\(worker)",
                runID: "conversation-run",
                stepID: "staged-\(worker)",
                kind: .publication,
                title: "Staged · \(worker)",
                summary: "\(worker) staged 1 file",
                actions: [.publish, .discard, .skip]
            )
        }
        func diff(_ worker: String) -> AgenticHostConsoleDocumentPresentation {
            .init(
                id: "staged-\(worker)-diff",
                runID: "conversation-run",
                stepID: "staged-\(worker)",
                kind: .diff,
                title: "Staged · \(worker)",
                body: "+\(worker) change"
            )
        }
        var snapshot = AgenticConversationSmoke.fixture()
        snapshot.hostConsole = AgenticHostConsoleSnapshot(
            runs: [.init(id: "conversation-run", title: "Delegating", state: .completed)],
            interruptions: [review("implementer"), review("tester")],
            documents: [diff("implementer"), diff("tester")]
        )
        var control = AgenticConversationControl(snapshot: snapshot)
        _ = control.handle(.escape)
        _ = control.handle(.escape)
        _ = control.handle(.char("a"))
        func shown() -> String {
            var frame = TerminalFrame(rows: 30, columns: 100)
            control.render(into: &frame, in: TerminalRegion(rows: 30, columns: 100))
            return frame.spans.map(\.content).joined(separator: "\n")
        }
        guard control.focus.current == .runReview,
              shown().contains("Staged · implementer · 1 of 2") else {
            throw Failure.stagedReviewsChanged
        }
        _ = control.handle(.char("]"))
        guard shown().contains("Staged · tester · 2 of 2") else {
            throw Failure.stagedReviewsChanged
        }
        // Diff, then Publish.
        _ = control.handle(.char("j"))
        guard control.handle(.enter) == .run(.actionRequested(
            interruptionID: "staged-tester",
            runID: "conversation-run",
            stepID: "staged-tester",
            action: .publish
        )), control.focus.current == .runReview else {
            throw Failure.stagedReviewsChanged
        }
        snapshot.hostConsole.interruptions.removeAll { $0.id == "staged-tester" }
        snapshot.hostConsole.documents.removeAll { $0.stepID == "staged-tester" }
        control.update(snapshot)
        guard control.focus.current == .runReview,
              shown().contains("Staged · implementer"),
              !shown().contains("of 2") else {
            throw Failure.stagedReviewsChanged
        }
    }
}
