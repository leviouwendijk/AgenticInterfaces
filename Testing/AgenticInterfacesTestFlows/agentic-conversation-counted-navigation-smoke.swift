import AgenticInterfaces
import Terminal

enum AgenticConversationCountedNavigationSmoke {
    enum Failure: Error {
        case countedMessages, pendingFooter, ends, position, countLeak, escape
        case attachmentRows, attachmentEnds, focusReset
        case settingsCounts, settingsPendingFooter
    }

    static func run() throws {
        try runConversation()
        try runSettings()
    }

    /// The settings tree (also the `m` model menu) takes the same counts.
    private static func runSettings() throws {
        var control = AgenticConversationControl(snapshot: AgenticConversationSmoke.fixture())
        _ = control.handle(.escape)
        _ = control.handle(.escape)
        _ = control.handle(.char("s"))
        _ = control.handle(.char("4"))
        var frame = TerminalFrame(rows: 28, columns: 100)
        control.render(into: &frame, in: TerminalRegion(rows: 28, columns: 100))
        guard frame.spans.contains(where: { $0.content.contains("4") && !$0.content.contains("j/k move") }) else {
            throw Failure.settingsPendingFooter
        }
        _ = control.handle(.char("j"))
        _ = control.handle(.enter) // Capabilities opens
        _ = control.handle(.char("j")) // Core
        _ = control.handle(.enter) // Core opens
        _ = control.handle(.char("2"))
        _ = control.handle(.char("j")) // Tools, then inspect_workspace
        guard control.handle(.enter) == .capabilitySelectionChanged(
            available: .init(tools: ["inspect_workspace"]),
            visible: .none
        ) else { throw Failure.settingsCounts }

        _ = control.handle(.char("g"))
        _ = control.handle(.char("g"))
        _ = control.handle(.enter) // Model opens
        _ = control.handle(.char("2"))
        _ = control.handle(.char("j")) // apple-default, then mock-model
        guard control.handle(.enter) == .modelPreferenceChanged("mock-model") else {
            throw Failure.settingsCounts
        }
    }

    private static func runConversation() throws {
        var snapshot = AgenticConversationSmoke.fixture()
        snapshot.messages = (0..<30).map { index in
            .init(id: "m\(index)", role: index.isMultiple(of: 2) ? .user : .assistant, body: "message \(index)")
        }
        var control = AgenticConversationControl(snapshot: snapshot)
        func render(_ control: inout AgenticConversationControl) -> TerminalFrame {
            var frame = TerminalFrame(rows: 20, columns: 200)
            control.render(into: &frame, in: TerminalRegion(rows: 20, columns: 200))
            return frame
        }
        _ = render(&control)
        _ = control.handle(.escape)
        _ = control.handle(.tab)
        guard control.focus.current == .transcript, control.currentMessage?.id == "m29" else {
            throw Failure.countedMessages
        }

        _ = control.handle(.char("1"))
        _ = control.handle(.char("2"))
        guard render(&control).spans.contains(where: { $0.content.contains("12") && $0.content.contains("msg") }) else {
            throw Failure.pendingFooter
        }
        _ = control.handle(.char("k"))
        guard control.currentMessage?.id == "m17" else { throw Failure.countedMessages }
        _ = control.handle(.char("3"))
        _ = control.handle(.char("j"))
        guard control.currentMessage?.id == "m20" else { throw Failure.countedMessages }

        _ = control.handle(.char("g"))
        _ = control.handle(.char("g"))
        guard control.currentMessage?.id == "m0" else { throw Failure.ends }
        _ = control.handle(.char("G"))
        guard control.currentMessage?.id == "m29" else { throw Failure.ends }
        _ = control.handle(.char("9"))
        _ = control.handle(.char("9"))
        _ = control.handle(.char("9"))
        _ = control.handle(.char("k"))
        guard control.currentMessage?.id == "m0" else { throw Failure.ends }

        _ = control.handle(.char("5"))
        _ = control.handle(.char("G"))
        guard control.currentMessage?.id == "m4" else { throw Failure.position }

        // A count never multiplies a view action, and does not survive it.
        _ = control.handle(.char("4"))
        guard case .copyRequested(_, "message")? = control.handle(.char("y")) else { throw Failure.countLeak }
        _ = control.handle(.char("j"))
        guard control.currentMessage?.id == "m5" else { throw Failure.countLeak }

        // Escape cancels a pending count without leaving the transcript.
        _ = control.handle(.char("7"))
        _ = control.handle(.escape)
        guard control.focus.current == .transcript else { throw Failure.escape }
        _ = control.handle(.char("j"))
        guard control.currentMessage?.id == "m6" else { throw Failure.escape }

        let body = (0..<100).map { "row \($0)" }.joined(separator: "\n")
        snapshot.messages[6].attachments = [
            .content(.init(id: "a", title: "A", summary: "a", body: body)),
            .content(.init(id: "b", title: "B", summary: "b", body: body)),
        ]
        control.update(snapshot)
        _ = control.handle(.char("2"))
        _ = control.handle(.enter)
        guard control.focus.current == .attachment else { throw Failure.focusReset }
        _ = render(&control)
        // The 2 typed in the transcript must not carry into the attachment.
        _ = control.handle(.char("j"))
        guard case .copyRequested(let one, _)? = control.handle(.char("Y")),
              one.hasPrefix("row 1\n") else { throw Failure.focusReset }

        _ = control.handle(.char("2"))
        _ = control.handle(.char("0"))
        _ = control.handle(.char("j"))
        guard case .copyRequested(let twentyOne, _)? = control.handle(.char("Y")),
              twentyOne.hasPrefix("row 21\n") else { throw Failure.attachmentRows }

        _ = control.handle(.char("G"))
        guard case .copyRequested(let end, _)? = control.handle(.char("Y")),
              end.hasSuffix("row 99") else { throw Failure.attachmentEnds }
        _ = control.handle(.char("g"))
        _ = control.handle(.char("g"))
        guard case .copyRequested(let start, _)? = control.handle(.char("Y")),
              start.hasPrefix("row 0\n") else { throw Failure.attachmentEnds }
    }
}
