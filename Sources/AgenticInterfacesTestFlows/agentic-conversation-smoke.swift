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
        case invocationOptionsSelectionChanged
        case autonomySelectionChanged
        case streamingCapabilityGateChanged
        case toolExposureSelectionChanged
        case customToolExposureSelectionChanged
        case customToolSelectionChanged
        case customToolPickerPresentationMissing
        case derivedToolSelectionChanged
        case skillSelectionChanged
        case settingsPresentationMissing
        case runDidNotOpen
        case runDidNotClose
        case assistantMarkdownSourceChanged
        case assistantMarkdownPresentationMissing
        case runCardProjectionChanged
        case runCardStyleChanged
        case transcriptQExited
        case selectedMessagePresentationChanged
        case selectedMessageViewportChanged
        case presentationMissing
    }

    static func run() throws {
        try AgenticConversationPendingSmoke.run()
        try AgenticConversationRunReviewSmoke.run()
        try AgenticConversationComposerSmoke.run()

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
              card.hint == "Enter for actions",
              card.tone == .warning
        else {
            throw Failure.runCardProjectionChanged
        }

        let completedWarningRun = AgenticHostConsoleRunPresentation(
            id: "completed-warning-run",
            title: "Recovered fixture",
            summary: "Recovered after discovery.",
            state: .completed,
            steps: [
                AgenticHostConsoleStepPresentation(
                    id: "warning-find",
                    title: "find_tools",
                    state: .completed
                ),
                AgenticHostConsoleStepPresentation(
                    id: "warning-hidden-call",
                    title: "mutate_files",
                    detail: "Tool was registered but not exposed.",
                    state: .warning
                ),
                AgenticHostConsoleStepPresentation(
                    id: "warning-retry",
                    title: "mutate_files",
                    state: .completed
                ),
            ]
        )
        let completedWarningCard =
            AgenticConversationRunCardPresentation.project(
                run: completedWarningRun,
                hostConsole: AgenticHostConsoleSnapshot(
                    runs: [
                        completedWarningRun,
                    ]
                )
            )

        guard completedWarningCard.title == "Run · completed",
              completedWarningCard.body == [
                "3 steps · 1 warning",
                "Recovered after discovery.",
              ].joined(separator: "\n"),
              completedWarningCard.hint == "Enter for run details",
              completedWarningCard.tone == .success
        else {
            throw Failure.runCardProjectionChanged
        }

        let toneExpectations: [
            (
                AgenticHostConsoleRunState,
                AgenticConversationRunCardTone
            )
        ] = [
            (.ready, .neutral),
            (.active, .active),
            (.pause_pending, .neutral),
            (.paused, .neutral),
            (.awaitingApproval, .warning),
            (.onHold, .warning),
            (.completed, .success),
            (.failed, .failure),
        ]

        for (state, expectedTone) in toneExpectations {
            var run = cardRun
            run.state = state
            let projected =
                AgenticConversationRunCardPresentation.project(
                    run: run,
                    hostConsole: AgenticHostConsoleSnapshot(
                        runs: [
                            run,
                        ]
                    )
                )

            guard projected.tone == expectedTone else {
                throw Failure.runCardProjectionChanged
            }
        }

        let colorExpectations: [
            (
                AgenticHostConsoleRunState,
                String
            )
        ] = [
            (.awaitingApproval, ANSIColor.yellow.rawValue),
            (.onHold, ANSIColor.yellow.rawValue),
            (.completed, ANSIColor.green.rawValue),
            (.failed, ANSIColor.red.rawValue),
        ]

        for (state, expectedColor) in colorExpectations {
            var run = cardRun
            run.state = state

            var colorSnapshot = fixture()
            colorSnapshot.messages = [
                AgenticConversationMessagePresentation(
                    id: "semantic-run-card",
                    role: .assistant,
                    body: "Semantic run card fixture.",
                    attachments: [
                        .run(
                            runID: run.id
                        ),
                    ]
                ),
            ]
            colorSnapshot.hostConsole =
                AgenticHostConsoleSnapshot(
                    runs: [
                        run,
                    ]
                )

            var colorControl =
                AgenticConversationControl(
                    snapshot: colorSnapshot
                )
            var colorFrame = TerminalFrame(
                rows: 24,
                columns: 80
            )
            colorControl.render(
                into: &colorFrame,
                in: TerminalRegion(
                    rows: 24,
                    columns: 80
                )
            )
            let colorRendered = colorFrame
                .resolved()
                .spans
                .map(\.content)
                .joined(
                    separator: "\n"
                )

            guard colorRendered.contains(
                expectedColor
            ) else {
                throw Failure.runCardStyleChanged
            }
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

        let submitted = control.handle(
            TerminalKeyStroke(
                key: .enter,
                modifiers: .control
            )
        )
        guard case .submissionRequested(let submission)? = submitted,
              submission.body == "q",
              submission.origin == .typed,
              submission.contents.map(\.body) == [pasted],
              submission.contents.map(\.kind) == [.pasted],
              submission.modelProfileID.rawValue == "apple-default",
              submission.skillIDs.isEmpty,
              submission.toolExposure == .discovery,
              submission.customToolSelection == AgenticConversationToolSelection(
                identifiers: [
                    "inspect_workspace",
                ],
                dynamicDiscovery: true
              ),
              submission.responseDelivery == .stream,
              submission.invocationoptions == .default,
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

        let voiceSubmitted = control.handle(
            TerminalKeyStroke(
                key: .enter,
                modifiers: .control
            )
        )
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
        _ = unconfiguredControl.handle(
            .escape
        )
        _ = unconfiguredControl.handle(
            .tab
        )
        guard unconfiguredControl.focus.current == .voice,
              unconfiguredControl.handle(
                .enter
              ) == .feedbackRequested(
                "Voice input unavailable — no transcription provider configured."
              )
        else {
            throw Failure.voiceAvailabilityChanged
        }

        var availableSnapshot = fixture()
        availableSnapshot.voiceAvailability = .available

        var availableControl = AgenticConversationControl(
            snapshot: availableSnapshot
        )
        _ = availableControl.handle(
            .escape
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
        _ = control.handle(.escape)

        var settingsControl = AgenticConversationControl(
            snapshot: fixture()
        )
        _ = settingsControl.handle(
            .escape
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
                "Invocation options"
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

        var customSettingsControl = AgenticConversationControl(
            snapshot: fixture()
        )
        _ = customSettingsControl.handle(
            .escape
        )
        _ = customSettingsControl.handle(
            .escape
        )
        _ = customSettingsControl.handle(
            .char("s")
        )
        _ = customSettingsControl.handle(
            .char("j")
        )
        _ = customSettingsControl.handle(
            .char("j")
        )
        _ = customSettingsControl.handle(
            .char("j")
        )
        _ = customSettingsControl.handle(
            .char("j")
        )
        _ = customSettingsControl.handle(
            .enter
        )
        _ = customSettingsControl.handle(
            .char("j")
        )
        _ = customSettingsControl.handle(
            .char("j")
        )
        _ = customSettingsControl.handle(
            .char("j")
        )

        guard customSettingsControl.handle(
            .enter
        ) == .toolExposureSelectionChanged(
            .custom
        ) else {
            throw Failure.customToolExposureSelectionChanged
        }

        var customPickerFrame = TerminalFrame(
            rows: 28,
            columns: 100
        )
        customSettingsControl.render(
            into: &customPickerFrame,
            in: TerminalRegion(
                rows: 28,
                columns: 100
            )
        )
        let customPickerPresentation = stripANSI(
            customPickerFrame.resolved().spans
                .map(\.content)
                .joined(
                    separator: "\n"
                )
        )

        guard customPickerPresentation.contains(
            "Conversation settings / Tool exposure / Custom"
        ),
              customPickerPresentation.contains(
                "Dynamic discovery"
              ),
              customPickerPresentation.contains(
                "Core"
              ),
              customPickerPresentation.contains(
                "1 / 2"
              ),
              customPickerPresentation.contains(
                "Intrinsics"
              )
        else {
            throw Failure.customToolPickerPresentationMissing
        }

        guard customSettingsControl.handle(
            .space
        ) == .customToolSelectionChanged(
            AgenticConversationToolSelection(
                identifiers: [
                    "inspect_workspace",
                ],
                dynamicDiscovery: false
            )
        ) else {
            throw Failure.customToolSelectionChanged
        }

        _ = customSettingsControl.handle(
            .char("j")
        )
        guard customSettingsControl.handle(
            .space
        ) == .customToolSelectionChanged(
            AgenticConversationToolSelection(
                identifiers: [
                    "inspect_workspace",
                    "mutate_files",
                ],
                dynamicDiscovery: false
            )
        ) else {
            throw Failure.customToolSelectionChanged
        }

        _ = customSettingsControl.handle(
            .enter
        )
        guard customSettingsControl.handle(
            .space
        ) == .customToolSelectionChanged(
            AgenticConversationToolSelection(
                identifiers: [
                    "mutate_files",
                ],
                dynamicDiscovery: false
            )
        ) else {
            throw Failure.customToolSelectionChanged
        }

        _ = customSettingsControl.handle(
            .char("q")
        )
        _ = customSettingsControl.handle(
            .char("j")
        )
        _ = customSettingsControl.handle(
            .enter
        )

        guard customSettingsControl.handle(
            .space
        ) == .feedbackRequested(
            "Tool 'find_tools' is controlled by Dynamic discovery."
        ) else {
            throw Failure.derivedToolSelectionChanged
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

        var invocationControl = AgenticConversationControl(
            snapshot: fixture()
        )
        _ = invocationControl.handle(.escape)
        _ = invocationControl.handle(.escape)
        _ = invocationControl.handle(.char("s"))
        _ = invocationControl.handle(.char("j"))
        _ = invocationControl.handle(.char("j"))
        _ = invocationControl.handle(.enter)
        _ = invocationControl.handle(.enter)
        _ = invocationControl.handle(.char("j"))
        _ = invocationControl.handle(.char("j"))
        _ = invocationControl.handle(.char("j"))
        _ = invocationControl.handle(.char("j"))
        guard invocationControl.handle(.enter) == .invocationOptionsSelectionChanged(
            .init(timeoutseconds: 1_800)
        ),
              invocationControl.snapshot.selectedInvocationOptions.timeoutseconds == 1_800
        else {
            throw Failure.invocationOptionsSelectionChanged
        }

        var autonomyControl = AgenticConversationControl(
            snapshot: fixture()
        )
        _ = autonomyControl.handle(.escape)
        _ = autonomyControl.handle(.escape)
        _ = autonomyControl.handle(.char("s"))
        _ = autonomyControl.handle(.char("j"))
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
        guard control.handle(.char("q")) == nil else {
            throw Failure.transcriptQExited
        }

        var frame = TerminalFrame(rows: 24, columns: 80)
        control.render(
            into: &frame,
            in: TerminalRegion(rows: 24, columns: 80)
        )
        let rendered = frame.resolved().spans
            .map(\.content)
            .joined(separator: "\n")
        let selectedBody = TerminalStyle(
            foreground: .hex(
                "#d0d0d0"
            ),
            background: .hex(
                "#3a3d43"
            )
        ).apply(
            TerminalDisplay.fitted(
                "  I prepared a run for inspection.",
                columns: 80
            )
        )

        guard rendered.contains(selectedBody),
              rendered.contains("ctrl-c composer"),
              !rendered.contains("q quit")
        else {
            throw Failure.selectedMessagePresentationChanged
        }

        guard rendered.contains(
            ANSIColor.green.rawValue
        ) else {
            throw Failure.runCardStyleChanged
        }

        var viewportSnapshot = fixture()
        viewportSnapshot.messages = [
            AgenticConversationMessagePresentation(
                id: "viewport-first",
                role: .user,
                body: "first message"
            ),
            AgenticConversationMessagePresentation(
                id: "viewport-long",
                role: .assistant,
                body: [
                    "long-1",
                    "long-2",
                    "long-3",
                    "long-4",
                    "long-5",
                    "long-6",
                    "long-tail",
                ].joined(separator: "\n")
            ),
        ]
        var viewportControl = AgenticConversationControl(
            snapshot: viewportSnapshot
        )
        _ = viewportControl.handle(.escape)
        _ = viewportControl.handle(.escape)
        _ = viewportControl.handle(.char("k"))

        var viewportFrame = TerminalFrame(
            rows: 10,
            columns: 60
        )
        viewportControl.render(
            into: &viewportFrame,
            in: TerminalRegion(
                rows: 10,
                columns: 60
            )
        )
        _ = viewportControl.handle(.char("j"))

        viewportFrame.removeAll()
        viewportControl.render(
            into: &viewportFrame,
            in: TerminalRegion(
                rows: 10,
                columns: 60
            )
        )
        let viewportRendered = stripANSI(
            viewportFrame.resolved().spans
                .map(\.content)
                .joined(separator: "\n")
        )

        guard viewportRendered.contains("long-tail") else {
            throw Failure.selectedMessageViewportChanged
        }

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
              rendered.contains("1 step"),
              !rendered.contains("Stage 1 of 1 · inspect_workspace"),
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
            toolCollections: [
                AgenticConversationToolCollectionPresentation(
                    id: "core",
                    title: "Core",
                    tools: [
                        AgenticConversationToolPresentation(
                            id: "inspect_workspace",
                            title: "inspect_workspace",
                            summary: "Inspect the active workspace."
                        ),
                        AgenticConversationToolPresentation(
                            id: "mutate_files",
                            title: "mutate_files",
                            summary: "Apply bounded file mutations."
                        ),
                    ]
                ),
                AgenticConversationToolCollectionPresentation(
                    id: "intrinsics",
                    title: "Intrinsics",
                    tools: [
                        AgenticConversationToolPresentation(
                            id: "find_tools",
                            title: "find_tools",
                            summary: "Discover and activate registered tools.",
                            selectionRole: .dynamicDiscovery
                        ),
                        AgenticConversationToolPresentation(
                            id: "inspect_tool_registry",
                            title: "inspect_tool_registry",
                            summary: "Inspect registered tool metadata."
                        ),
                    ]
                ),
            ],
            customToolSelection: AgenticConversationToolSelection(
                identifiers: [
                    "inspect_workspace",
                ],
                dynamicDiscovery: true
            ),
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