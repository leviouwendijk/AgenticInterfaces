import AgenticInterfaces
import Terminal

enum AgenticConversationSmoke {
    static let assistantMarkdown = """
    ## Inspection ready

    I prepared a **run** for inspection.

    - preserves the original Markdown
    - renders structured content

    `body` stays canonical.
    """

    enum Failure: Error {
        case composerConsumedQ
        case pastedContentChanged
        case submissionChanged
        case transcriptionDraftChanged
        case transcribedContentChanged
        case voiceAvailabilityChanged
        case voiceStartChanged
        case voiceStopChanged
        case voiceCancelChanged
        case voiceFocusChanged
        case voiceStatusChanged
        case modelSelectionChanged
        case responseDeliverySelectionChanged
        case autonomySelectionChanged
        case streamingCapabilityGateChanged
        case toolExposureSelectionChanged
        case skillSelectionChanged
        case settingsPresentationMissing
        case runDidNotOpen
        case runDidNotClose
        case assistantMarkdownSourceChanged
        case assistantMarkdownPresentationMissing
        case runCardProjectionChanged
        case presentationMissing
    }

    static func run() throws {
        try AgenticConversationPendingSmoke.run()

        let cardRun = AgenticHostConsoleRunPresentation(
            id: "card-run",
            title: "Card fixture",
            summary: "fallback run summary",
            state: .awaitingApproval,
            steps: [
                AgenticHostConsoleStepPresentation(
                    id: "card-inspect",
                    title: "inspect_workspace",
                    state: .completed
                ),
                AgenticHostConsoleStepPresentation(
                    id: "card-mutate",
                    title: "mutate_files",
                    state: .pending
                ),
                AgenticHostConsoleStepPresentation(
                    id: "card-parse",
                    title: "swift_parse",
                    state: .pending
                ),
            ]
        )
        let card = AgenticConversationRunCardPresentation.project(
            run: cardRun,
            hostConsole: AgenticHostConsoleSnapshot(
                runs: [
                    cardRun,
                ],
                interruptions: [
                    AgenticHostConsoleInterruptionPresentation(
                        id: "card-approval",
                        runID: "card-run",
                        stepID: "card-mutate",
                        kind: .approval,
                        title: "Approval",
                        summary: "Human review required",
                        actions: [
                            .approve,
                            .deny,
                            .skip,
                        ]
                    ),
                ]
            )
        )

        guard card.title == "Run · awaiting review",
              card.body == [
                "Stage 2 of 3 · mutate_files",
                "Human review required",
              ].joined(separator: "\n"),
              card.hint == "Enter for actions"
        else {
            throw Failure.runCardProjectionChanged
        }

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
              submission.toolExposure == .discovery,
              submission.responseDelivery == .stream,
              submission.autonomyMode == .auto_observe,
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

        var unconfiguredControl = AgenticConversationControl(
            snapshot: fixture()
        )
        guard unconfiguredControl.handle(
            .control("V")
        ) == .feedbackRequested(
            "Voice input unavailable — no transcription provider configured."
        ) else {
            throw Failure.voiceAvailabilityChanged
        }

        var availableSnapshot = fixture()
        availableSnapshot.voiceAvailability = .available

        var availableControl = AgenticConversationControl(
            snapshot: availableSnapshot
        )
        guard availableControl.handle(
            .tab
        ) == nil,
              availableControl.focus.current == .voice,
              availableControl.handle(
                .enter
              ) == .voiceStartRequested
        else {
            throw Failure.voiceFocusChanged
        }

        availableSnapshot.voiceState = .recording
        availableSnapshot.voiceStatus = .init(
            elapsedSeconds: 7,
            level: 0.75
        )

        availableControl.update(
            availableSnapshot
        )

        var recordingFrame = TerminalFrame(
            rows: 24,
            columns: 80
        )
        availableControl.render(
            into: &recordingFrame,
            in: TerminalRegion(
                rows: 24,
                columns: 80
            )
        )
        let recordingPresentation = stripANSI(
            recordingFrame.resolved().spans
                .map(\.content)
                .joined(separator: "\n")
        )

        guard recordingPresentation.contains(
            "recording  00:07"
        ),
              recordingPresentation.contains(
                "●"
              )
        else {
            throw Failure.voiceStatusChanged
        }

        var recordingControl = AgenticConversationControl(
            snapshot: availableSnapshot
        )
        _ = recordingControl.handle(
            .char("q")
        )
        guard recordingControl.draftText == "q" else {
            throw Failure.composerConsumedQ
        }

        guard recordingControl.handle(
            .control("V")
        ) == .voiceStopRequested else {
            throw Failure.voiceStopChanged
        }

        guard recordingControl.handle(
            .escape
        ) == .voiceCancelRequested,
              recordingControl.draftText == "q"
        else {
            throw Failure.voiceCancelChanged
        }

        _ = control.handle(.escape)

        var settingsControl = AgenticConversationControl(
            snapshot: fixture()
        )
        _ = settingsControl.handle(
            .escape
        )
        _ = settingsControl.handle(
            .char("s")
        )
        var settingsFrame = TerminalFrame(
            rows: 28,
            columns: 100
        )
        settingsControl.render(
            into: &settingsFrame,
            in: TerminalRegion(
                rows: 28,
                columns: 100
            )
        )
        let settingsPresentation = stripANSI(
            settingsFrame.resolved().spans
                .map(\.content)
                .joined(
                    separator: "\n"
                )
        )
        guard settingsPresentation.contains(
            "Conversation settings"
        ),
              settingsPresentation.contains(
                "Model"
              ),
              settingsPresentation.contains(
                "Response"
              ),
              settingsPresentation.contains(
                "Autonomy"
              ),
              settingsPresentation.contains(
                "Tool exposure"
              ),
              settingsPresentation.contains(
                "Skills"
              )
        else {
            throw Failure.settingsPresentationMissing
        }

        _ = control.handle(
            .char("m")
        )
        _ = control.handle(
            .char("j")
        )
        guard control.handle(
            .enter
        ) == .modelSelectionChanged(
            "mock-model"
        ) else {
            throw Failure.modelSelectionChanged
        }
        _ = control.handle(
            .char("q")
        )

        var responseControl = AgenticConversationControl(
            snapshot: fixture()
        )
        _ = responseControl.handle(
            .escape
        )
        _ = responseControl.handle(
            .char("s")
        )
        _ = responseControl.handle(
            .char("j")
        )
        _ = responseControl.handle(
            .enter
        )
        _ = responseControl.handle(
            .char("j")
        )
        guard responseControl.handle(
            .enter
        ) == .responseDeliverySelectionChanged(
            .buffered
        ) else {
            throw Failure.responseDeliverySelectionChanged
        }

        var autonomyControl = AgenticConversationControl(
            snapshot: fixture()
        )
        _ = autonomyControl.handle(.escape)
        _ = autonomyControl.handle(.char("s"))
        _ = autonomyControl.handle(.char("j"))
        _ = autonomyControl.handle(.char("j"))
        _ = autonomyControl.handle(.enter)
        _ = autonomyControl.handle(.char("j"))
        guard autonomyControl.handle(.enter) == .autonomySelectionChanged(
            .auto_bounded_mutate
        ),
              autonomyControl.snapshot.selectedAutonomyMode == .auto_bounded_mutate
        else {
            throw Failure.autonomySelectionChanged
        }

        var nonStreamingSnapshot = fixture()
        nonStreamingSnapshot.selectedModelProfileID = "buffered-model"
        nonStreamingSnapshot.selectedResponseDelivery = .buffered

        var nonStreamingControl = AgenticConversationControl(
            snapshot: nonStreamingSnapshot
        )
        _ = nonStreamingControl.handle(
            .escape
        )
        _ = nonStreamingControl.handle(
            .char("s")
        )
        _ = nonStreamingControl.handle(
            .char("j")
        )
        _ = nonStreamingControl.handle(
            .enter
        )
        _ = nonStreamingControl.handle(
            .char("k")
        )
        guard nonStreamingControl.handle(
            .enter
        ) == .feedbackRequested(
            "Streaming is unavailable for the selected model."
        ) else {
            throw Failure.streamingCapabilityGateChanged
        }

        _ = control.handle(
            .char("s")
        )
        _ = control.handle(
            .char("j")
        )
        _ = control.handle(
            .char("j")
        )
        _ = control.handle(
            .char("j")
        )
        _ = control.handle(
            .enter
        )
        _ = control.handle(
            .char("j")
        )
        guard control.handle(
            .enter
        ) == .toolExposureSelectionChanged(
            .all
        ) else {
            throw Failure.toolExposureSelectionChanged
        }
        _ = control.handle(
            .char("q")
        )

        _ = control.handle(
            .char("s")
        )
        _ = control.handle(
            .char("j")
        )
        _ = control.handle(
            .char("j")
        )
        _ = control.handle(
            .char("j")
        )
        _ = control.handle(
            .char("j")
        )
        _ = control.handle(
            .enter
        )
        guard control.handle(
            .space
        ) == .skillSelectionChanged([
            "swift-editing",
        ]) else {
            throw Failure.skillSelectionChanged
        }
        _ = control.handle(
            .char("q")
        )
        _ = control.handle(
            .char("q")
        )

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

        guard control.snapshot.messages.first(where: {
            $0.id == "assistant-run"
        })?.body == assistantMarkdown else {
            throw Failure.assistantMarkdownSourceChanged
        }

        guard rendered.contains("Inspection ready"),
              rendered.contains("preserves the original Markdown"),
              rendered.contains("renders structured content"),
              rendered.contains("body"),
              !rendered.contains("## Inspection ready"),
              !rendered.contains("**run**"),
              !rendered.contains("`body`")
        else {
            throw Failure.assistantMarkdownPresentationMissing
        }

        guard rendered.contains("agentic conversation"),
              rendered.contains("Mock model"),
              rendered.contains("all tools"),
              rendered.contains("Swift editing"),
              rendered.contains("Run · completed"),
              rendered.contains("Stage 1 of 1 · inspect_workspace"),
              rendered.contains("1 operation passed"),
              rendered.contains("Enter for run details")
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
                    body: assistantMarkdown,
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
                AgenticConversationModelPresentation(
                    id: "buffered-model",
                    title: "Buffered-only model",
                    detail: "does not support streaming",
                    supportsStreaming: false
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