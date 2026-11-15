import Foundation
import Swim
import SwimIO
import SwimTerminal
import Terminal

private enum AgenticConversationComposerKeyAction:
    Sendable
{
    case submit
    case showWork
}

private enum AgenticConversationComposerQuitChoice:
    Sendable,
    Hashable
{
    case cancel
    case quit

    var title: String {
        switch self {
        case .cancel:
            return "Cancel"

        case .quit:
            return "Archive"
        }
    }
}

private struct AgenticConversationComposerQuitItem:
    Sendable
{
    var id: AgenticConversationComposerQuitChoice

    var title: String {
        id.title
    }
}

enum AgenticConversationComposerEvent:
    Sendable
{
    case submitRequested
    case focusTranscriptRequested
    case archiveRequested
    case showWorkRequested
    /// An ex command the editor does not know but the host does.
    case hostCommandRequested(String)
}

struct AgenticConversationComposerControl:
    Sendable
{
    private var surface: SwimTerminalSurface
    private let inputBufferStore: SwimBufferStore
    private let inputBufferID: UUID
    private var keyMap: TerminalKeyMap<AgenticConversationComposerKeyAction>
    private var keySequences: SwimKeySequenceMap<AgenticConversationComposerKeyAction>
    private var quitConfirmation: TerminalListControl<
        AgenticConversationComposerQuitItem,
        AgenticConversationComposerQuitChoice
    >
    private(set) var isQuitConfirmationPresented: Bool
    /// Ex command names, without `:`, forwarded to the host with their
    /// arguments instead of rejected as unknown editor commands.
    var hostCommands: Set<String> = []
    /// Completes the command line as it is typed; the host supplies it.
    var commandCompleter: AgenticCommandCompleter?
    private var completion: AgenticCommandCompletion?
    private var completionIndex: Int?
    // The command line's row, from the last render; the list sits above.
    private var commandLineRow: TerminalRegion?

    init(keyConfiguration: AgenticConversationKeyConfiguration = .init()) {
        var keyMap = TerminalKeyMap<
            AgenticConversationComposerKeyAction
        >()
        keyMap.remap(
            .control("C"),
            to: .escape
        )
        keyMap.bindAction(
            TerminalKeyStroke(
                key: .enter,
                modifiers: .control
            ),
            to: .submit
        )

        let editorPresentation = SwimTerminalPresentation(
            lineNumbers: TerminalLineNumberPresentation(
                mode: .hybrid
            ),
            indentationGuides: TerminalIndentationGuideOptions(
                isEnabled: true,
                width: 4,
                glyph: "│"
            )
        )

        self.surface = SwimTerminalSurface(
            editor: SwimEditor(
                mode: .insert
            ),
            sizePolicy: SwimTerminalSurfaceSizePolicy(
                minimumRows: 1,
                maximumRows: 6
            ),
            compactPresentation: editorPresentation,
            expandedPresentation: editorPresentation,
            placeholder: "type a message..."
        )
        self.inputBufferStore = SwimBufferStore()
        self.inputBufferID = UUID()
        self.keyMap = keyMap
        var keySequences = SwimKeySequenceMap<AgenticConversationComposerKeyAction>(
            leader: SwimTerminalInputAdapter.input(for: keyConfiguration.leader),
            timeout: keyConfiguration.timeout
        )
        keySequences.bind([.leader, .char("p"), .char("v")], to: .showWork)
        self.keySequences = keySequences
        self.quitConfirmation = TerminalListControl(
            items: [
                AgenticConversationComposerQuitItem(
                    id: .cancel
                ),
                AgenticConversationComposerQuitItem(
                    id: .quit
                ),
            ],
            currentID: .cancel,
            id: {
                $0.id
            }
        )
        self.isQuitConfirmationPresented = false
    }

    var text: String {
        surface.text
    }

    mutating func replace(
        with text: String
    ) {
        surface.replace(
            with: text
        )
        surface.setMode(
            .insert
        )
        surface.setCommandStatus(
            nil
        )
        isQuitConfirmationPresented = false
    }

    var isExpanded: Bool {
        surface.surfacePresentation == .expanded
    }

    func compactRows(
        columns: Int
    ) -> Int {
        surface.compactRows(
            columns: columns
        )
    }

    mutating func insertPaste(
        _ text: String
    ) {
        _ = surface.handle(
            TerminalInputEvent.paste(
                text
            )
        )
    }

    mutating func clearAfterSubmission() {
        surface.clear()
        surface.setMode(
            .insert
        )
        surface.setSurfacePresentation(
            .compact
        )
        surface.setCommandStatus(
            nil
        )
        isQuitConfirmationPresented = false
    }

    mutating func handle(
        _ keyStroke: TerminalKeyStroke
    ) -> AgenticConversationComposerEvent? {
        let key: TerminalKey

        switch keyMap.resolveOrFallback(
            keyStroke
        ) {
        case .key(let resolvedKey):
            key = resolvedKey

        case .action(.submit):
            return .submitRequested

        case .action(.showWork):
            return .showWorkRequested

        case .consumed:
            return nil
        }

        if isQuitConfirmationPresented {
            return handleQuitConfirmation(
                key
            )
        }

        if !surface.commandLine.isActive, surface.mode == .normal {
            let resolved = keySequences.handle(
                SwimTerminalInputAdapter.input(for: key),
                mode: surface.mode
            )
            var replayEvent: AgenticConversationComposerEvent?
            for replay in resolved.replay {
                replayEvent = handleEditorKey(
                    SwimTerminalInputAdapter.key(for: replay)
                ) ?? replayEvent
            }
            if let action = resolved.action {
                switch action {
                case .showWork:
                    return .showWorkRequested
                case .submit:
                    return .submitRequested
                }
            }
            if resolved.isPending { return replayEvent }
            return replayEvent
        }
        _ = keySequences.reset()
        return handleEditorKey(key)
    }

    private mutating func handleEditorKey(
        _ key: TerminalKey
    ) -> AgenticConversationComposerEvent? {
        if surface.commandLine.isActive,
           let event = handleCompletionKey(key)
        {
            return event
        }
        defer { refreshCompletion() }
        if key == .control("F"),
           !surface.commandLine.isActive
        {
            surface.toggleSurfacePresentation()
            return nil
        }

        if key == .tab,
           !surface.commandLine.isActive,
           !isExpanded,
           surface.mode != .insert,
           surface.mode != .replace
        {
            return .focusTranscriptRequested
        }

        switch surface.handle(
            key
        ) {
        case .commandRequested(let command)?:
            switch command {
            case .write:
                do {
                    let record = SwimStoredBufferRecord(
                        id: inputBufferID,
                        label: "agentic conversation composer",
                        content: surface.text,
                        cursorOffset: surface.editor.buffer.cursor.offset
                    )
                    _ = try inputBufferStore.store(
                        record
                    )
                    let destination = inputBufferStore.layout.bufferRecordURL(
                        for: inputBufferID
                    )
                    surface.setCommandStatus(
                        "\"\(destination.lastPathComponent)\" written"
                    )
                } catch {
                    surface.setCommandStatus(
                        "E212: Can't open file for writing: \(error)"
                    )
                }

            case .quit:
                _ = quitConfirmation.select(id: .cancel)
                isQuitConfirmationPresented = true

            case .explore:
                return .showWorkRequested
            }

        case .cancelRequested?:
            if !isExpanded {
                return .focusTranscriptRequested
            }

        case .invalidCommand(let command)?
            where hostCommands.contains(
                command.split(separator: " ", maxSplits: 1).first.map(String.init) ?? command
            ):
            surface.setCommandStatus(":" + command)
            return .hostCommandRequested(command)

        case .changed?,
             .copyRequested(_)?,
             .invalidCommand(_)?,
             .rejected(_)?,
             nil:
            break
        }

        return nil
    }

    mutating func render(
        into frame: inout TerminalFrame,
        in region: TerminalRegion,
        isFocused: Bool
    ) {
        let presentation = surface.surfacePresentation
        surface.setSurfacePresentation(
            .compact
        )
        surface.render(
            into: &frame,
            in: region,
            isFocused: isFocused
                && !isQuitConfirmationPresented
        )
        if !isExpanded {
            commandLineRow = Self.lastRow(of: region)
        }
        surface.setSurfacePresentation(
            presentation
        )
    }

    mutating func renderOverlay(
        into frame: inout TerminalFrame,
        in root: TerminalRegion
    ) {
        if isExpanded {
            renderComposerSheet(
                into: &frame,
                in: root
            )
        }

        renderCompletion(
            into: &frame
        )

        if isQuitConfirmationPresented {
            renderQuitConfirmation(
                into: &frame,
                in: root
            )
        }
    }
}

private extension AgenticConversationComposerControl {
    mutating func handleQuitConfirmation(
        _ key: TerminalKey
    ) -> AgenticConversationComposerEvent? {
        guard let event = quitConfirmation.handle(
            key
        ) else {
            return nil
        }

        switch event {
        case .currentChanged(_):
            return nil

        case .cancelRequested:
            isQuitConfirmationPresented = false
            return nil

        case .accepted(let choice):
            switch choice {
            case .cancel:
                isQuitConfirmationPresented = false
                return nil

            case .quit:
                isQuitConfirmationPresented = false
                return .archiveRequested
            }
        }
    }

    mutating func renderComposerSheet(
        into frame: inout TerminalFrame,
        in root: TerminalRegion
    ) {
        let overlay = TerminalOverlay(
            placement: .centered(
                columns: max(
                    0,
                    root.columns - 4
                ),
                rows: max(
                    0,
                    root.rows - 2
                )
            ),
            outerInsets: .zero,
            contentInsets: TerminalInsets(
                vertical: 0,
                horizontal: 1
            )
        )
        let content = overlay.render(
            into: &frame,
            in: root,
            title: "message editor"
        )

        guard !content.isEmpty else {
            return
        }

        let showsCommandLine = surface.commandLine.hasPresentation
        let surfaceRows = max(
            0,
            content.rows - (showsCommandLine ? 0 : 1)
        )

        if showsCommandLine {
            commandLineRow = Self.lastRow(of: content)
        }
        if surfaceRows > 0 {
            surface.render(
                into: &frame,
                in: TerminalRegion(
                    top: content.top,
                    leading: content.leading,
                    rows: surfaceRows,
                    columns: content.columns
                ),
                isFocused: true
            )
        }

        if !showsCommandLine,
           content.rows > 0
        {
            frame.write(
                TerminalStyle.dim.apply(
                    "mode \(surface.mode) · ctrl-enter submit · ctrl-c normal · :w save · :q archive · :Ex work · ctrl-f compact"
                ),
                in: TerminalRegion(
                    top: content.bottom - 1,
                    leading: content.leading,
                    rows: 1,
                    columns: content.columns
                )
            )
        }
    }

    func renderQuitConfirmation(
        into frame: inout TerminalFrame,
        in root: TerminalRegion
    ) {
        let overlay = TerminalOverlay(
            placement: .centered(
                columns: 44,
                rows: 9
            ),
            outerInsets: TerminalInsets(
                vertical: 1,
                horizontal: 2
            )
        )
        let content = overlay.render(
            into: &frame,
            in: root,
            title: "archive conversation?"
        )

        guard !content.isEmpty else {
            return
        }

        quitConfirmation.render(
            into: &frame,
            in: content
        ) { row in
            let value = (
                row.isCurrent
                    ? "> "
                    : "  "
            ) + row.item.title

            return row.isCurrent
                ? TerminalStyle(
                    .inverse
                ).apply(
                    TerminalDisplay.fitted(
                        value,
                        columns: content.columns
                    )
                )
                : value
        }
    }
}

private extension AgenticConversationComposerControl {
    static let completionRows = 8

    static func lastRow(
        of region: TerminalRegion
    ) -> TerminalRegion? {
        guard region.rows > 0 else { return nil }
        return TerminalRegion(
            top: region.bottom - 1,
            leading: region.leading,
            rows: 1,
            columns: region.columns
        )
    }

    /// ctrl-n / ctrl-p move through the candidates; Enter on one puts it
    /// in the command line. `.some(nil)` consumes the key.
    mutating func handleCompletionKey(
        _ key: TerminalKey
    ) -> AgenticConversationComposerEvent?? {
        guard let completion, !completion.candidates.isEmpty else { return nil }
        let count = completion.candidates.count

        switch key {
        case .control("N"), .down:
            completionIndex = completionIndex.map { ($0 + 1) % count } ?? 0
            return .some(nil)

        case .control("P"), .up:
            completionIndex = completionIndex.map { ($0 + count - 1) % count } ?? count - 1
            return .some(nil)

        case .enter:
            guard let index = completionIndex else { return nil }
            let text = surface.commandLine.text
            surface.replaceCommandLine(
                String(text.dropLast(completion.replacing))
                    + completion.candidates[index].text
            )
            // Accepted: the next Enter runs the command unless a new
            // candidate is selected.
            self.completion = nil
            refreshCompletion()
            return .some(nil)

        default:
            return nil
        }
    }

    mutating func refreshCompletion() {
        guard surface.commandLine.isActive, let commandCompleter else {
            completion = nil
            completionIndex = nil
            return
        }
        let next = commandCompleter(surface.commandLine.text)
        if next != completion {
            completion = next
            completionIndex = nil
        }
    }

    func renderCompletion(
        into frame: inout TerminalFrame
    ) {
        guard surface.commandLine.isActive,
              let completion,
              !completion.candidates.isEmpty,
              let anchor = commandLineRow
        else { return }

        let rows = min(Self.completionRows, completion.candidates.count, anchor.top)
        guard rows > 0 else { return }
        // Keep the selection in view.
        let selected = completionIndex ?? 0
        let first = min(
            max(0, selected - rows + 1),
            completion.candidates.count - rows
        )
        let width = min(
            anchor.columns,
            (completion.candidates.map { TerminalDisplay.width(of: $0.title) }.max() ?? 0) + 4
        )

        for row in 0..<rows {
            let index = first + row
            let candidate = completion.candidates[index]
            let isSelected = index == completionIndex
            let line = TerminalDisplay.clipped(
                (isSelected ? "› " : "  ") + candidate.title,
                columns: width
            )
            let padded = line + String(repeating: " ", count: max(0, width - TerminalDisplay.width(of: line)))
            frame.write(
                isSelected ? TerminalStyle.bold.apply(padded) : TerminalStyle.dim.apply(padded),
                in: TerminalRegion(
                    top: anchor.top - rows + row,
                    leading: anchor.leading,
                    rows: 1,
                    columns: width
                )
            )
        }
    }
}
