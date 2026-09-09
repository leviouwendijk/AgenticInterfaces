import Swim
import Terminal

private enum AgenticConversationComposerKeyAction:
    Sendable
{
    case submit
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
            return "Quit"
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
    case focusVoiceRequested
    case focusTranscriptRequested
    case exitRequested
}

struct AgenticConversationComposerControl:
    Sendable
{
    private var surface: TerminalTextSurface
    private var commandLine: TerminalCommandLine
    private let inputBufferStore: TerminalInputBufferStore
    private let inputBufferID: TerminalInputBufferID
    private var keyMap: TerminalKeyMap<AgenticConversationComposerKeyAction>
    private var quitConfirmation: TerminalListControl<
        AgenticConversationComposerQuitItem,
        AgenticConversationComposerQuitChoice
    >
    private(set) var isQuitConfirmationPresented: Bool

    init() {
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

        let editorPresentation = TerminalTextEditorPresentation(
            lineNumbers: .hybrid,
            indentationGuides: TerminalIndentationGuideOptions(
                isEnabled: true,
                width: 4,
                glyph: "│"
            )
        )

        self.surface = TerminalTextSurface(
            editor: TerminalTextEditor(
                mode: .insert
            ),
            sizePolicy: TerminalTextSurfaceSizePolicy(
                minimumRows: 1,
                maximumRows: 6
            ),
            compactEditorPresentation: editorPresentation,
            expandedEditorPresentation: editorPresentation,
            placeholder: "type a message..."
        )
        self.commandLine = TerminalCommandLine()
        self.inputBufferStore = TerminalInputBufferStore()
        self.inputBufferID = TerminalInputBufferID()
        self.keyMap = keyMap
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
        commandLine.clearStatus()
        isQuitConfirmationPresented = false
    }

    var mode: Swim.Mode {
        surface.mode
    }

    var isExpanded: Bool {
        surface.presentation == .expanded
    }

    var hasCommandPresentation: Bool {
        commandLine.hasPresentation
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
            .paste(
                text
            )
        )
    }

    mutating func clearAfterSubmission() {
        surface.clear()
        surface.setMode(
            .insert
        )
        surface.setPresentation(
            .compact
        )
        commandLine.clearStatus()
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

        case .consumed:
            return nil
        }

        if isQuitConfirmationPresented {
            return handleQuitConfirmation(
                key
            )
        }

        if commandLine.isActive {
            handleCommandLine(
                key
            )
            return nil
        }

        if key == .control("F") {
            surface.togglePresentation()
            return nil
        }

        if key == .tab,
           !isExpanded,
           surface.mode != .insert,
           surface.mode != .replace
        {
            return .focusVoiceRequested
        }

        switch surface.handle(
            key
        ) {
        case .commandLineRequested?:
            commandLine.begin()

        case .cancelRequested?:
            if !isExpanded {
                return .focusTranscriptRequested
            }

        case .changed?,
             .copied(_)?,
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
        let presentation = surface.presentation
        surface.setPresentation(
            .compact
        )
        surface.render(
            into: &frame,
            in: region,
            isFocused: isFocused
                && !isQuitConfirmationPresented
        )
        surface.setPresentation(
            presentation
        )
    }

    mutating func renderCommandLine(
        into frame: inout TerminalFrame,
        in region: TerminalRegion,
        isFocused: Bool
    ) {
        commandLine.render(
            into: &frame,
            in: region,
            isFocused: isFocused
                && !isQuitConfirmationPresented
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

        if isQuitConfirmationPresented {
            renderQuitConfirmation(
                into: &frame,
                in: root
            )
        }
    }
}

private extension AgenticConversationComposerControl {
    mutating func handleCommandLine(
        _ key: TerminalKey
    ) {
        switch commandLine.handle(
            key
        ) {
        case .editing,
             .cancelled,
             .inactive:
            break

        case .command(let command):
            switch command {
            case .write:
                do {
                    let destination = try inputBufferStore.write(
                        surface.text,
                        id: inputBufferID
                    )
                    commandLine.setStatus(
                        "\"\(destination.path)\" written"
                    )
                } catch {
                    commandLine.setStatus(
                        "E212: Can't open file for writing: \(error)"
                    )
                }

            case .quit:
                if isExpanded {
                    surface.setPresentation(
                        .compact
                    )
                } else {
                    _ = quitConfirmation.select(
                        id: .cancel
                    )
                    isQuitConfirmationPresented = true
                }
            }

        case .invalid(let command):
            commandLine.setStatus(
                "E492: Not an editor command: \(command)"
            )
        }
    }

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
                return .exitRequested
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

        let editorRows = max(
            0,
            content.rows - 1
        )

        if editorRows > 0 {
            surface.render(
                into: &frame,
                in: TerminalRegion(
                    top: content.top,
                    leading: content.leading,
                    rows: editorRows,
                    columns: content.columns
                ),
                isFocused: true
            )
        }

        if content.rows > 0 {
            let commandRegion = TerminalRegion(
                top: content.bottom - 1,
                leading: content.leading,
                rows: 1,
                columns: content.columns
            )

            if commandLine.hasPresentation {
                commandLine.render(
                    into: &frame,
                    in: commandRegion,
                    isFocused: true
                )
            } else {
                frame.write(
                    TerminalStyle.dim.apply(
                        "mode \(surface.mode) · ctrl-enter submit · ctrl-c normal · :w save · :q compact · ctrl-f compact"
                    ),
                    in: commandRegion
                )
            }
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
            title: "quit agentic conversation?"
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
