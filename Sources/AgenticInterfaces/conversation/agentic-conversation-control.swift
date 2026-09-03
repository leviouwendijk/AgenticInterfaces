import Agentic
import Foundation
import ParsersStructuredContent
import Terminal
import TerminalStructuredContent

public enum AgenticConversationFocus: Sendable, Hashable {
    case composer
    case voice
    case transcript
    case attachment
    case settings
    case run
}

public enum AgenticConversationEvent: Sendable, Hashable {
    case exitRequested
    case voiceStartRequested
    case voiceStopRequested
    case voiceCancelRequested
    case contentPinned(AgenticConversationContentPresentation)
    case submissionRequested(AgenticConversationSubmission)
    case modelSelectionChanged(AgentModelProfileIdentifier)
    case toolExposureSelectionChanged(AgenticConversationToolExposure)
    case skillSelectionChanged([AgentSkillIdentifier])
    case attachmentOpened(messageID: String, attachmentID: String)
    case attachmentClosed(messageID: String)
    case runOpened(messageID: String, runID: String)
    case runClosed(runID: String)
    case run(AgenticHostConsoleWorkflowEvent)
    case feedbackRequested(String)
}

public struct AgenticConversationControl: Sendable {
    public private(set) var snapshot: AgenticConversationSnapshot
    public private(set) var focus: TerminalFocusStack<AgenticConversationFocus>

    private var composer: TerminalTextInputControl
    private var voiceMeter: TerminalLevelMeter
    private var draftOrigin: AgenticConversationInputOrigin
    private var transcript: TerminalScrollableDocument
    private var attachmentDocument: TerminalScrollableDocument
    private var selectedMessageID: String?
    private var pendingContents: [AgenticConversationContentPresentation]
    private var nextContentOrdinal: Int
    private var attachmentIndex: Int
    private var settings: AgenticConversationSettingsControl
    private var pendingSubmission: AgenticConversationSubmission?
    private var pendingSpinner: TerminalSpinnerControl
    private var openedRunID: String?
    private var hostConsole: AgenticHostConsoleWorkflowControl?

    public init(snapshot: AgenticConversationSnapshot) {
        self.snapshot = snapshot
        self.focus = TerminalFocusStack(.composer)
        self.composer = TerminalTextInputControl(
            prompt: "> ",
            placeholder: "type a message..."
        )
        self.voiceMeter = TerminalLevelMeter(
            capacity: 32
        )
        self.draftOrigin = .typed
        self.transcript = TerminalScrollableDocument(followEnd: true)
        self.attachmentDocument = TerminalScrollableDocument()
        self.selectedMessageID = snapshot.messages.last?.id
        self.pendingContents = []
        self.nextContentOrdinal = 1
        self.attachmentIndex = 0
        self.settings = AgenticConversationSettingsControl(
            snapshot: snapshot
        )
        self.pendingSubmission = nil
        self.pendingSpinner = TerminalSpinnerControl(
            label: "invoking model"
        )
        self.openedRunID = nil
        self.hostConsole = nil
    }

    public var draftText: String {
        composer.input.text
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
        pendingSpinner.reset()
        transcript.moveToEnd()
    }

    @discardableResult
    public mutating func advancePendingTurn() -> Bool {
        guard pendingSubmission != nil else {
            return false
        }

        _ = pendingSpinner.advance()
        return true
    }

    public mutating func endPendingTurn() {
        pendingSubmission = nil
        pendingSpinner.reset()
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
        if let previousMessageID,
           snapshot.messages.contains(where: { $0.id == previousMessageID })
        {
            selectedMessageID = previousMessageID
        } else {
            selectedMessageID = snapshot.messages.last?.id
        }
        settings.update(
            snapshot
        )

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
        let text = TerminalTextBuffer(
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
            return focus.current == .composer
                && pendingSubmission == nil
                ? pin(
                    text,
                    kind: .pasted
                )
                : nil
        case .key(let key):
            return handle(key)
        }
    }

    public mutating func handle(_ key: TerminalKey) -> AgenticConversationEvent? {
        if key == .control("C") {
            return .exitRequested
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

        if key == .control("V") {
            switch focus.current {
            case .composer,
                 .voice,
                 .transcript:
                return voiceAction()

            case .attachment,
                 .settings,
                 .run:
                break
            }
        }

        switch focus.current {
        case .composer:
            return handleComposer(key)
        case .voice:
            return handleVoice(key)
        case .transcript:
            return handleTranscript(key)
        case .attachment:
            return handleAttachment(key)
        case .settings:
            return handleSettings(key)
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
        case .composer, .voice, .transcript, .run:
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
        let source = TerminalTextBuffer(text: source).text
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

    mutating func handleComposer(_ key: TerminalKey) -> AgenticConversationEvent? {
        if key == .tab {
            focus.replace(.voice)
            return nil
        }

        if key == .escape {
            focus.replace(.transcript)
            return nil
        }

        guard pendingSubmission == nil else {
            return nil
        }

        guard composer.handle(key) == .submitRequested else {
            return nil
        }

        let body = composer.input.text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !body.isEmpty || !pendingContents.isEmpty else {
            return .feedbackRequested("Message is empty.")
        }
        guard snapshot.models.contains(where: {
            $0.id == snapshot.selectedModelProfileID && $0.isAvailable
        }) else {
            return .feedbackRequested("Selected model is unavailable.")
        }

        let submission = AgenticConversationSubmission(
            body: body,
            origin: draftOrigin,
            contents: pendingContents,
            modelProfileID: snapshot.selectedModelProfileID,
            skillIDs: snapshot.selectedSkillIDs,
            toolExposure: snapshot.selectedToolExposure
        )
        composer.clear()
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
        case .char("q"):
            guard pendingSubmission == nil else {
                return nil
            }
            return .exitRequested
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
            return openCurrentAttachment()
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
            _ = attachmentDocument.handle(.motion(.down))
        case .char("k"), .up:
            _ = attachmentDocument.handle(.motion(.up))
        case .pageUp:
            _ = attachmentDocument.handle(.motion(.pageUp))
        case .pageDown:
            _ = attachmentDocument.handle(.motion(.pageDown))
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
            return
        }
        let current = selectedMessageID.flatMap { id in
            snapshot.messages.firstIndex { $0.id == id }
        } ?? snapshot.messages.count - 1
        let next = min(snapshot.messages.count - 1, max(0, current + offset))
        selectedMessageID = snapshot.messages[next].id
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
        let vertical = TerminalLayout.vertical(
            in: region,
            [.fixed(3), .flex(1), .fixed(2), .fixed(1)]
        )
        guard vertical.count == 4 else {
            return
        }

        let modelTitle = snapshot.models.first {
            $0.id == snapshot.selectedModelProfileID
        }?.title ?? snapshot.selectedModelProfileID.rawValue
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
           let selectedMessageID,
           let row = layout.messageRows[selectedMessageID]?.lowerBound
        {
            transcript.reveal(row: row, margin: 1)
        } else if focus.current == .composer {
            transcript.moveToEnd()
        }
        transcript.render(into: &frame, in: vertical[1])

        let pending = pendingContents.map(\.summary).joined(separator: " · ")
        frame.write(
            TerminalStyle.dim.apply(pending),
            in: TerminalRegion(
                top: vertical[2].top,
                leading: vertical[2].leading,
                rows: 1,
                columns: vertical[2].columns
            )
        )
        let composerRow = TerminalRegion(
            top: vertical[2].top + 1,
            leading: vertical[2].leading,
            rows: 1,
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

        frame.write(TerminalStyle.dim.apply(footer), in: vertical[3])
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
            lines += message.attachments.map {
                TerminalStyle.dim.apply(
                    "  [" + $0.summary(in: snapshot.hostConsole) + "]"
                )
            }
            rows[message.id] = start..<lines.count
            lines.append("")
        }

        if let pendingSubmission {
            lines.append(
                TerminalStyle.bold.apply(
                    AgentRole.user.rawValue
                )
            )
            lines += TerminalTextWrap.lines(
                pendingSubmission.body,
                width: bodyWidth
            ).map {
                "  " + $0
            }
            lines += pendingSubmission.contents.map {
                TerminalStyle.dim.apply(
                    "  [" + $0.summary + "]"
                )
            }
            lines.append("")

            lines.append(
                TerminalStyle.bold.apply(
                    AgentRole.assistant.rawValue
                )
            )
            lines.append(
                "  " + pendingSpinner.render()
            )
            lines.append("")
        }

        if lines.isEmpty {
            lines = [TerminalStyle.dim.apply("No messages yet.")]
        }
        return (lines, rows)
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
                return "response pending  tab voice  esc transcript  ctrl-c quit"
            case .voice:
                return "response pending  tab transcript  esc composer"
            case .transcript:
                return "j/k message  enter attachments  tab composer  response pending"
            case .attachment,
                 .settings,
                 .run:
                break
            }
        }

        switch focus.current {
        case .composer:
            return "enter send  paste pin  tab voice  esc transcript  ctrl-c quit"
                + voiceFooter
        case .voice:
            return "enter voice  tab transcript  esc composer  ctrl-v voice"
        case .transcript:
            return "j/k message  enter attachments  m model  s settings  tab composer  q quit"
                + voiceFooter
        case .attachment:
            return "h/l sibling  j/k scroll  enter run  q back"
        case .settings:
            return "conversation settings"
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