@_spi(Testing) import AgenticInterfaces
import AgenticPresentation
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
        case exploreNavigationChanged
        case leaderNavigationChanged
        case insertLeaderTextChanged
        case completionChanged
        case queuePolicyChanged
        case pendingCancelChanged
        case unsentRestoreChanged
    }

    static func run() throws {
        try runCompactAndSubmissionProbe()
        try runExpandedCommandProbe()
        try runTabProbe()
        try runNavigationProbe()
        try runQueuePolicyProbe()
        try runPendingCancelProbe()
    }

    /// `x` on a pending message asks to cancel it; on any other message it
    /// keeps opening run actions. Unsent text returns below the draft.
    private static func runPendingCancelProbe() throws {
        var snapshot = AgenticConversationSmoke.fixture()
        snapshot.messages = [
            .init(id: "answered", role: .user, body: "first"),
            .init(id: "held", role: .user, body: "later", pending: AgenticQueuePolicy.await.pendingLabel),
        ]
        var control = AgenticConversationControl(snapshot: snapshot)
        _ = control.handle(.escape)
        _ = control.handle(.tab)
        guard control.currentMessage?.id == "held",
              rendered(control).contains("x cancel message"),
              case .pendingMessageCancelRequested(messageID: "held")? = control.handle(.char("x"))
        else { throw Failure.pendingCancelChanged }
        _ = control.handle(.char("k"))
        if case .pendingMessageCancelRequested? = control.handle(.char("x")) {
            throw Failure.pendingCancelChanged
        }

        var composer = AgenticConversationControl(snapshot: AgenticConversationSmoke.fixture())
        let unsent = AgenticConversationSubmission(
            body: "later",
            contents: [],
            preferredModelProfileID: composer.snapshot.preferredModelProfileID,
            instructionIDs: []
        )
        composer.restoreUnsent(unsent)
        guard composer.draftText == "later" else { throw Failure.unsentRestoreChanged }
        composer.restoreUnsent(unsent)
        guard composer.draftText == "later\n\nlater" else { throw Failure.unsentRestoreChanged }
    }

    /// During a run, sending follows the queue policy without a sheet.
    private static func runQueuePolicyProbe() throws {
        var control = AgenticConversationControl(snapshot: AgenticConversationSmoke.fixture())
        control.beginPendingTurn(.init(body: "first", contents: [], preferredModelProfileID: control.snapshot.preferredModelProfileID, instructionIDs: []))

        func send(_ text: String) -> AgenticConversationEvent? {
            for character in text {
                _ = control.handle(.char(String(character)))
            }
            return control.handle(submitStroke)
        }

        guard case .queuedSubmissionRequested(let queued)? = send("later"),
              queued.body == "later",
              control.draftText.isEmpty,
              !rendered(control).contains("Replace current run")
        else { throw Failure.queuePolicyChanged }

        var forced = control.snapshot
        forced.queuePolicy = .force
        control.update(forced)
        guard case .supersedingSubmissionRequested(let replacement)? = send("instead"),
              replacement.body == "instead"
        else { throw Failure.queuePolicyChanged }

        var steering = control.snapshot
        steering.queuePolicy = .next
        control.update(steering)
        guard case .steeringRequested(let steering)? = send("steer"),
              steering.body == "steer",
              control.draftText.isEmpty
        else { throw Failure.queuePolicyChanged }
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
                ":q archive"
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
              rendered(control).contains("archive conversation?")
        else { throw Failure.expandedQuitChanged }
        _ = control.handle(.escape)
        _ = control.handle(.control("F"))

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

        control.hostCommands = ["publish"]
        _ = control.handle(.char(":"))
        for character in "publish" {
            _ = control.handle(.char(String(character)))
        }
        guard control.handle(.enter) == .hostCommandRequested("publish"),
              !rendered(control).contains("E492")
        else {
            throw Failure.invalidCommandStatusChanged
        }

        control.hostCommands = ["path"]
        _ = control.handle(.char(":"))
        for character in "path add ~/notes --read" {
            _ = control.handle(.char(String(character)))
        }
        guard control.handle(.enter) == .hostCommandRequested("path add ~/notes --read"),
              !rendered(control).contains("E492")
        else {
            throw Failure.invalidCommandStatusChanged
        }

        // Completion: ctrl-n selects, Enter puts it in place, Enter again runs.
        control.commandCompleter = { text in
            guard text.hasPrefix("path add ~/n") else { return nil }
            return .init(
                replacing: "~/n".count,
                candidates: [
                    .init(text: "~/notes/", title: "notes/"),
                    .init(text: "~/news/", title: "news/"),
                ]
            )
        }
        _ = control.handle(.char(":"))
        for character in "path add ~/n" {
            _ = control.handle(.char(String(character)))
        }
        _ = control.handle(.control("N"))
        guard rendered(control).contains("› notes/"),
              control.handle(.enter) == nil,
              control.handle(.enter) == .hostCommandRequested("path add ~/notes/")
        else {
            throw Failure.completionChanged
        }
        control.commandCompleter = nil

        enterCommand(
            "q",
            in: &control
        )

        guard rendered(
            control
        ).contains(
            "archive conversation?"
        ) else {
            throw Failure.quitConfirmationChanged
        }

        _ = control.handle(
            .escape
        )

        guard !rendered(
            control
        ).contains(
            "archive conversation?"
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
        ) == .archiveRequested else {
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

        guard control.focus.current == .transcript else {
            throw Failure.tabSemanticsChanged
        }
    }

    private static func runNavigationProbe() throws {
        var control = AgenticConversationControl(snapshot: AgenticConversationSmoke.fixture())
        // The editor starts in insert mode: Space/p/v are literal draft text.
        for key in [TerminalKey.space, .char("p"), .char("v")] {
            guard control.handle(key) == nil else { throw Failure.insertLeaderTextChanged }
        }
        guard control.draftText == " pv" else { throw Failure.insertLeaderTextChanged }
        _ = control.handle(.control("C"))
        for key in [TerminalKey.space, .char("p")] {
            guard control.handle(key) == nil else { throw Failure.leaderNavigationChanged }
        }
        guard control.handle(.char("v")) == .showWorkRequested,
              control.draftText == " pv"
        else { throw Failure.leaderNavigationChanged }

        // Assert :Ex requests Work navigation without clearing the draft.
        _ = control.handle(.char(":"))
        _ = control.handle(.char("E"))
        _ = control.handle(.char("x"))
        guard control.handle(.enter) == .showWorkRequested
        else { throw Failure.exploreNavigationChanged }
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
