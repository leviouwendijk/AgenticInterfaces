import Agentic
import Foundation
import ParsersStructuredContent
import Swim
import Terminal
import TerminalStructuredContent

public enum AgenticConversationFocus: Sendable, Hashable {
    case composer
    case voice
    case transcript
    case attachment
    case settings
    case runReview
    case run
}

public enum AgenticConversationEvent: Sendable, Hashable {
    case exitRequested
    case voiceStartRequested
    case voiceStopRequested
    case voiceCancelRequested
    case contentPinned(AgenticConversationContentPresentation)
    case submissionRequested(AgenticConversationSubmission)
    case modelPreferenceChanged(AgentModelProfileIdentifier)
    case responseDeliverySelectionChanged(AgentModelResponseDelivery)
    case invocationOptionsSelectionChanged(AgentModelInvocationOptions)
    case autonomySelectionChanged(AutonomyMode)
    case toolExposureSelectionChanged(AgenticConversationToolExposure)
    case customToolSelectionChanged(AgenticConversationToolSelection)
    case skillSelectionChanged([AgentSkillIdentifier])
    case attachmentOpened(messageID: String, attachmentID: String)
    case attachmentClosed(messageID: String)
    case runOpened(messageID: String, runID: String)
    case runClosed(runID: String)
    case run(AgenticHostConsoleWorkflowEvent)
    case feedbackRequested(String)
}

private enum AgenticConversationTranscriptReveal: Sendable {
    case start
    case end
}

public struct AgenticConversationControl: Sendable {
    public private(set) var snapshot: AgenticConversationSnapshot
    public private(set) var focus: TerminalFocusStack<AgenticConversationFocus>

    private var composer: AgenticConversationComposerControl
    private var voiceMeter: TerminalLevelMeter
    private var draftOrigin: AgenticConversationInputOrigin
    private var transcript: TerminalScrollableDocument
    private var attachmentDocument: TerminalScrollableDocument
    private var selectedMessageID: String?
    private var transcriptSelectionFollowsEnd: Bool
    private var pendingTranscriptReveal: AgenticConversationTranscriptReveal?
    private var pendingContents: [AgenticConversationContentPresentation]
    private var nextContentOrdinal: Int
    private var attachmentIndex: Int
    private var settings: AgenticConversationSettingsControl
    private var pendingSubmission: AgenticConversationSubmission?
    private var openedRunID: String?
    private var runReview: AgenticConversationRunReviewControl?
    private var hostConsole: AgenticHostConsoleWorkflowControl?

    public init(snapshot: AgenticConversationSnapshot) {
        self.snapshot = snapshot
        self.focus = TerminalFocusStack(.composer)
        self.composer = AgenticConversationComposerControl()
        self.voiceMeter = TerminalLevelMeter(
            capacity: 32
        )
        self.draftOrigin = .typed
        self.transcript = TerminalScrollableDocument(followEnd: true)
        self.attachmentDocument = TerminalScrollableDocument()
        self.selectedMessageID = snapshot.messages.last?.id
        self.transcriptSelectionFollowsEnd = true
        self.pendingTranscriptReveal = nil
        self.pendingContents = []
        self.nextContentOrdinal = 1
        self.attachmentIndex = 0
        self.settings = AgenticConversationSettingsControl(
            snapshot: snapshot
        )
        self.pendingSubmission = nil
        self.openedRunID = nil
        self.runReview = nil
        self.hostConsole = nil
    }

    public var draftText: String {
        composer.text
    }

    public var pinnedContents: [AgenticConversationContentPresentation] {
        pendingContents
    }

    public var isResponsePending: Bool {
        pendingSubmission != nil
    }

    public mutating func beginPendingTurn(
        _ submission: AgenticConversationSubmission
    ) {
        pendingSubmission = submission
        transcriptSelectionFollowsEnd = true
        pendingTranscriptReveal = nil
        transcript.moveToEnd()
    }

    public mutating func endPendingTurn() {
        pendingSubmission = nil
    }

    public var currentMessage: AgenticConversationMessagePresentation? {
        guard let selectedMessageID else {
            return nil
        }
        return snapshot.messages.first { $0.id == selectedMessageID }
    }

    public var currentAttachment: AgenticConversationAttachmentPresentation? {
        guard let currentMessage, !currentMessage.attachments.isEmpty else {
            return nil
        }
        let index = min(
            currentMessage.attachments.count - 1,
            max(0, attachmentIndex)
        )
        return currentMessage.attachments[index]
    }

    public mutating func update(_ snapshot: AgenticConversationSnapshot) {
        let previousMessageID = selectedMessageID
        let previousVoiceState = self.snapshot.voiceState
        self.snapshot = snapshot

        if snapshot.voiceState == .recording {
            if previousVoiceState != .recording {
                voiceMeter.reset()
            }

            if let level = snapshot.voiceStatus?.level {
                voiceMeter.append(
                    level
                )
            }
        } else if previousVoiceState == .recording {
            voiceMeter.reset()
        }
        if transcriptSelectionFollowsEnd {
            selectedMessageID = snapshot.messages.last?.id
        } else if let previousMessageID,
                  snapshot.messages.contains(where: { $0.id == previousMessageID })
        {
            selectedMessageID = previousMessageID
        } else {
            selectedMessageID = snapshot.messages.last?.id
            transcriptSelectionFollowsEnd = true
            pendingTranscriptReveal = selectedMessageID == nil
                ? nil
                : .end
        }
        settings.update(
            snapshot
        )

        if var runReview {
            if runReview.update(
                snapshot.hostConsole
            ) {
                self.runReview = runReview
            } else {
                self.runReview = nil

                if focus.current == .runReview {
                    focus.reset(
                        to: .transcript
                    )
                }
            }
        }

        guard let openedRunID else {
            return
        }
        guard snapshot.hostConsole.runs.contains(where: { $0.id == openedRunID }) else {
            self.openedRunID = nil
            hostConsole = nil
            focus.reset(to: .transcript)
            return
        }
        hostConsole?.update(snapshot.hostConsole)
    }

    public mutating func applyTranscription(
        _ transcription: AgenticConversationTranscription,
        disposition: AgenticConversationTranscriptionDisposition = .draft
    ) -> AgenticConversationEvent? {
        let text = SwimTextBuffer(
            text: transcription.text
        ).text

        guard !text.isEmpty else {
            return nil
        }

        switch disposition {
        case .draft:
            composer.replace(
                with: text
            )
            draftOrigin = .transcribed
            focus.reset(
                to: .composer
            )
            return nil

        case .pinned:
            return pin(
                text,
                kind: .transcribed,
                detail: transcription.localeIdentifier
            )
        }
    }

    public mutating func handle(
        _ event: TerminalInputEvent
    ) -> AgenticConversationEvent? {
        switch event {
        case .paste(let text):
            guard focus.current == .composer,
                  pendingSubmission == nil else {
                return nil
            }

            let normalized = SwimTextBuffer(
                text: text
            ).text
            guard !normalized.isEmpty else {
                return nil
            }

            if composer.isExpanded
                || !normalized.contains("\n")
            {
                composer.insertPaste(
                    normalized
                )
                return nil
            }

            return pin(
                normalized,
                kind: .pasted
            )

        case .key(let key):
            return handle(
                key
            )

        case .keyStroke(let keyStroke):
            return handle(
                keyStroke
            )
        }
    }

    public mutating func handle(
        _ keyStroke: TerminalKeyStroke
    ) -> AgenticConversationEvent? {
        if focus.current == .composer {
            if keyStroke.key == .control("V"),
               snapshot.voiceState == .recording
            {
                return voiceAction()
            }

            return handleComposer(
                keyStroke
            )
        }

        return handle(
            keyStroke.key
        )
    }

    public mutating func handle(_ key: TerminalKey) -> AgenticConversationEvent? {
        if key == .control("C") {
            return handle(
                .escape
            )
        }

        if key == .escape,
           snapshot.voiceState == .recording
        {
            focus.replace(
                .composer
            )
            return .voiceCancelRequested
        }

        if key == .control("V"),
           pendingSubmission != nil
        {
            return nil
        }

        if key == .control("V"),
           snapshot.voiceState == .recording
        {
            return voiceAction()
        }

        if key == .control("V") {
            switch focus.current {
            case .voice,
                 .transcript:
                return voiceAction()

            case .composer,
                 .attachment,
                 .settings,
                 .runReview,
                 .run:
                break
            }
        }

        switch focus.current {
        case .composer:
            return handleComposer(
                TerminalKeyStroke(
                    key: key
                )
            )
        case .voice:
            return handleVoice(key)
        case .transcript:
            return handleTranscript(key)
        case .attachment:
            return handleAttachment(key)
        case .settings:
            return handleSettings(key)
        case .runReview:
            return handleRunReview(key)
        case .run:
            return handleRun(key)
        }
    }

    public mutating func render(
        into frame: inout TerminalFrame,
        in region: TerminalRegion
    ) {
        guard !region.isEmpty else {
            return
        }

        if focus.current == .run, var hostConsole {
            hostConsole.render(into: &frame, in: region)
            self.hostConsole = hostConsole
            return
        }

        renderConversation(into: &frame, in: region)

        if focus.current == .voice {
            renderVoice(
                into: &frame,
                in: region
            )
        }

        switch focus.current {
        case .attachment:
            renderAttachment(into: &frame, in: region)
        case .settings:
            settings.render(
                into: &frame,
                in: region
            )
        case .runReview:
            if var runReview {
                runReview.render(
                    into: &frame,
                    in: region
                )
                self.runReview = runReview
            }
        case .composer:
            composer.renderOverlay(
                into: &frame,
                in: region
            )

        case .voice,
             .transcript,
             .run:
            break
        }
    }
}

private extension AgenticConversationControl {
    mutating func pin(
        _ source: String,
        kind: AgenticConversationContentKind,
        detail: String? = nil
    ) -> AgenticConversationEvent? {
        let source = SwimTextBuffer(text: source).text
        guard !source.isEmpty else {
            return nil
        }

        let lineCount = source.reduce(1) {
            $0 + ($1 == "\n" ? 1 : 0)
        }
        let lineLabel = lineCount == 1 ? "line" : "lines"
        let titlePrefix: String
        let summaryPrefix: String

        switch kind {
        case .pasted:
            titlePrefix = "Pasted"
            summaryPrefix = "paste"

        case .transcribed:
            titlePrefix = "Transcribed"
            summaryPrefix = if let detail,
                               !detail.isEmpty {
                "transcribed · \(detail)"
            } else {
                "transcribed"
            }
        }

        let content = AgenticConversationContentPresentation(
            id: "pending-content-\(nextContentOrdinal)",
            kind: kind,
            title: "\(titlePrefix) content \(nextContentOrdinal)",
            summary: "\(summaryPrefix) · \(lineCount) \(lineLabel)",
            body: source
        )
        nextContentOrdinal += 1
        pendingContents.append(content)
        return .contentPinned(content)
    }

    mutating func handleComposer(
        _ keyStroke: TerminalKeyStroke
    ) -> AgenticConversationEvent? {
        if pendingSubmission != nil {
            switch keyStroke.key {
            case .escape,
                 .control("C"):
                focus.replace(
                    .transcript
                )

            case .tab:
                focus.replace(
                    .voice
                )

            default:
                break
            }

            return nil
        }

        switch composer.handle(
            keyStroke
        ) {
        case .submitRequested?:
            return submitComposer()

        case .focusVoiceRequested?:
            focus.replace(
                .voice
            )
            return nil

        case .focusTranscriptRequested?:
            focus.replace(
                .transcript
            )
            return nil

        case .exitRequested?:
            return .exitRequested

        case nil:
            return nil
        }
    }

    mutating func submitComposer() -> AgenticConversationEvent? {
        let body = composer.text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !body.isEmpty || !pendingContents.isEmpty else {
            return .feedbackRequested("Message is empty.")
        }
        guard snapshot.models.contains(where: {
            $0.id == snapshot.preferredModelProfileID && $0.isAvailable
        }) else {
            return .feedbackRequested("Preferred model is unavailable.")
        }

        let submission = AgenticConversationSubmission(
            body: body,
            origin: draftOrigin,
            contents: pendingContents,
            preferredModelProfileID: snapshot.preferredModelProfileID,
            skillIDs: snapshot.selectedSkillIDs,
            toolExposure: snapshot.selectedToolExposure,
            customToolSelection: snapshot.customToolSelection,
            responseDelivery: snapshot.selectedResponseDelivery,
            invocationoptions: snapshot.selectedInvocationOptions,
            autonomyMode: snapshot.selectedAutonomyMode
        )
        composer.clearAfterSubmission()
        draftOrigin = .typed
        pendingContents.removeAll(keepingCapacity: true)
        return .submissionRequested(submission)
    }

    mutating func handleVoice(_ key: TerminalKey) -> AgenticConversationEvent? {
        if key == .tab {
            focus.replace(.transcript)
            return nil
        }

        if key == .escape {
            if snapshot.voiceState == .recording {
                focus.replace(.composer)
                return .voiceCancelRequested
            }

            focus.replace(.composer)
            return nil
        }

        guard pendingSubmission == nil else {
            return nil
        }

        let action = voiceActionControl

        guard action.handle(
            key
        ) == .accepted else {
            return nil
        }

        return voiceAction()
    }

    mutating func handleTranscript(_ key: TerminalKey) -> AgenticConversationEvent? {
        switch key {
        case .tab, .escape:
            focus.replace(.composer)
        case .char("j"), .down:
            moveMessage(by: 1)
        case .char("k"), .up:
            moveMessage(by: -1)
        case .char("m"):
            guard pendingSubmission == nil else {
                return nil
            }
            guard !snapshot.models.isEmpty else {
                return .feedbackRequested("No models available.")
            }
            settings.openModel(
                snapshot
            )
            focus.push(
                .settings
            )
        case .char("s"):
            guard pendingSubmission == nil else {
                return nil
            }
            settings.openRoot(
                snapshot
            )
            focus.push(
                .settings
            )
        case .enter:
            return openCurrentMessage()
        default:
            break
        }
        return nil
    }

    mutating func handleAttachment(_ key: TerminalKey) -> AgenticConversationEvent? {
        switch key {
        case .char("q"), .escape:
            let messageID = currentMessage?.id ?? ""
            _ = focus.pop()
            attachmentDocument.moveToStart()
            return .attachmentClosed(messageID: messageID)
        case .char("h"), .left:
            moveAttachment(by: -1)
        case .char("l"), .right:
            moveAttachment(by: 1)
        case .char("j"), .down:
            _ = attachmentDocument.scrollDown()
        case .char("k"), .up:
            _ = attachmentDocument.scrollUp()
        case .pageUp:
            _ = attachmentDocument.pageUp()
        case .pageDown:
            _ = attachmentDocument.pageDown()
        case .home:
            attachmentDocument.moveToStart()
        case .end:
            attachmentDocument.moveToEnd()
        case .enter:
            guard case .run(let runID)? = currentAttachment else {
                return nil
            }
            return openRun(runID: runID)
        default:
            break
        }
        return nil
    }

    mutating func handleSettings(
        _ key: TerminalKey
    ) -> AgenticConversationEvent? {
        guard let event = settings.handle(
            key,
            snapshot: &snapshot
        ) else {
            return nil
        }

        switch event {
        case .closeRequested:
            _ = focus.pop()
            return nil

        case .conversation(let event):
            return event
        }
    }

    mutating func handleRun(_ key: TerminalKey) -> AgenticConversationEvent? {
        guard var hostConsole else {
            focus.reset(to: .transcript)
            return .feedbackRequested("Run is no longer available.")
        }

        if key == .char("q"),
           hostConsole.focus.current == .base,
           hostConsole.console.focus.current != .inspector
        {
            let runID = openedRunID ?? ""
            openedRunID = nil
            self.hostConsole = nil
            _ = focus.pop()
            return .runClosed(runID: runID)
        }

        let event = hostConsole.handle(key)
        self.hostConsole = hostConsole
        guard event?.requestsExit == true else {
            return event.map { .run($0) }
        }

        let runID = openedRunID ?? ""
        openedRunID = nil
        self.hostConsole = nil
        _ = focus.pop()
        return .runClosed(runID: runID)
    }

    mutating func handleRunReview(
        _ key: TerminalKey
    ) -> AgenticConversationEvent? {
        guard var runReview else {
            focus.reset(
                to: .transcript
            )
            return .feedbackRequested(
                "Run review is no longer available."
            )
        }

        let event = runReview.handle(
            key
        )
        self.runReview = runReview

        guard let event else {
            return nil
        }

        switch event {
        case .closed:
            self.runReview = nil
            _ = focus.pop()
            return nil

        case .openRunConsole(let runID):
            self.runReview = nil
            _ = focus.pop()
            return openRun(
                runID: runID
            )

        case .actionRequested(
            let interruptionID,
            let runID,
            let stepID,
            let action
        ):
            self.runReview = nil
            _ = focus.pop()

            return .run(
                .actionRequested(
                    interruptionID: interruptionID,
                    runID: runID,
                    stepID: stepID,
                    action: action
                )
            )
        }
    }

    mutating func openCurrentMessage() -> AgenticConversationEvent? {
        guard let currentMessage else {
            return .feedbackRequested("No message selected.")
        }

        if currentMessage.attachments.count == 1,
           case .run(let runID) = currentMessage.attachments[0]
        {
            if let review = AgenticConversationRunReviewControl(
                snapshot: snapshot.hostConsole,
                runID: runID
            ) {
                runReview = review
                focus.push(
                    .runReview
                )
                return nil
            }

            return openRun(
                runID: runID
            )
        }

        return openCurrentAttachment()
    }

    mutating func openCurrentAttachment() -> AgenticConversationEvent? {
        guard let currentMessage else {
            return .feedbackRequested("No message selected.")
        }
        guard let first = currentMessage.attachments.first else {
            return .feedbackRequested("Selected message has no attached content or run.")
        }
        attachmentIndex = 0
        attachmentDocument.moveToStart()
        focus.push(.attachment)
        return .attachmentOpened(
            messageID: currentMessage.id,
            attachmentID: first.id
        )
    }

    mutating func openRun(runID: String) -> AgenticConversationEvent? {
        guard snapshot.hostConsole.runs.contains(where: { $0.id == runID }) else {
            return .feedbackRequested("Run '\(runID)' is unavailable.")
        }
        openedRunID = runID
        hostConsole = AgenticHostConsoleWorkflowControl(
            snapshot: snapshot.hostConsole,
            currentRunID: runID
        )
        focus.push(.run)
        return .runOpened(
            messageID: currentMessage?.id ?? "",
            runID: runID
        )
    }

    mutating func moveMessage(by offset: Int) {
        guard !snapshot.messages.isEmpty else {
            selectedMessageID = nil
            transcriptSelectionFollowsEnd = true
            pendingTranscriptReveal = nil
            return
        }
        let current = selectedMessageID.flatMap { id in
            snapshot.messages.firstIndex { $0.id == id }
        } ?? snapshot.messages.count - 1
        let next = min(snapshot.messages.count - 1, max(0, current + offset))
        selectedMessageID = snapshot.messages[next].id
        transcriptSelectionFollowsEnd = next == snapshot.messages.count - 1

        if offset < 0 {
            pendingTranscriptReveal = .start
        } else if offset > 0 {
            pendingTranscriptReveal = .end
        }
    }

    mutating func moveAttachment(by offset: Int) {
        guard let currentMessage, !currentMessage.attachments.isEmpty else {
            attachmentIndex = 0
            return
        }
        attachmentIndex = min(
            currentMessage.attachments.count - 1,
            max(0, attachmentIndex + offset)
        )
        attachmentDocument.moveToStart()
    }
}

private extension AgenticConversationControl {
    mutating func renderConversation(
        into frame: inout TerminalFrame,
        in region: TerminalRegion
    ) {
        let composerColumns = max(
            1,
            region.columns - 5
        )
        let composerRows = composer.compactRows(
            columns: composerColumns
        )
        let pendingRows = pendingContents.isEmpty
            ? 0
            : 1
        let controlRows = min(
            max(
                0,
                region.rows - 4
            ),
            pendingRows + composerRows
        )

        let vertical = TerminalLayout.vertical(
            in: region,
            [
                .fixed(3),
                .flex(1),
                .fixed(controlRows),
                .fixed(1),
            ]
        )
        guard vertical.count == 4 else {
            return
        }

        let modelTitle = snapshot.models.first {
            $0.id == snapshot.preferredModelProfileID
        }?.title ?? snapshot.preferredModelProfileID.rawValue
        let selectedSkills = snapshot.skills.filter {
            snapshot.selectedSkillIDs.contains(
                $0.id
            )
        }
        let skillTitle: String
        if selectedSkills.isEmpty {
            skillTitle = "no skills"
        } else if selectedSkills.count == 1 {
            skillTitle = selectedSkills[0].title
        } else {
            skillTitle = "\(selectedSkills.count) skills"
        }
        frame.write(
            [
                TerminalStyle.bold.apply(snapshot.title),
                TerminalStyle.dim.apply(
                    "\(snapshot.workspace) · \(modelTitle) · \(snapshot.selectedToolExposure.title.lowercased()) · \(skillTitle)"
                ),
                snapshot.activity.map { TerminalStyle.dim.apply($0) } ?? "",
            ],
            in: vertical[0]
        )

        let layout = transcriptLines(columns: vertical[1].columns)
        transcript.update(lines: layout.lines, visibleRows: vertical[1].rows)
        if focus.current == .transcript,
           let pendingTranscriptReveal
        {
            if let selectedMessageID,
               let rows = layout.messageRows[selectedMessageID],
               !rows.isEmpty
            {
                switch pendingTranscriptReveal {
                case .start:
                    transcript.reveal(
                        row: rows.lowerBound,
                        margin: 1
                    )

                case .end:
                    if transcriptSelectionFollowsEnd,
                       selectedMessageID == snapshot.messages.last?.id
                    {
                        transcript.moveToEnd()
                    } else {
                        transcript.reveal(
                            row: rows.upperBound - 1,
                            margin: 1
                        )
                    }
                }
            }

            self.pendingTranscriptReveal = nil
        }
        transcript.render(into: &frame, in: vertical[1])

        if pendingRows > 0 {
            let pending = pendingContents
                .map(\.summary)
                .joined(separator: " · ")
            frame.write(
                TerminalStyle.dim.apply(pending),
                in: TerminalRegion(
                    top: vertical[2].top,
                    leading: vertical[2].leading,
                    rows: 1,
                    columns: vertical[2].columns
                )
            )
        }

        let composerRow = TerminalRegion(
            top: vertical[2].top + pendingRows,
            leading: vertical[2].leading,
            rows: max(
                0,
                vertical[2].rows - pendingRows
            ),
            columns: vertical[2].columns
        )
        let composerLayout = TerminalLayout.horizontal(
            in: composerRow,
            [
                .flex(1),
                .fixed(4),
            ],
            spacing: 1
        )

        if composerLayout.count == 2 {
            composer.render(
                into: &frame,
                in: composerLayout[0],
                isFocused: focus.current == .composer
                    && pendingSubmission == nil
            )
            frame.write(
                voiceActionControl.render(
                    focused: focus.current == .voice,
                    theme: .agentic
                ),
                in: composerLayout[1]
            )
        } else {
            composer.render(
                into: &frame,
                in: composerRow,
                isFocused: focus.current == .composer
                    && pendingSubmission == nil
            )
        }

        frame.write(
            TerminalStyle.dim.apply(
                footer
            ),
            in: vertical[3]
        )
    }

    func transcriptLines(
        columns: Int
    ) -> (lines: [String], messageRows: [String: Range<Int>]) {
        let width = max(1, columns)
        let bodyWidth = max(1, width - 2)
        var lines: [String] = []
        var rows: [String: Range<Int>] = [:]
        let structuredRenderer = TerminalStructuredContent.Renderer()

        for message in snapshot.messages {
            let start = lines.count
            let selected = focus.current == .transcript
                && message.id == selectedMessageID
            var nestedInteractiveRows: Set<Int> = []
            let label = (selected ? "> " : "") + message.role.rawValue
            lines.append(
                selected
                    ? TerminalStyle(.inverse).apply(
                        TerminalDisplay.fitted(label, columns: width)
                    )
                    : TerminalStyle.bold.apply(label)
            )
            if message.role == .assistant {
                let structured = MarkdownStructuredContentParser.parse(
                    message.body
                )
                lines += structuredRenderer.rows(
                    structured,
                    columns: bodyWidth
                ).map {
                    "  " + $0
                }
            } else {
                lines += TerminalTextWrap.lines(
                    message.body,
                    width: bodyWidth
                ).map {
                    "  " + $0
                }
            }
            for attachment in message.attachments {
                switch attachment {
                case .content(let content):
                    lines.append(
                        TerminalStyle.dim.apply(
                            "  [" + content.summary + "]"
                        )
                    )

                case .run(let runID):
                    guard let run = snapshot.hostConsole.runs.first(
                        where: { run in
                            run.id == runID
                        }
                    ) else {
                        lines.append(
                            TerminalStyle.dim.apply(
                                "  ["
                                    + attachment.summary(
                                        in: snapshot.hostConsole
                                    )
                                    + "]"
                            )
                        )
                        continue
                    }

                    let presentation =
                        AgenticConversationRunCardPresentation.project(
                            run: run,
                            hostConsole: snapshot.hostConsole
                        )
                    let block = TerminalInteractiveBlock(
                        title: presentation.title,
                        body: presentation.body,
                        hint: presentation.hint,
                        state: TerminalInteractiveBlock.resolvedState(
                            isFocused: selected
                        ),
                        style: runCardStyle(
                            for: presentation.tone
                        )
                    )
                    let blockStart = lines.count

                    lines.append(
                        contentsOf: block.render(
                            width: bodyWidth
                        ).map { line in
                            "  " + line
                        }
                    )
                    nestedInteractiveRows.formUnion(
                        blockStart..<lines.count
                    )
                }
            }
            if selected {
                let selectionStyle = TerminalStyle(
                    foreground: .hex(
                        "#d0d0d0"
                    ),
                    background: .hex(
                        "#3a3d43"
                    )
                )

                for index in start..<lines.count where !nestedInteractiveRows.contains(index) {
                    lines[index] = selectionStyle.apply(
                        TerminalDisplay.fitted(
                            stripANSI(
                                lines[index]
                            ),
                            columns: width
                        )
                    )
                }
            }

            rows[message.id] = start..<lines.count
            lines.append("")
        }

        if lines.isEmpty {
            lines = [TerminalStyle.dim.apply("No messages yet.")]
        }
        return (lines, rows)
    }

    func runCardStyle(
        for tone: AgenticConversationRunCardTone
    ) -> TerminalInteractiveBlockStyle {
        let theme = TerminalTheme.agentic
        let accent: TerminalStyle

        switch tone {
        case .neutral:
            accent = .dim

        case .active:
            accent = theme.title

        case .warning:
            accent = theme.warning

        case .success:
            accent = theme.success

        case .failure:
            accent = theme.failure
        }

        let emphasized = accent.merging(
            .bold
        )

        return TerminalInteractiveBlockStyle(
            border: accent,
            focusedBorder: emphasized,
            hoveredBorder: emphasized,
            activeBorder: emphasized,
            disabledBorder: .dim,
            title: emphasized,
            body: .none,
            hint: .dim,
            disabledContent: .dim
        )
    }

    mutating func renderAttachment(
        into frame: inout TerminalFrame,
        in region: TerminalRegion
    ) {
        guard let message = currentMessage, let attachment = currentAttachment else {
            return
        }
        let overlay = AgenticHostConsoleInspectionSurface.overlay(in: region)
        let content = overlay.render(
            into: &frame,
            in: region,
            title: message.role.rawValue
                + " · "
                + attachment.title(in: snapshot.hostConsole)
        )
        guard !content.isEmpty else {
            return
        }

        let body = TerminalRegion(
            top: content.top,
            leading: content.leading,
            rows: max(0, content.rows - 1),
            columns: content.columns
        )
        switch attachment {
        case .content(let pasted):
            attachmentDocument.update(
                text: pasted.body,
                columns: body.columns,
                visibleRows: body.rows,
                wrapping: .display
            )
        case .run(let runID):
            let run = snapshot.hostConsole.runs.first { $0.id == runID }
            attachmentDocument.update(
                text: [
                    "run      \(runID)",
                    "state    \(run?.state.rawValue ?? "unavailable")",
                    "summary  \(run?.summary ?? "No run summary available.")",
                    "",
                    "Press Enter to inspect and control this run.",
                ].joined(separator: "\n"),
                columns: body.columns,
                visibleRows: body.rows,
                wrapping: .word
            )
        }
        attachmentDocument.render(into: &frame, in: body, zIndex: .overlay)

        let position = min(message.attachments.count, attachmentIndex + 1)
        let enterHint: String
        if case .run = attachment {
            enterHint = "  enter run"
        } else {
            enterHint = ""
        }
        frame.write(
            TerminalStyle.dim.apply(
                "\(position)/\(message.attachments.count)  h/l sibling  j/k scroll"
                    + enterHint
                    + "  q back"
            ),
            in: TerminalRegion(
                top: content.bottom - 1,
                leading: content.leading,
                rows: 1,
                columns: content.columns
            ),
            zIndex: .overlay
        )
    }

    func renderVoice(
        into frame: inout TerminalFrame,
        in region: TerminalRegion
    ) {
        let content: [String]

        switch snapshot.voiceState {
        case .idle:
            return

        case .recording:
            let elapsed = voiceElapsed
            let meter = voiceMeter.render(
                width: 28
            )
            content = [
                "●  recording  \(elapsed)",
                "",
                meter.isEmpty
                    ? "▁"
                    : meter,
                "",
                TerminalStyle.dim.apply(
                    "enter stop  esc cancel"
                ),
            ]

        case .transcribing:
            content = [
                "transcribing...",
                "",
                TerminalStyle.dim.apply(
                    "voice input is being converted to text"
                ),
            ]

        case .failed(let message):
            content = [
                "voice input failed",
                "",
                message,
                "",
                TerminalStyle.dim.apply(
                    "enter retry  esc close"
                ),
            ]
        }

        let overlay = TerminalOverlay(
            placement: .centered(
                columns: 48,
                rows: max(
                    8,
                    content.count + 2
                )
            ),
            outerInsets: TerminalInsets(
                vertical: 1,
                horizontal: 2
            ),
            contentInsets: TerminalInsets(
                vertical: 1,
                horizontal: 2
            )
        )
        let region = overlay.render(
            into: &frame,
            in: region,
            title: "voice"
        )

        frame.write(
            content,
            in: region,
            zIndex: .overlay
        )
    }

    var footer: String {
        if pendingSubmission != nil {
            switch focus.current {
            case .composer:
                return "response pending  tab voice  esc/ctrl-c transcript"
            case .voice:
                return "response pending  tab transcript  esc composer"
            case .transcript:
                return "j/k message  enter inspect  tab composer  response pending"
            case .attachment,
                 .settings,
                 .runReview,
                 .run:
                break
            }
        }

        switch focus.current {
        case .composer:
            return "enter newline  ctrl-enter send  ctrl-c normal  :w save  :q quit  ctrl-f expand"
        case .voice:
            return "enter voice  tab transcript  esc composer  ctrl-v voice"
        case .transcript:
            return "j/k message  enter inspect  m model  s settings  tab composer  ctrl-c composer"
                + voiceFooter
        case .attachment:
            return "h/l sibling  j/k scroll  enter run  q back"
        case .settings:
            return "conversation settings"
        case .runReview:
            return runReview?.footer
                ?? "q conversation"
        case .run:
            return "q conversation"
        }
    }
}


private extension AgenticConversationControl {
    var voiceActionControl: TerminalActionControl {
        TerminalActionControl(
            symbol: "●",
            isEnabled: pendingSubmission == nil,
            isActive: snapshot.voiceState == .recording
        )
    }

    var voiceElapsed: String {
        let seconds = Int(
            snapshot.voiceStatus?.elapsedSeconds
                ?? 0
        )
        let minutes = seconds / 60
        let remainder = seconds % 60

        return String(
            format: "%02d:%02d",
            minutes,
            remainder
        )
    }

    mutating func voiceAction() -> AgenticConversationEvent? {
        switch snapshot.voiceState {
        case .recording:
            return .voiceStopRequested

        case .transcribing:
            return .feedbackRequested(
                "Voice input is transcribing."
            )

        case .idle,
             .failed(_):
            switch snapshot.voiceAvailability {
            case .available:
                focus.replace(
                    .voice
                )
                return .voiceStartRequested

            case .unconfigured:
                return .feedbackRequested(
                    "Voice input unavailable — no transcription provider configured."
                )

            case .unavailable(let reason):
                return .feedbackRequested(
                    "Voice input unavailable — \(reason)"
                )
            }
        }
    }

    var voiceFooter: String {
        switch snapshot.voiceState {
        case .recording:
            return "  ctrl-v stop  esc cancel"

        case .transcribing:
            return "  transcribing..."

        case .failed(_):
            return "  ctrl-v retry"

        case .idle:
            switch snapshot.voiceAvailability {
            case .available:
                return "  ctrl-v mic"

            case .unconfigured,
                 .unavailable(_):
                return "  ctrl-v mic unavailable"
            }
        }
    }
}