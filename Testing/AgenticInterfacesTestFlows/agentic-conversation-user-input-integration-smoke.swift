import Agentic
import AgenticInterfaces
import Terminal

enum AgenticConversationUserInputIntegrationSmoke {
    enum Failure: Error {
        case pendingInputDidNotFocus
        case replyIdentityChanged
        case duplicateReplyWasNotBlocked
        case closeDidNotReturnToTranscript
        case closeBecameSkip
        case pendingInputDidNotReopen
        case clearedInputStayedFocused
    }

    static func run() throws {
        let request = try UserInputRequest(
            prompt: "Name the continuation."
        )
        let pending = AgenticConversationUserInputPresentation(
            interactionID: "interaction-1",
            runID: "run-1",
            request: request
        )
        var control = AgenticConversationControl(
            snapshot: fixture(
                pendingUserInput: pending
            )
        )

        guard control.focus.current == .userInput else {
            throw Failure.pendingInputDidNotFocus
        }

        _ = control.handle(
            .paste("reviewed")
        )
        let reply = control.handle(
            TerminalKeyStroke(
                key: .enter
            )
        )

        guard reply == .userInputReplyRequested(
            interactionID: "interaction-1",
            runID: "run-1",
            reply: .text("reviewed")
        ) else {
            throw Failure.replyIdentityChanged
        }

        control.beginUserInputResolution(
            interactionID: "interaction-1"
        )
        guard control.handle(
            TerminalKeyStroke(
                key: .enter
            )
        ) == nil else {
            throw Failure.duplicateReplyWasNotBlocked
        }
        control.endUserInputResolution()

        let closeEvent = control.handle(
            TerminalKeyStroke(
                key: .escape
            )
        )
        guard closeEvent == nil else {
            throw Failure.closeBecameSkip
        }
        guard control.focus.current == .transcript else {
            throw Failure.closeDidNotReturnToTranscript
        }

        _ = control.handle(
            .char("u")
        )
        guard control.focus.current == .userInput else {
            throw Failure.pendingInputDidNotReopen
        }

        control.update(
            fixture(
                pendingUserInput: nil
            )
        )
        guard control.focus.current != .userInput else {
            throw Failure.clearedInputStayedFocused
        }
    }

    private static func fixture(
        pendingUserInput: AgenticConversationUserInputPresentation?
    ) -> AgenticConversationSnapshot {
        AgenticConversationSnapshot(
            workspace: "/tmp/UserInputConversation",
            models: [
                .init(
                    id: "input-model",
                    title: "Input model",
                    detail: "user-input integration fixture"
                ),
            ],
            preferredModelProfileID: "input-model",
            pendingUserInput: pendingUserInput
        )
    }
}
