import Foundation
import Swim
import SwimIO
import SwimTerminal
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
    private var surface: SwimTerminalSurface
    private let inputBufferStore: SwimBufferStore
    private let inputBufferID: UUID
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

        case .consumed:
            return nil
        }

        if isQuitConfirmationPresented {
            return handleQuitConfirmation(
                key
            )
        }

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
            return .focusVoiceRequested
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
                if isExpanded {
                    surface.setSurfacePresentation(
                        .compact
                    )
                } else {
                    _ = quitConfirmation.select(
                        id: .cancel
                    )
                    isQuitConfirmationPresented = true
                }
            }

        case .cancelRequested?:
            if !isExpanded {
                return .focusTranscriptRequested
            }

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

        let showsCommandLine = surface.commandLine.hasPresentation
        let surfaceRows = max(
            0,
            content.rows - (showsCommandLine ? 0 : 1)
        )

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
                    "mode \(surface.mode) · ctrl-enter submit · ctrl-c normal · :w save · :q compact · ctrl-f compact"
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
