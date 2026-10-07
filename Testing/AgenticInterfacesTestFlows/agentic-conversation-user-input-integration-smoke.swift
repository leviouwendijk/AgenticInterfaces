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
        case pendingRunCardMissing
        case pendingRunEnterDidNotReopen
        case pendingRunDetailsDidNotOpen
        case runConsoleAnswerAffordanceMissing
        case runConsoleAnswerDidNotReopen
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

        let pendingPresentation = rendered(
            control
        )
        guard pendingPresentation.contains(
            "Run · awaiting input"
        ),
              pendingPresentation.contains(
                "Enter to answer"
              )
        else {
            throw Failure.pendingRunCardMissing
        }

        _ = control.handle(
            .char("u")
        )
        guard control.focus.current == .userInput else {
            throw Failure.pendingInputDidNotReopen
        }

        _ = control.handle(
            .escape
        )
        guard control.focus.current == .transcript else {
            throw Failure.closeDidNotReturnToTranscript
        }

        guard control.handle(
            .enter
        ) == nil,
              control.focus.current == .userInput else {
            throw Failure.pendingRunEnterDidNotReopen
        }

        _ = control.handle(
            .escape
        )
        guard control.focus.current == .transcript else {
            throw Failure.closeDidNotReturnToTranscript
        }

        guard control.handle(
            .char("r")
        ) == .runOpened(
            messageID: "pending-message",
            runID: "run-1"
        ),
              control.focus.current == .run else {
            throw Failure.pendingRunDetailsDidNotOpen
        }

        let runPresentation = rendered(
            control
        )
        guard runPresentation.contains(
            "u answer"
        ) else {
            throw Failure.runConsoleAnswerAffordanceMissing
        }

        _ = control.handle(
            .char("u")
        )
        guard control.focus.current == .userInput else {
            throw Failure.runConsoleAnswerDidNotReopen
        }

        _ = control.handle(
            .escape
        )
        guard control.focus.current == .run else {
            throw Failure.pendingRunDetailsDidNotOpen
        }

        _ = control.handle(
            .char("q")
        )
        guard control.focus.current == .transcript else {
            throw Failure.closeDidNotReturnToTranscript
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
        let messages: [AgenticConversationMessagePresentation]
        let hostConsole: AgenticHostConsoleSnapshot

        if let pendingUserInput {
            messages = [
                AgenticConversationMessagePresentation(
                    id: "pending-message",
                    role: .assistant,
                    body: "The run is awaiting user input.",
                    attachments: [
                        .run(
                            runID: pendingUserInput.runID
                        ),
                    ]
                ),
            ]
            hostConsole = AgenticHostConsoleSnapshot(
                runs: [
                    AgenticHostConsoleRunPresentation(
                        id: pendingUserInput.runID,
                        title: "Pending user-input run",
                        summary: pendingUserInput.request.prompt,
                        state: .paused
                    ),
                ]
            )
        } else {
            messages = []
            hostConsole = .init()
        }

        return AgenticConversationSnapshot(
            workspace: "/tmp/UserInputConversation",
            messages: messages,
            models: [
                .init(
                    id: "input-model",
                    title: "Input model",
                    detail: "user-input integration fixture"
                ),
            ],
            preferredModelProfileID: "input-model",
            pendingUserInput: pendingUserInput,
            hostConsole: hostConsole
        )
    }

    private static func rendered(
        _ value: AgenticConversationControl
    ) -> String {
        var control = value
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
            .joined(
                separator: "\n"
            )
    }
}
