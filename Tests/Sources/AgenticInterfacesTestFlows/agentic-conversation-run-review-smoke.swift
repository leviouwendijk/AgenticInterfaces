import Agentic
@_spi(Testing) import AgenticInterfaces
import Foundation
import Reporting
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
        case toolNamedPreviewChanged
        case wrappedSummaryCroppedOptions
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
                            title: "mutate",
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
                    kind: .preview,
                    title: "Diff",
                    body: "diff --git a/a.swift b/a.swift\n+reviewed-change"
                ),
                AgenticHostConsoleDocumentPresentation(
                    id: "conversation-details",
                    runID: "conversation-run",
                    stepID: "review-step",
                    kind: .details,
                    title: "Mutation details",
                    body: "tool mutate\nrisk boundedmutate"
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

        // A waiting run comes before the message's other attachments.
        guard shortcutControl.handle(.enter) == nil,
              shortcutControl.focus.current == .runReview else {
            throw Failure.inspectionNavigationChanged
        }

        _ = shortcutControl.handle(.char("q"))
        guard shortcutControl.focus.current == .transcript,
              shortcutControl.handle(.char("a")) == nil,
              shortcutControl.focus.current == .runReview else {
            throw Failure.reviewShortcutDidNotOpen
        }
        _ = shortcutControl.handle(.char("q"))

        // From the attachment inspector, `a` and Enter on the run card reach the review.
        guard shortcutControl.handle(.char("t")) == .attachmentOpened(
            messageID: "assistant-run",
            attachmentID: "trace-conversation-run"
        ), shortcutControl.focus.current == .attachment,
              shortcutControl.handle(.char("a")) == nil,
              shortcutControl.focus.current == .runReview else {
            throw Failure.reviewShortcutDidNotOpen
        }
        _ = shortcutControl.handle(.char("q"))
        _ = shortcutControl.handle(.char("l"))
        guard shortcutControl.focus.current == .attachment,
              shortcutControl.handle(.enter) == nil,
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
        ), shortcutControl.focus.current == .attachment else {
            throw Failure.reviewShortcutActionChanged
        }

        try runStagedReviews()
        try runToolNamedPreview()
        try runWrappedSummary()

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

        guard diff.contains("Diff"),
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
    /// A tool names its preview (`Event`); the menu shows that name and
    /// opens the tool's card rather than a diff.
    static func runToolNamedPreview() throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let card = try ReportDocument(title: "Weekly session", datasets: [], blocks: [
            .event(.init(
                title: "Weekly session",
                interval: .init(start: start, end: start + 5400),
                timeZone: "Europe/Amsterdam",
                change: .create,
                calendar: "Trainer A"
            )),
        ])
        let sections: [ToolPreflight.Preview.Section] = [.report(card, title: "Event")]
        var snapshot = AgenticConversationSmoke.fixture()
        snapshot.hostConsole = AgenticHostConsoleSnapshot(
            runs: [.init(
                id: "conversation-run", title: "Book", state: .awaitingApproval,
                steps: [.init(id: "book-step", title: "schedule_tool_book", state: .pending)]
            )],
            interruptions: [.init(
                id: "book-approval", runID: "conversation-run", stepID: "book-step",
                kind: .approval, title: "Approval required", summary: "Create one event.",
                actions: [.approve, .deny]
            )],
            documents: [
                .init(
                    id: "book-preview", runID: "conversation-run", stepID: "book-step",
                    kind: .preview, title: AgenticPreviewRenderer.title(sections),
                    body: "Create 'Weekly session'", previewBody: sections
                ),
                .init(id: "book-details", runID: "conversation-run", stepID: "book-step", kind: .details, body: "{}"),
            ]
        )
        var control = AgenticConversationControl(snapshot: snapshot)
        _ = control.handle(.escape)
        _ = control.handle(.escape)
        _ = control.handle(.char("a"))
        func shown() -> String {
            var frame = TerminalFrame(rows: 40, columns: 100)
            control.render(into: &frame, in: TerminalRegion(rows: 40, columns: 100))
            return frame.resolved().spans.map(\.content).joined(separator: "\n")
        }
        let menu = shown()
        guard control.focus.current == .runReview,
              menu.contains("Event"), menu.contains("Details"), !menu.contains("Diff") else {
            throw Failure.toolNamedPreviewChanged
        }
        _ = control.handle(.enter)
        let opened = shown()
        guard opened.contains("New event"), opened.contains("Weekly session"), opened.contains("╭─") else {
            throw Failure.toolNamedPreviewChanged
        }
    }

    /// A summary that wraps past the menu's height gives up lines; the
    /// options never do.
    static func runWrappedSummary() throws {
        var snapshot = AgenticConversationSmoke.fixture()
        snapshot.hostConsole = AgenticHostConsoleSnapshot(
            runs: [.init(
                id: "conversation-run", title: "Book", state: .awaitingApproval,
                steps: [.init(id: "long-step", title: "schedule_tool_book", state: .pending)]
            )],
            interruptions: [.init(
                id: "long-approval", runID: "conversation-run", stepID: "long-step",
                kind: .approval, title: "Approval required",
                summary: Array(repeating: "This summary keeps going well past the menu.", count: 12)
                    .joined(separator: " "),
                actions: [.approve, .deny, .skip]
            )]
        )
        var control = AgenticConversationControl(snapshot: snapshot)
        _ = control.handle(.escape)
        _ = control.handle(.escape)
        _ = control.handle(.char("a"))
        var frame = TerminalFrame(rows: 18, columns: 70)
        control.render(into: &frame, in: TerminalRegion(rows: 18, columns: 70))
        let menu = frame.resolved().spans.map(\.content).joined(separator: "\n")
        guard control.focus.current == .runReview,
              menu.contains("Approve"), menu.contains("Deny"), menu.contains("Skip"),
              menu.contains("Open run console"), menu.contains("…") else {
            throw Failure.wrappedSummaryCroppedOptions
        }
    }

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
                kind: .preview,
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
