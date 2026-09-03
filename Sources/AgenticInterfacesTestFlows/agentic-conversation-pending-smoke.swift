import AgenticInterfaces
import Terminal

enum AgenticConversationPendingSmoke {
    enum Failure: Error {
        case submissionMissing
        case pendingStateMissing
        case pendingPresentationMissing
        case spinnerDidNotAdvance
        case pendingComposerMutated
        case pendingNavigationBlocked
        case pendingStateDidNotClear
    }

    static func run() throws {
        var control = AgenticConversationControl(
            snapshot: fixture()
        )

        _ = control.handle(
            .char("p")
        )
        _ = control.handle(
            .char("i")
        )
        _ = control.handle(
            .char("n")
        )
        _ = control.handle(
            .char("g")
        )

        guard case .submissionRequested(let submission)? =
            control.handle(.enter)
        else {
            throw Failure.submissionMissing
        }

        control.beginPendingTurn(
            submission
        )

        guard control.isResponsePending else {
            throw Failure.pendingStateMissing
        }

        let first = rendered(
            control
        )

        guard first.contains("ping"),
              first.contains("⠋"),
              first.contains("invoking model")
        else {
            throw Failure.pendingPresentationMissing
        }

        _ = control.advancePendingTurn()

        let second = rendered(
            control
        )

        guard second.contains("⠙"),
              second.contains("invoking model")
        else {
            throw Failure.spinnerDidNotAdvance
        }

        _ = control.handle(
            .char("x")
        )

        guard control.draftText.isEmpty else {
            throw Failure.pendingComposerMutated
        }

        _ = control.handle(
            .escape
        )

        guard control.focus.current == .transcript else {
            throw Failure.pendingNavigationBlocked
        }

        _ = control.handle(
            .char("j")
        )
        _ = control.handle(
            .tab
        )

        guard control.focus.current == .composer,
              control.isResponsePending
        else {
            throw Failure.pendingNavigationBlocked
        }

        control.endPendingTurn()

        guard !control.isResponsePending else {
            throw Failure.pendingStateDidNotClear
        }
    }

    private static func rendered(
        _ control: AgenticConversationControl
    ) -> String {
        var control = control
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

        return frame.resolved().spans
            .map(\.content)
            .joined(separator: "\n")
    }

    private static func fixture() -> AgenticConversationSnapshot {
        AgenticConversationSnapshot(
            workspace: "/tmp/PendingConversation",
            messages: [
                AgenticConversationMessagePresentation(
                    id: "existing-message",
                    role: .assistant,
                    body: "ready"
                ),
            ],
            models: [
                AgenticConversationModelPresentation(
                    id: "pending-model",
                    title: "Pending model",
                    detail: "responsive conversation fixture"
                ),
            ],
            selectedModelProfileID: "pending-model"
        )
    }
}
