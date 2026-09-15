import AgenticInterfaces
import Terminal

enum AgenticConversationPinnedContentSmoke {
    enum Failure: Error {
        case blockerDidNotOpenPins
        case pinListPresentationChanged
        case pinInspectionChanged
        case exclusionDidNotRecoverProgram
        case removalDidNotRecoverProgram
        case transcriptPinEntryChanged
    }

    static func run() throws {
        try runExclusionRecovery()
        try runRemovalRecovery()
        try runTranscriptEntry()
    }

    private static func runExclusionRecovery() throws {
        var control = AgenticConversationControl(
            snapshot: fixture()
        )
        let command =
            "/program fixture.conversation_program {\"value\":\"hello\"}"

        _ = control.applyTranscription(
            .init(
                text: command
            )
        )
        _ = control.applyTranscription(
            .init(
                text: "recoverable pinned context"
            ),
            disposition: .pinned
        )

        guard control.pinnedContents.count == 1 else {
            throw Failure.blockerDidNotOpenPins
        }

        let blocked = control.handle(
            submitStroke
        )

        guard blocked == .feedbackRequested(
            "Program commands cannot include pinned content. Exclude or remove the included pins to continue."
        ),
              control.focus.current == .pinnedContent,
              control.draftText == command
        else {
            throw Failure.blockerDidNotOpenPins
        }

        let list = rendered(
            &control
        )

        guard list.contains("Pinned content"),
              list.contains("[x]"),
              !list.contains("recoverable pinned context")
        else {
            throw Failure.pinListPresentationChanged
        }

        _ = control.handle(
            .enter
        )

        let inspected = rendered(
            &control
        )

        guard inspected.contains("recoverable pinned context"),
              inspected.contains("included")
        else {
            throw Failure.pinInspectionChanged
        }

        _ = control.handle(
            .char("q")
        )
        _ = control.handle(
            .space
        )

        let excluded = rendered(
            &control
        )

        guard excluded.contains("[ ]") else {
            throw Failure.pinListPresentationChanged
        }

        _ = control.handle(
            .char("q")
        )

        let recovered = control.handle(
            submitStroke
        )

        guard case .programInvocationRequested(
            let invocation,
            let submission
        )? = recovered,
              invocation.program.rawValue == "fixture.conversation_program",
              submission.contents.isEmpty,
              control.draftText.isEmpty,
              control.pinnedContents.count == 1,
              control.pinnedContents[0].body == "recoverable pinned context"
        else {
            throw Failure.exclusionDidNotRecoverProgram
        }
    }

    private static func runRemovalRecovery() throws {
        var control = AgenticConversationControl(
            snapshot: fixture()
        )
        let command =
            "/program fixture.conversation_program {\"value\":\"remove\"}"

        _ = control.applyTranscription(
            .init(
                text: command
            )
        )
        _ = control.applyTranscription(
            .init(
                text: "remove me"
            ),
            disposition: .pinned
        )
        _ = control.handle(
            submitStroke
        )

        guard control.focus.current == .pinnedContent else {
            throw Failure.blockerDidNotOpenPins
        }

        _ = control.handle(
            .char("d")
        )

        guard control.pinnedContents.isEmpty,
              control.focus.current == .composer,
              control.draftText == command
        else {
            throw Failure.removalDidNotRecoverProgram
        }

        let recovered = control.handle(
            submitStroke
        )

        guard case .programInvocationRequested(
            _,
            let submission
        )? = recovered,
              submission.contents.isEmpty
        else {
            throw Failure.removalDidNotRecoverProgram
        }
    }

    private static func runTranscriptEntry() throws {
        var control = AgenticConversationControl(
            snapshot: fixture()
        )

        _ = control.applyTranscription(
            .init(
                text: "transcript pin"
            ),
            disposition: .pinned
        )
        _ = control.handle(
            .escape
        )
        _ = control.handle(
            .escape
        )

        guard control.focus.current == .transcript else {
            throw Failure.transcriptPinEntryChanged
        }

        _ = control.handle(
            .char("p")
        )

        guard control.focus.current == .pinnedContent else {
            throw Failure.transcriptPinEntryChanged
        }
    }

    private static var submitStroke: TerminalKeyStroke {
        TerminalKeyStroke(
            key: .enter,
            modifiers: .control
        )
    }

    private static func rendered(
        _ control: inout AgenticConversationControl
    ) -> String {
        var frame = TerminalFrame(
            rows: 24,
            columns: 80
        )

        control.render(
            into: &frame,
            in: TerminalRegion(
                rows: 24,
                columns: 80
            )
        )

        return frame.resolved().spans
            .map(\.content)
            .joined(separator: "\n")
    }

    private static func fixture() -> AgenticConversationSnapshot {
        AgenticConversationSnapshot(
            workspace: "/tmp/PinnedConversation",
            models: [
                AgenticConversationModelPresentation(
                    id: "pin-model",
                    title: "Pin model",
                    detail: "recoverable pin fixture"
                ),
            ],
            programs: [
                .init(
                    identifier: "fixture.conversation_program",
                    title: "Conversation Program",
                    summary: "Conversation Program command fixture."
                ),
            ],
            preferredModelProfileID: "pin-model"
        )
    }
}
