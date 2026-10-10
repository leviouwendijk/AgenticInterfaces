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
        case modelPreferenceChanged
        case responseDeliverySelectionChanged
        case invocationOptionsSelectionChanged
        case autonomySelectionChanged
        case streamingCapabilityGateChanged
        case capabilitySelectionChanged
        case capabilityBrowserPresentationMissing
        case derivedToolSelectionChanged
        case instructionSelectionChanged
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
        case presentationMissing(String)
        case programCommandChanged
    }

    static func run() throws {
        try AgenticConversationUserInputSmoke.run()
        try AgenticConversationUserInputIntegrationSmoke.run()
        try AgenticConversationPendingSmoke.run()
        try AgenticConversationRunReviewSmoke.run()
        try AgenticConversationComposerSmoke.run()
        try AgenticConversationPinnedContentSmoke.run()

        var programSnapshot = fixture()
        programSnapshot.programs = [
            .init(
                identifier: "fixture.conversation_program",
                purpose: "Conversation Program command fixture.",
                title: "Conversation Program"
            ),
        ]
        var programControl = AgenticConversationControl(
            snapshot: programSnapshot
        )
        _ = programControl.applyTranscription(
            .init(
                text: "/program fixture.conversation_program {\"value\":\"hello\"}"
            )
        )
        let programEvent = programControl.handle(
            TerminalKeyStroke(
                key: .enter,
                modifiers: .control
            )
        )

        guard case .programInvocationRequested(
            let invocation,
            let submission
        )? = programEvent,
              invocation.program.rawValue == "fixture.conversation_program",
              submission.body == "/program fixture.conversation_program {\"value\":\"hello\"}"
        else {
            throw Failure.programCommandChanged
        }

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
            (.interrupted, .neutral),
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
        guard control.handle(.paste(pasted)) == nil,
              control.draftText == "qalpha\nbeta\n",
              control.pinnedContents.isEmpty
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
              submission.body == "qalpha\nbeta",
              submission.origin == .typed,
              submission.contents.isEmpty,
              submission.preferredModelProfileID.rawValue == "apple-default",
              submission.instructionIDs.isEmpty,
              submission.availableCapabilities.tools == ["inspect_workspace"],
              submission.visibleCapabilities.tools == ["inspect_workspace"],
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
        guard unconfiguredControl.handle(
            .controlSpace
        ) == .feedbackRequested(
            "Voice input unavailable — no transcription provider configured."
        ),
              unconfiguredControl.focus.current == .composer
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
        _ = availableControl.handle(
            .tab
        )
        guard availableControl.focus.current == .transcript,
              availableControl.handle(
                .controlSpace
              ) == .voiceStartRequested,
              availableControl.focus.current == .voice
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

        guard availableControl.handle(
            .controlSpace
        ) == .voiceStopRequested,
              availableControl.focus.current == .transcript
        else {
            throw Failure.voiceStopChanged
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
            .controlSpace
        ) == .voiceStopRequested,
              recordingControl.focus.current == .composer
        else {
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
              settingsPresentation.contains("Capabilities")
        else {
            throw Failure.settingsPresentationMissing
        }

        // Browse by Domain, then Type; availability and visibility are separate.
        var browserControl = AgenticConversationControl(snapshot: fixture())
        _ = browserControl.handle(.escape)
        _ = browserControl.handle(.escape)
        _ = browserControl.handle(.char("s"))
        for _ in 0..<4 { _ = browserControl.handle(.char("j")) }
        _ = browserControl.handle(.enter) // Capabilities
        _ = browserControl.handle(.char("j")) // Domain first
        _ = browserControl.handle(.enter)
        _ = browserControl.handle(.enter) // Core domain
        _ = browserControl.handle(.enter) // Tools
        guard browserControl.handle(.enter) == .capabilitySelectionChanged(
            available: .init(tools: ["inspect_workspace"]),
            visible: .none
        ) else {
            throw Failure.capabilitySelectionChanged
        }
        // Search is user-facing and must filter the *same* catalog.
        // Domain and Type metadata are searchable, not inferred from IDs.
        let catalog = fixture().capabilityEntries
        let domainMatches = AgenticConversationCapabilityEntry.search(
            "core",
            in: catalog
        )
        guard domainMatches.contains(where: { $0.identifier == "mutate_files" }),
              domainMatches.allSatisfy({ $0.domain == "Core" })
        else {
            throw Failure.capabilityBrowserPresentationMissing
        }
        let compoundMatches = AgenticConversationCapabilityEntry.search(
            "core mutate",
            in: catalog
        )
        guard compoundMatches.first?.identifier == "mutate_files",
              !compoundMatches.contains(where: { $0.identifier == "inspect_workspace" })
        else {
            throw Failure.capabilityBrowserPresentationMissing
        }
        let fuzzyMatches = AgenticConversationCapabilityEntry.search(
            "mtat",
            in: catalog
        )
        guard fuzzyMatches.contains(where: { $0.identifier == "mutate_files" })
        else {
            throw Failure.capabilityBrowserPresentationMissing
        }
        _ = browserControl.handle(.char("/"))
        for character in "mutate" { _ = browserControl.handle(.char(String(character))) }
        _ = browserControl.handle(.enter)
        var searchFrame = TerminalFrame(rows: 28, columns: 100)
        browserControl.render(into: &searchFrame,
            in: TerminalRegion(rows: 28, columns: 100))
        let searchText = stripANSI(searchFrame.resolved().spans.map(\.content).joined(separator: "\n"))
        guard searchText.contains("Search: /mutate"),
              searchText.contains("mutate_files"),
              !searchText.contains("inspect_workspace") else {
            throw Failure.capabilityBrowserPresentationMissing
        }
        guard browserControl.handle(.space) == .capabilitySelectionChanged(
            available: .init(tools: ["inspect_workspace", "mutate_files"]),
            visible: .none
        ) else {
            throw Failure.capabilitySelectionChanged
        }

        _ = control.handle(
            .char("m")
        )
        _ = control.handle(
            .char("j")
        )
        guard control.handle(
            .enter
        ) == .modelPreferenceChanged(
            "mock-model"
        ) else {
            throw Failure.modelPreferenceChanged
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
        nonStreamingSnapshot.preferredModelProfileID = "buffered-model"
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

        // Instruction selection never grants executable authority.
        var instructionControl = AgenticConversationControl(snapshot: fixture())
        _ = instructionControl.handle(.escape)
        _ = instructionControl.handle(.escape)
        _ = instructionControl.handle(.char("s"))
        for _ in 0..<4 { _ = instructionControl.handle(.char("j")) }
        _ = instructionControl.handle(.enter)
        _ = instructionControl.handle(.char("/"))
        for character in "Swift editing" { _ = instructionControl.handle(.char(String(character))) }
        _ = instructionControl.handle(.enter)
        guard instructionControl.handle(.space) == .instructionSelectionChanged(["swift-editing"]),
              instructionControl.snapshot.availableCapabilities == fixture().availableCapabilities,
              instructionControl.snapshot.visibleCapabilities == fixture().visibleCapabilities
        else {
            throw Failure.instructionSelectionChanged
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

        guard control.focus.current == .transcript,
              rendered.contains(selectedBody),
              rendered.contains("tab composer"),
              !rendered.contains("tab voice"),
              !rendered.contains("q quit")
        else {
            throw Failure.selectedMessagePresentationChanged
        }

        guard rendered.contains(
            ANSIColor.green.rawValue
        ) else {
            throw Failure.runCardStyleChanged
        }

        var messageSelectionSnapshot = fixture()
        messageSelectionSnapshot.messages = [
            AgenticConversationMessagePresentation(
                id: "selection-first",
                role: .user,
                body: "first selection"
            ),
            AgenticConversationMessagePresentation(
                id: "selection-second",
                role: .assistant,
                body: "second selection"
            ),
        ]
        var messageSelectionControl = AgenticConversationControl(
            snapshot: messageSelectionSnapshot
        )

        messageSelectionSnapshot.messages.append(
            AgenticConversationMessagePresentation(
                id: "selection-third",
                role: .assistant,
                body: "third selection"
            )
        )
        messageSelectionControl.update(
            messageSelectionSnapshot
        )

        guard messageSelectionControl.currentMessage?.id == "selection-third" else {
            throw Failure.selectedMessagePresentationChanged
        }

        _ = messageSelectionControl.handle(.escape)
        _ = messageSelectionControl.handle(.escape)
        _ = messageSelectionControl.handle(.char("k"))

        guard messageSelectionControl.focus.current == .transcript,
              messageSelectionControl.currentMessage?.id == "selection-second"
        else {
            throw Failure.selectedMessagePresentationChanged
        }

        _ = messageSelectionControl.handle(.tab)
        messageSelectionSnapshot.messages.append(
            AgenticConversationMessagePresentation(
                id: "selection-fourth",
                role: .assistant,
                body: "fourth selection"
            )
        )
        messageSelectionControl.update(
            messageSelectionSnapshot
        )

        guard messageSelectionControl.focus.current == .composer,
              messageSelectionControl.currentMessage?.id == "selection-second"
        else {
            throw Failure.selectedMessagePresentationChanged
        }

        _ = messageSelectionControl.handle(.tab)

        guard messageSelectionControl.focus.current == .transcript,
              messageSelectionControl.currentMessage?.id == "selection-second"
        else {
            throw Failure.selectedMessagePresentationChanged
        }

        _ = messageSelectionControl.handle(.char("j"))
        _ = messageSelectionControl.handle(.char("j"))

        guard messageSelectionControl.currentMessage?.id == "selection-fourth" else {
            throw Failure.selectedMessagePresentationChanged
        }

        _ = messageSelectionControl.handle(.tab)
        messageSelectionSnapshot.messages.append(
            AgenticConversationMessagePresentation(
                id: "selection-fifth",
                role: .assistant,
                body: "fifth selection"
            )
        )
        messageSelectionControl.update(
            messageSelectionSnapshot
        )

        guard messageSelectionControl.currentMessage?.id == "selection-fifth" else {
            throw Failure.selectedMessagePresentationChanged
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

        viewportFrame.removeAll()
        viewportControl.render(
            into: &viewportFrame,
            in: TerminalRegion(
                rows: 10,
                columns: 60
            )
        )
        let stableViewportRendered = stripANSI(
            viewportFrame.resolved().spans
                .map(\.content)
                .joined(separator: "\n")
        )

        guard stableViewportRendered.contains("long-tail") else {
            throw Failure.selectedMessageViewportChanged
        }

        guard viewportControl.handle(.enter) == .feedbackRequested(
            "Selected message has no attached content or run."
        ) else {
            throw Failure.selectedMessageViewportChanged
        }

        viewportFrame.removeAll()
        viewportControl.render(
            into: &viewportFrame,
            in: TerminalRegion(
                rows: 10,
                columns: 60
            )
        )
        let inspectedViewportRendered = stripANSI(
            viewportFrame.resolved().spans
                .map(\.content)
                .joined(separator: "\n")
        )

        guard inspectedViewportRendered.contains("long-tail") else {
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

        // The fixture installs an Instruction but does not select it.
        // Installed metadata must not be presented as active guidance.
        let presentationChecks: [(String, Bool)] = [
            ("conversation title", rendered.contains("agentic conversation")),
            ("selected model", rendered.contains("Mock model")),
            ("visible tool count", rendered.contains("1 visible tools")),
            ("retired exposure preset absent", !rendered.contains("all tools")),
            ("no selected instructions", rendered.contains("no instructions")),
            ("completed run card", rendered.contains("Run · completed")),
            ("run step count", rendered.contains("1 step")),
            ("obsolete stage detail absent", !rendered.contains("Stage 1 of 1 · inspect_workspace")),
            ("run summary", rendered.contains("1 operation passed")),
            ("run details hint", rendered.contains("Enter for run details")),
        ]
        let missing = presentationChecks.filter { !$0.1 }.map { $0.0 }
        guard missing.isEmpty else {
            throw Failure.presentationMissing(missing.joined(separator: ", "))
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
            preferredModelProfileID: "apple-default",
            instructions: [
                AgenticConversationInstructionPresentation(
                    id: "swift-editing",
                    title: "Swift editing",
                    summary: "Inspect, mutate, parse, and test Swift sources.",
               ),
            ],
            capabilityEntries: [
                .init(kind: .tool, identifier: "inspect_workspace", namespace: "Core",
                    title: "inspect_workspace", summary: "Inspect the active workspace."),
                .init(kind: .tool, identifier: "mutate_files", namespace: "Core",
                    title: "mutate_files", summary: "Apply bounded file mutations."),
                .init(kind: .tool, identifier: "find_tools", namespace: "Intrinsics",
                    title: "find_tools", summary: "Discover installed capabilities."),
                .init(kind: .tool, identifier: "inspect_tool_registry", namespace: "Intrinsics",
                    title: "inspect_tool_registry", summary: "Inspect tool metadata."),
                .init(kind: .instruction, identifier: "swift-editing", namespace: "Swift",
                    title: "Swift editing", summary: "Inspect, mutate, parse, and test Swift sources."),
            ],
            availableCapabilities: .init(tools: ["inspect_workspace"]),
            visibleCapabilities: .init(tools: ["inspect_workspace"]),
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