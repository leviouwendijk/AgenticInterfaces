import AgenticInterfaces
import Terminal

enum AgenticConversationPendingSmoke {
    enum Failure: Error {
        case submissionMissing
        case pendingStateMissing
        case pendingPresentationMissing
        case pendingSpinnerChanged
        case pendingComposerDidNotRemainEditable
        case pendingNavigationBlocked
        case pendingSupersedeGateMissing
        case pendingStateDidNotClear
        case globalStopUnavailable
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
            control.handle(
                TerminalKeyStroke(
                    key: .enter,
                    modifiers: .control
                )
            )
        else {
            throw Failure.submissionMissing
        }

        control.beginPendingTurn(
            submission
        )

        guard control.isResponsePending else {
            throw Failure.pendingStateMissing
        }

        var waitingSnapshot = fixture()
        waitingSnapshot.activity = "invoking model · 0.1s"
        control.update(waitingSnapshot)
        let invoking = rendered(
            &control
        )
        guard invoking.contains("⠋ invoking model…"),
              invoking.contains("assistant")
        else {
            throw Failure.pendingSpinnerChanged
        }

        let advanced = rendered(
            &control
        )
        guard advanced.contains(
            "⠙ invoking model…"
        ) else {
            throw Failure.pendingSpinnerChanged
        }

        var liveSnapshot = fixture()
        liveSnapshot.messages.append(
            AgenticConversationMessagePresentation(
                id: "live-user",
                role: .user,
                body: submission.body
            )
        )
        liveSnapshot.messages.append(
            AgenticConversationMessagePresentation(
                id: "live-assistant",
                role: .assistant,
                body: "partial response"
            )
        )
        liveSnapshot.activity = "streaming · 0.4s"
        control.update(
            liveSnapshot
        )

        let first = rendered(
            &control
        )

        guard first.contains("ping"),
              first.contains("partial response"),
              first.contains("streaming · 0.4s"),
              first.contains("response pending")
        else {
            throw Failure.pendingPresentationMissing
        }

        guard !first.contains("invoking model…"),
              first.components(separatedBy: "ping").count == 2
        else {
            throw Failure.pendingSpinnerChanged
        }

        _ = control.handle(
            .char("x")
        )

        guard control.draftText == "x",
              control.isResponsePending else {
            throw Failure.pendingComposerDidNotRemainEditable
        }
        guard control.handle(TerminalKeyStroke(key: .control("G"))) == .stopRequested,
              control.handle(.control("G")) == nil,
              control.isResponsePending,
              control.draftText == "x"
        else { throw Failure.pendingStateMissing }

        // The focused editor must retain its cursor and Vim-like mode
        // transitions even while another task is running.
        func composerCursor() -> TerminalCursorShape? {
            var frame = TerminalFrame(rows: 24, columns: 80)
            control.render(into: &frame, in: .init(rows: 24, columns: 80))
            return frame.cursor?.shape
        }
        guard composerCursor() == .bar else {
            throw Failure.pendingComposerDidNotRemainEditable
        }
        _ = control.handle(TerminalKeyStroke(key: .control("C")))
        guard composerCursor() == .block else {
            throw Failure.pendingNavigationBlocked
        }
        _ = control.handle(.char("i"))
        guard composerCursor() == .bar, control.draftText == "x" else {
            throw Failure.pendingNavigationBlocked
        }

        _ = control.handle(
            .control("C")
        )
        _ = control.handle(
            .tab
        )

        guard control.focus.current == .transcript,
              control.isResponsePending else {
            throw Failure.pendingNavigationBlocked
        }

        _ = control.handle(
            .char("j")
        )
        _ = control.handle(
            .tab
        )

        guard control.focus.current == .composer,
              control.draftText == "x",
              control.isResponsePending
        else {
            throw Failure.pendingNavigationBlocked
        }

        guard control.handle(
            TerminalKeyStroke(
                key: .enter,
                modifiers: .control
            )
        ) == nil,
              control.focus.current == .confirmation,
              control.draftText == "x",
              control.isResponsePending
        else {
            throw Failure.pendingSupersedeGateMissing
        }

        control.setWorkRunning(false)
        control.setWorkRunning(true)
        guard control.handle(.control("G")) == .stopRequested,
              control.focus.current == .confirmation else {
            throw Failure.globalStopUnavailable
        }
        control.setWorkRunning(false)

        _ = control.handle(
            .escape
        )

        guard control.focus.current == .composer,
              control.draftText == "x",
              control.isResponsePending
        else {
            throw Failure.pendingSupersedeGateMissing
        }

        control.endPendingTurn()
        control.setWorkRunning(true)

        guard !control.isResponsePending,
              control.handle(.control("G")) == .stopRequested,
              control.handle(.control("G")) == nil else {
            throw Failure.globalStopUnavailable
        }

        control.setWorkRunning(false)
        guard !control.isResponsePending else {
            throw Failure.pendingStateDidNotClear
        }
    }

    private static func rendered(
        _ control: inout AgenticConversationControl
    ) -> String {
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
            preferredModelProfileID: "pending-model"
        )
    }
}
