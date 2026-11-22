import Agentic
@_spi(Testing) import AgenticInterfaces
import AgenticPresentation
import Terminal

/// Dictating an answer: Ctrl-Space in an answer menu records into its text
/// field, the menu stays open, and the transcription is inserted there.
enum AgenticConversationUserInputVoiceSmoke {
    enum Failure: Error {
        case startNotRequested
        case focusLeftAnswer
        case targetNotAnswer
        case keyEditedWhileRecording
        case stopNotRequested
        case cancelNotRequested
        case transcriptionNotInAnswer(String)
        case secondTranscriptionNotAppended(String)
        case customValueNotDictated(String)
        case choiceOnlyAcceptedVoice
        case panelMissing
    }

    static func run() throws {
        try textAnswer()
        try singleChoiceCustomValue()
        try choiceOnlyRefuses()
    }

    private static func textAnswer() throws {
        let pending = AgenticConversationUserInputPresentation(
            interactionID: "interaction-1",
            runID: "run-1",
            request: try UserInputRequest(prompt: "Name the continuation.")
        )
        var control = AgenticConversationControl(snapshot: fixture(pending))

        try dictate("reviewed", into: &control, pending: pending)

        guard rendered(control, recording: pending).contains("recording") else {
            throw Failure.panelMissing
        }

        let first = control.handle(TerminalKeyStroke(key: .enter, modifiers: .control))
        guard first == .userInputReplyRequested(interactionID: "interaction-1", runID: "run-1", reply: .text("reviewed")) else {
            throw Failure.transcriptionNotInAnswer(String(describing: first))
        }

        try dictate("and merged", into: &control, pending: pending)
        let second = control.handle(TerminalKeyStroke(key: .enter, modifiers: .control))
        guard second == .userInputReplyRequested(interactionID: "interaction-1", runID: "run-1", reply: .text("reviewed and merged")) else {
            throw Failure.secondTranscriptionNotAppended(String(describing: second))
        }

        // Esc while recording cancels and keeps the answer open.
        _ = control.handle(.controlSpace)
        control.update(fixture(pending, voiceState: .recording))
        guard control.handle(.escape) == .voiceCancelRequested else {
            throw Failure.cancelNotRequested
        }
        guard control.focus.current == .userInput else {
            throw Failure.focusLeftAnswer
        }
    }

    private static func singleChoiceCustomValue() throws {
        let pending = AgenticConversationUserInputPresentation(
            interactionID: "interaction-2",
            runID: "run-2",
            request: try UserInputRequest(
                prompt: "Compatibility",
                input: .single_choice(
                    SingleChoiceUserInput(
                        choices: [
                            UserInputChoice(id: "hard-cut", label: "Hard cut", value: "hard-cut"),
                        ],
                        allowsCustomValue: true
                    )
                )
            )
        )
        var control = AgenticConversationControl(snapshot: fixture(pending))

        try dictate("keep both for a week", into: &control, pending: pending)
        let reply = control.handle(TerminalKeyStroke(key: .enter))
        guard reply == .userInputReplyRequested(
            interactionID: "interaction-2",
            runID: "run-2",
            reply: .single_choice(.custom("keep both for a week"))
        ) else {
            throw Failure.customValueNotDictated(String(describing: reply))
        }
    }

    private static func choiceOnlyRefuses() throws {
        let pending = AgenticConversationUserInputPresentation(
            interactionID: "interaction-3",
            runID: "run-3",
            request: try UserInputRequest(
                prompt: "Capabilities",
                input: .multi_choice(
                    MultiChoiceUserInput(
                        choices: [
                            UserInputChoice(id: "read", label: "Read", value: "read"),
                        ]
                    )
                )
            )
        )
        var control = AgenticConversationControl(snapshot: fixture(pending))
        guard case .feedbackRequested? = control.handle(.controlSpace) else {
            throw Failure.choiceOnlyAcceptedVoice
        }
    }

    /// One recording, as the console drives it: start, recording, stop,
    /// transcribing, transcription, idle.
    private static func dictate(
        _ text: String,
        into control: inout AgenticConversationControl,
        pending: AgenticConversationUserInputPresentation
    ) throws {
        guard control.handle(.controlSpace) == .voiceStartRequested else {
            throw Failure.startNotRequested
        }
        guard control.focus.current == .userInput else {
            throw Failure.focusLeftAnswer
        }
        guard control.voiceTarget == .userInput else {
            throw Failure.targetNotAnswer
        }

        control.update(fixture(pending, voiceState: .recording))
        guard control.handle(.char("x")) == nil,
              control.handle(TerminalKeyStroke(key: .char("y"))) == nil else {
            throw Failure.keyEditedWhileRecording
        }
        guard control.handle(TerminalKeyStroke(key: .enter)) == .voiceStopRequested else {
            throw Failure.stopNotRequested
        }

        control.update(fixture(pending, voiceState: .transcribing))
        _ = control.applyTranscription(.init(text: text))
        control.update(fixture(pending))
        guard control.focus.current == .userInput else {
            throw Failure.focusLeftAnswer
        }
    }

    private static func fixture(
        _ pending: AgenticConversationUserInputPresentation,
        voiceState: AgenticConversationVoice.State = .idle
    ) -> AgenticConversationSnapshot {
        AgenticConversationSnapshot(
            workspace: "/tmp/VoiceAnswerConversation",
            voiceAvailability: .available,
            voiceState: voiceState,
            models: [
                .init(id: "voice-model", title: "Voice model", detail: "voice answer fixture"),
            ],
            preferredModelProfileID: "voice-model",
            pendingUserInput: pending
        )
    }

    private static func rendered(
        _ value: AgenticConversationControl,
        recording pending: AgenticConversationUserInputPresentation
    ) -> String {
        var control = value
        _ = control.handle(.controlSpace)
        control.update(fixture(pending, voiceState: .recording))
        var frame = TerminalFrame(rows: 24, columns: 80)
        control.render(into: &frame, in: TerminalRegion(rows: 24, columns: 80))
        return frame.resolved().spans.map(\.content).joined(separator: "\n")
    }
}
