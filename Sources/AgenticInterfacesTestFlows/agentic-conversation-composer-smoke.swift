import AgenticInterfaces
import Terminal

enum AgenticConversationComposerSmoke {
    enum Failure: Error {
        case compactPresentationChanged
        case plainEnterSubmitted
        case controlEnterSubmissionChanged
        case expandedPresentationChanged
        case controlCModeChanged
        case blockVisualChanged
        case expandedQuitChanged
        case writeStatusChanged
        case invalidCommandStatusChanged
        case quitConfirmationChanged
        case quitCancellationChanged
        case quitChanged
        case tabSemanticsChanged
    }

    static func run() throws {
        try runCompactAndSubmissionProbe()
        try runExpandedCommandProbe()
        try runTabProbe()
    }

    private static func runCompactAndSubmissionProbe() throws {
        var control = AgenticConversationControl(
            snapshot: AgenticConversationSmoke.fixture()
        )

        for key in [
            TerminalKey.char("a"),
            .char("l"),
            .char("p"),
            .char("h"),
            .char("a"),
            .enter,
            .space,
            .space,
            .space,
            .space,
            .char("b"),
            .char("e"),
            .char("t"),
            .char("a"),
        ] {
            let event = control.handle(
                key
            )
            if key == .enter,
               event != nil
            {
                throw Failure.plainEnterSubmitted
            }
        }

        guard control.draftText == "alpha\n    beta" else {
            throw Failure.plainEnterSubmitted
        }

        let compact = rendered(
            control
        )
        guard compact.contains(
            "     1 alpha"
        ),
              compact.contains(
                "     2 │   beta"
              ),
              compact.contains(
                "ctrl-enter send"
              )
        else {
            throw Failure.compactPresentationChanged
        }

        guard case .submissionRequested(let submission)? =
            control.handle(
                submitStroke
            ),
              submission.body == "alpha\n    beta",
              control.draftText.isEmpty
        else {
            throw Failure.controlEnterSubmissionChanged
        }
    }

    private static func runExpandedCommandProbe() throws {
        var control = AgenticConversationControl(
            snapshot: AgenticConversationSmoke.fixture()
        )

        for key in [
            TerminalKey.char("a"),
            .char("l"),
            .char("p"),
            .char("h"),
            .char("a"),
            .enter,
            .space,
            .space,
            .space,
            .space,
            .char("b"),
            .char("e"),
            .char("t"),
            .char("a"),
        ] {
            _ = control.handle(
                key
            )
        }

        let draft = control.draftText

        _ = control.handle(
            .control("F")
        )

        let expanded = rendered(
            control
        )
        guard expanded.contains(
            "message editor"
        ),
              expanded.contains(
                "mode insert"
              ),
              expanded.contains(
                "ctrl-enter submit"
              ),
              expanded.contains(
                ":w save"
              ),
              expanded.contains(
                ":q compact"
              ),
              expanded.contains(
                "     1 alpha"
              ),
              expanded.contains(
                "     2 │   beta"
              )
        else {
            throw Failure.expandedPresentationChanged
        }

        _ = control.handle(
            .control("C")
        )

        guard rendered(
            control
        ).contains(
            "mode normal"
        ) else {
            throw Failure.controlCModeChanged
        }

        _ = control.handle(
            .control("V")
        )

        guard control.focus.current == .composer,
              rendered(
                control
              ).contains(
                "mode visual"
              )
        else {
            throw Failure.blockVisualChanged
        }

        _ = control.handle(
            .control("C")
        )

        enterCommand(
            "q",
            in: &control
        )

        guard control.draftText == draft,
              !rendered(
                control
              ).contains(
                "message editor"
              )
        else {
            throw Failure.expandedQuitChanged
        }

        enterCommand(
            "w",
            in: &control
        )

        guard rendered(
            control
        ).contains(
            "written"
        ) else {
            throw Failure.writeStatusChanged
        }

        enterCommand(
            "not-a-command",
            in: &control
        )

        guard rendered(
            control
        ).contains(
            "E492: Not an editor command: not-a-command"
        ) else {
            throw Failure.invalidCommandStatusChanged
        }

        enterCommand(
            "q",
            in: &control
        )

        guard rendered(
            control
        ).contains(
            "quit agentic conversation?"
        ) else {
            throw Failure.quitConfirmationChanged
        }

        _ = control.handle(
            .escape
        )

        guard !rendered(
            control
        ).contains(
            "quit agentic conversation?"
        ) else {
            throw Failure.quitCancellationChanged
        }

        enterCommand(
            "q",
            in: &control
        )
        _ = control.handle(
            .down
        )

        guard control.handle(
            .enter
        ) == .exitRequested else {
            throw Failure.quitChanged
        }
    }

    private static func runTabProbe() throws {
        var control = AgenticConversationControl(
            snapshot: AgenticConversationSmoke.fixture()
        )

        _ = control.handle(
            .tab
        )

        guard control.draftText == "\t",
              control.focus.current == .composer
        else {
            throw Failure.tabSemanticsChanged
        }

        _ = control.handle(
            .control("C")
        )
        _ = control.handle(
            .tab
        )

        guard control.focus.current == .voice else {
            throw Failure.tabSemanticsChanged
        }
    }

    private static var submitStroke: TerminalKeyStroke {
        TerminalKeyStroke(
            key: .enter,
            modifiers: .control
        )
    }

    private static func enterCommand(
        _ command: String,
        in control: inout AgenticConversationControl
    ) {
        _ = control.handle(
            .char(":")
        )

        for character in command {
            _ = control.handle(
                .char(
                    String(
                        character
                    )
                )
            )
        }

        _ = control.handle(
            .enter
        )
    }

    private static func rendered(
        _ value: AgenticConversationControl
    ) -> String {
        var control = value
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

        let resolved = frame.resolved()

        return (0..<resolved.rows)
            .map { row in
                stripANSI(
                    resolved.spans(
                        inRow: row
                    )
                    .sorted {
                        $0.leading < $1.leading
                    }
                    .map(\.content)
                    .joined()
                )
            }
            .joined(
                separator: "\n"
            )
    }
}
