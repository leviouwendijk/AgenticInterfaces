import AgenticInterfaces
import Terminal

enum AgenticConversationLab {
    static func run() throws {
        try AgenticConversationSmoke.run()

        let stream = TerminalStream.standardError
        let session = try TerminalSession(
            options: TerminalSession.Options(
                useAlternateScreen: true,
                hideCursor: true,
                useRawMode: true,
                useBracketedPaste: true,
                restoreOnInterrupt: true,
                outputStream: stream
            )
        )
        defer {
            session.restore()
        }

        let reader = TerminalKeyReader()
        var renderer = TerminalFrameRenderer(stream: stream)
        var snapshot = AgenticConversationSmoke.fixture()
        var control = AgenticConversationControl(snapshot: snapshot)
        var size = Terminal.size(for: stream)
        var nextMessageOrdinal = 1

        func render() {
            var frame = TerminalFrame(rows: size.rows, columns: size.columns)
            control.render(
                into: &frame,
                in: TerminalRegion(rows: size.rows, columns: size.columns)
            )
            renderer.render(frame)
        }
        render()

        while true {
            let events = reader.readEvents(
                timeoutMilliseconds: 100,
                maximumCount: 128
            )
            if events.isEmpty {
                let currentSize = Terminal.size(for: stream)
                if currentSize.rows != size.rows
                    || currentSize.columns != size.columns
                {
                    size = currentSize
                    render()
                }
                continue
            }

            for input in events {
                guard let event = control.handle(input) else {
                    continue
                }
                switch event {
                case .exitRequested:
                    return
                case .submissionRequested(let submission):
                    let userID = "lab-user-\(nextMessageOrdinal)"
                    let assistantID = "lab-assistant-\(nextMessageOrdinal)"
                    nextMessageOrdinal += 1
                    snapshot.messages.append(
                        AgenticConversationMessagePresentation(
                            id: userID,
                            role: .user,
                            body: submission.body,
                            attachments: submission.contents.map { .content($0) }
                        )
                    )
                    snapshot.messages.append(
                        AgenticConversationMessagePresentation(
                            id: assistantID,
                            role: .assistant,
                            body: "Model invocation and tool-loop wiring arrive in the next pass."
                        )
                    )
                    snapshot.activity = "submission captured in memory"
                    control.update(snapshot)
                case .feedbackRequested(let message):
                    snapshot.activity = message
                    control.update(snapshot)
                case .modelSelectionChanged(let id):
                    snapshot.selectedModelProfileID = id
                    snapshot.activity = "model selected"
                    control.update(snapshot)
                case .skillSelectionChanged(let ids):
                    snapshot.selectedSkillIDs = ids
                    snapshot.activity = ids.isEmpty
                        ? "full tool manifest selected"
                        : "skill tool set selected"
                    control.update(snapshot)
                case .voiceStartRequested,
                     .voiceStopRequested,
                     .voiceCancelRequested,
                     .contentPinned,
                     .attachmentOpened,
                     .attachmentClosed,
                     .runOpened,
                     .runClosed,
                     .run:
                    break
                }
            }

            size = Terminal.size(for: stream)
            render()
        }
    }
}
