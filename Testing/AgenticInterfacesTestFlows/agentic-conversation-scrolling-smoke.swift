import AgenticInterfaces
import Terminal

enum AgenticConversationScrollingSmoke {
    enum Failure: Error {
        case composerYank, wheelFocus, wheelRows, arrowRows, messageCopy, visibleCopy
        case selectionCopy, followEnd, attachmentCopy
    }

    static func run() throws {
        var snapshot = AgenticConversationSmoke.fixture()
        snapshot.messages = [
            .init(id: "first", role: .user, body: "First message"),
            .init(id: "long", role: .assistant,
                  body: (0..<30).map { "line \($0)" }.joined(separator: "\n\n")),
        ]
        var control = AgenticConversationControl(snapshot: snapshot)
        let region = TerminalRegion(rows: 14, columns: 80)
        func render(_ control: inout AgenticConversationControl) -> TerminalFrame {
            var frame = TerminalFrame(rows: 14, columns: 80)
            control.render(into: &frame, in: region)
            return frame
        }
        _ = render(&control)
        _ = control.handle(.char("h"))
        _ = control.handle(.char("i"))
        _ = control.handle(.escape)
        guard control.focus.current == .composer,
              control.handle(.char("y")) == nil,
              control.draftText == "hi" else { throw Failure.composerYank }
        _ = render(&control)

        // Wheel scroll targets the transcript while Swim retains keyboard focus.
        _ = control.handle(.mouse(.init(kind: .scrollUp, row: 5, column: 5)))
        guard control.focus.current == .composer, control.draftText == "hi" else {
            throw Failure.wheelFocus
        }
        let wheelFrame = render(&control)
        guard wheelFrame.scrolls.last?.delta == -1 else { throw Failure.wheelRows }

        _ = control.handle(.tab)
        guard control.focus.current == .transcript else { throw Failure.wheelFocus }
        _ = render(&control)
        _ = control.handle(.up)
        let arrowFrame = render(&control)
        guard arrowFrame.scrolls.last?.delta == -1,
              control.currentMessage?.id == "long" else { throw Failure.arrowRows }
        guard control.handle(.char("y")) == .copyRequested(
            text: snapshot.messages[1].body, title: "message"
        ) else { throw Failure.messageCopy }

        guard case .copyRequested(let visible, "visible transcript")? = control.handle(.char("Y")),
              visible.contains("line"), !visible.contains("\u{001B}"),
              !visible.contains(snapshot.workspace), !visible.contains("tab composer") else {
            throw Failure.visibleCopy
        }
        _ = control.handle(.home)
        _ = render(&control)
        // Body of the first message occupies row 4 with two cells of indentation.
        _ = control.handle(.mouse(.init(kind: .press, row: 4, column: 2)))
        _ = control.handle(.mouse(.init(kind: .drag, row: 4, column: 6)))
        _ = control.handle(.mouse(.init(kind: .release, row: 4, column: 6)))
        _ = render(&control)
        guard control.handle(.char("y")) == .copyRequested(text: "First", title: "selection"),
              control.handle(.control("C")) == .copyRequested(text: "First", title: "selection") else {
            throw Failure.selectionCopy
        }
        // New output never pulls a manually scrolled transcript back down.
        snapshot.messages.append(.init(id: "new", role: .assistant, body: "Newest output"))
        control.update(snapshot)
        _ = render(&control)
        guard case .copyRequested(let held, _)? = control.handle(.char("Y")),
              !held.contains("Newest output") else { throw Failure.followEnd }
        _ = control.handle(.end)
        _ = render(&control)
        guard case .copyRequested(let end, _)? = control.handle(.char("Y")),
              end.contains("Newest output"), control.currentMessage?.id == "new" else {
            throw Failure.followEnd
        }

        let attachmentBody = String(repeating: "unwrapped ", count: 12) + "\n"
            + (0..<30).map { "attachment \($0)" }.joined(separator: "\n")
        snapshot.messages[snapshot.messages.count - 1].attachments = [
            .content(.init(id: "content", title: "Viewed file", summary: "text",
                           body: attachmentBody)),
        ]
        control.update(snapshot)
        _ = control.handle(.enter)
        _ = render(&control)
        guard control.focus.current == .attachment,
              case .copyRequested(let attachment, "attachment")? = control.handle(.char("y")),
              attachment == attachmentBody,
              !attachment.contains("\u{001B}"),
              case .copyRequested(let visibleAttachment, "visible attachment")? = control.handle(.char("Y")),
              visibleAttachment.contains("attachment 0"),
              !visibleAttachment.contains("attachment 29") else { throw Failure.attachmentCopy }
    }
}
