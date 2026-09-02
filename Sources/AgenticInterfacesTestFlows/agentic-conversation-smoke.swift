import AgenticInterfaces
import Terminal

enum AgenticConversationSmoke {
    enum Failure: Error {
        case composerConsumedQ
        case pastedContentChanged
        case submissionChanged
        case transcriptionDraftChanged
        case transcribedContentChanged
        case modelSelectionChanged
        case skillSelectionChanged
        case attachmentDidNotOpen
        case runDidNotOpen
        case runDidNotClose
        case presentationMissing
    }

    static func run() throws {
        var control = AgenticConversationControl(snapshot: fixture())
        _ = control.handle(.char("q"))
        guard control.draftText == "q" else {
            throw Failure.composerConsumedQ
        }

        let pasted = "alpha\nbeta\n"
        let pinned = control.handle(.paste(pasted))
        guard case .contentPinned(let content)? = pinned,
              content.kind == .pasted,
              content.body == pasted,
              control.pinnedContents.first?.kind == .pasted,
              control.pinnedContents.first?.body == pasted
        else {
            throw Failure.pastedContentChanged
        }

        let submitted = control.handle(.enter)
        guard case .submissionRequested(let submission)? = submitted,
              submission.body == "q",
              submission.origin == .typed,
              submission.contents.map(\.body) == [pasted],
              submission.contents.map(\.kind) == [.pasted],
              submission.modelProfileID.rawValue == "apple-default",
              submission.skillIDs.isEmpty,
              control.draftText.isEmpty,
              control.pinnedContents.isEmpty
        else {
            throw Failure.submissionChanged
        }

        _ = control.applyTranscription(
            .init(
                text: "spoken draft",
                localeIdentifier: "en-US"
            )
        )
        guard control.draftText == "spoken draft" else {
            throw Failure.transcriptionDraftChanged
        }

        let transcribedPinned = control.applyTranscription(
            .init(
                text: "spoken context",
                localeIdentifier: "en-US"
            ),
            disposition: .pinned
        )
        guard case .contentPinned(let transcribedContent)? = transcribedPinned,
              transcribedContent.kind == .transcribed,
              transcribedContent.body == "spoken context"
        else {
            throw Failure.transcribedContentChanged
        }

        let voiceSubmitted = control.handle(.enter)
        guard case .submissionRequested(let voiceSubmission)? = voiceSubmitted,
              voiceSubmission.body == "spoken draft",
              voiceSubmission.origin == .transcribed,
              voiceSubmission.contents.map(\.kind) == [.transcribed],
              voiceSubmission.contents.map(\.body) == ["spoken context"],
              control.draftText.isEmpty,
              control.pinnedContents.isEmpty
        else {
            throw Failure.transcribedContentChanged
        }

        _ = control.handle(.escape)
        _ = control.handle(.char("m"))
        _ = control.handle(.char("j"))
        guard control.handle(.enter) == .modelSelectionChanged("mock-model") else {
            throw Failure.modelSelectionChanged
        }

        _ = control.handle(.char("s"))
        _ = control.handle(.space)
        guard control.handle(.enter) == .skillSelectionChanged([
            "swift-editing",
        ]) else {
            throw Failure.skillSelectionChanged
        }

        guard control.handle(.enter) == .attachmentOpened(
            messageID: "assistant-run",
            attachmentID: "conversation-run"
        ) else {
            throw Failure.attachmentDidNotOpen
        }
        guard control.handle(.enter) == .runOpened(
            messageID: "assistant-run",
            runID: "conversation-run"
        ) else {
            throw Failure.runDidNotOpen
        }
        guard control.handle(.char("q")) == .runClosed(
            runID: "conversation-run"
        ) else {
            throw Failure.runDidNotClose
        }
        _ = control.handle(.char("q"))

        var frame = TerminalFrame(rows: 24, columns: 80)
        control.render(
            into: &frame,
            in: TerminalRegion(rows: 24, columns: 80)
        )
        let rendered = frame.resolved().spans
            .map(\.content)
            .joined(separator: "\n")
        guard rendered.contains("agentic conversation"),
              rendered.contains("Mock model"),
              rendered.contains("swift-editing"),
              rendered.contains("run · conversation-run")
        else {
            throw Failure.presentationMissing
        }
    }

    static func fixture() -> AgenticConversationSnapshot {
        AgenticConversationSnapshot(
            workspace: "/tmp/FakeLibrary",
            messages: [
                AgenticConversationMessagePresentation(
                    id: "user-request",
                    role: .user,
                    body: "Inspect the mock library."
                ),
                AgenticConversationMessagePresentation(
                    id: "assistant-run",
                    role: .assistant,
                    body: "I prepared a run for inspection.",
                    attachments: [.run(runID: "conversation-run")]
                ),
            ],
            models: [
                AgenticConversationModelPresentation(
                    id: "apple-default",
                    title: "Apple Foundation Models",
                    detail: "on-device system model"
                ),
                AgenticConversationModelPresentation(
                    id: "mock-model",
                    title: "Mock model",
                    detail: "deterministic interface fixture"
                ),
            ],
            selectedModelProfileID: "apple-default",
            skills: [
                AgenticConversationSkillPresentation(
                    id: "swift-editing",
                    title: "Swift editing",
                    summary: "Inspect, mutate, parse, and test Swift sources.",
                    toolNames: [
                        "read_swift_structure",
                        "mutate_files",
                        "swift_parse",
                        "swift_run_product",
                    ]
                ),
            ],
            hostConsole: AgenticHostConsoleSnapshot(
                runs: [
                    AgenticHostConsoleRunPresentation(
                        id: "conversation-run",
                        title: "Inspect mock library",
                        summary: "1 operation passed",
                        state: .completed,
                        steps: [
                            AgenticHostConsoleStepPresentation(
                                id: "inspect-step",
                                title: "inspect_workspace",
                                state: .completed,
                                fields: [
                                    AgenticHostConsoleField(
                                        "outcome",
                                        "succeeded"
                                    ),
                                ]
                            ),
                        ]
                    ),
                ]
            )
        )
    }
}
