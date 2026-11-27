import Agentic
import Surface
@_spi(Testing) import AgenticInterfaces
import Terminal

enum AgenticConversationUserInputSmoke {
    enum Failure: Error {
        case textReplyChanged
        case multilineReplyChanged
        case singleChoiceReplyChanged
        case customChoiceReplyChanged
        case multiChoiceReplyChanged
        case confirmationReplyChanged
        case formOmissionChanged
        case formEmptyOptionalChanged
        case optionalSkipChanged
        case requiredSkipChanged
        case escapeChanged
        case promptLayoutOverflow
        case promptLayoutDidNotWrap
        case formInputDidNotSoftWrap
        case formInputChangedByWrapping
    }

    static func run() throws {
        try layout()
        try wrappedFormField()
        try text()
        try multiline()
        try singleChoice()
        try customChoice()
        try multiChoice()
        try confirmation()
        try form()
        try skip()
        try escape()
    }

    private static func layout() throws {
        var control = AgenticConversationUserInputControl(
            request: try UserInputRequest(
                prompt: "Which package workspace task would you like to perform? (e.g., inspect package graph, update dependencies, lint package)",
                input: .text(
                    SurfaceTextInput(
                        placeholder: "Enter your choice"
                    )
                )
            )
        )
        let columns = 28
        var frame = TerminalFrame(
            rows: 12,
            columns: columns
        )

        control.render(
            into: &frame,
            in: TerminalRegion(
                rows: 12,
                columns: columns
            )
        )

        let resolved = frame.resolved()
        let lines = (0..<resolved.rows).map { row in
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

        guard lines.allSatisfy({
            TerminalDisplay.width(
                of: $0
            ) <= columns
        }) else {
            throw Failure.promptLayoutOverflow
        }

        let rendered = lines.joined(
            separator: "\n"
        )

        guard rendered.contains(
            "Which package workspace"
        ),
              rendered.contains(
                "lint package"
              )
        else {
            throw Failure.promptLayoutDidNotWrap
        }
    }

    private static func wrappedFormField() throws {
        let value = "alpha beta gamma delta epsilon zeta eta theta endmark"
        var control = AgenticConversationUserInputControl(
            request: try UserInputRequest(
                prompt: "Long answer",
                input: .form(
                    SurfaceForm(fields: [
                        SurfaceForm.Field(id: "note", label: "Note", defaultText: value)
                    ])
                )
            )
        )
        // Narrow enough to wrap, wide enough that the word-wrapped value fits the field's four rows.
        let columns = 26
        var frame = TerminalFrame(rows: 16, columns: columns)
        control.render(
            into: &frame,
            in: TerminalRegion(rows: 16, columns: columns)
        )
        let rendered = frame.resolved().spans
            .map(\.content)
            .joined(separator: "\n")
        guard rendered.contains("alpha"), rendered.contains("endmark") else {
            throw Failure.formInputDidNotSoftWrap
        }
        guard case .submitted(.answer(.form(let answer)))? = control.handle(
            SurfaceInput.Stroke(key: .enter, modifiers: .control)
        ), answer.values["note"] == value else {
            throw Failure.formInputChangedByWrapping
        }
    }

    private static func text() throws {
        var control = AgenticConversationUserInputControl(
            request: try UserInputRequest(
                prompt: "Name",
                input: .text(
                    SurfaceTextInput(
                        placeholder: "package name"
                    )
                )
            )
        )

        _ = control.handle(
            .paste("AgenticFoo")
        )

        guard control.handle(
            SurfaceInput.Stroke(
                key: .enter
            )
        ) == nil else {
            throw Failure.textReplyChanged
        }

        guard case .submitted(
            .answer(
                .text("AgenticFoo\n")
            )
        )? = control.handle(
            SurfaceInput.Stroke(
                key: .enter,
                modifiers: .control
            )
        ) else {
            throw Failure.textReplyChanged
        }
    }

    private static func multiline() throws {
        var control = AgenticConversationUserInputControl(
            request: try UserInputRequest(
                prompt: "Notes",
                input: .text(
                    SurfaceTextInput(
                        multiline: true
                    )
                )
            )
        )

        _ = control.handle(
            .paste("first")
        )
        _ = control.handle(
            SurfaceInput.Stroke(
                key: .enter
            )
        )
        _ = control.handle(
            .paste("second")
        )

        guard case .submitted(
            .answer(
                .text("first\nsecond")
            )
        )? = control.handle(
            SurfaceInput.Stroke(
                key: .enter,
                modifiers: .control
            )
        ) else {
            throw Failure.multilineReplyChanged
        }
    }

    private static func singleChoice() throws {
        var control = AgenticConversationUserInputControl(
            request: try UserInputRequest(
                prompt: "Compatibility",
                input: .choice(
                    SurfaceChoice(
                        options: [
                            SurfaceChoice.Option(
                                id: "hard-cut",
                                label: "Hard cut",
                                value: "hard-cut"
                            ),
                            SurfaceChoice.Option(
                                id: "compatibility",
                                label: "Compatibility layer",
                                value: "compatibility"
                            ),
                        ],
                        defaults: ["compatibility"]
                    )
                )
            )
        )

        guard case .submitted(
            .answer(
                .choice(
                    let answer
                )
            )
        )? = control.handle(
            SurfaceInput.Stroke(
                key: .enter
            )
        ),
              answer == .option("compatibility")
        else {
            throw Failure.singleChoiceReplyChanged
        }
    }

    private static func customChoice() throws {
        var control = AgenticConversationUserInputControl(
            request: try UserInputRequest(
                prompt: "Strategy",
                input: .choice(
                    SurfaceChoice(
                        options: [
                            SurfaceChoice.Option(
                                id: "direct",
                                label: "Direct",
                                value: "direct"
                            ),
                        ],
                        allowsCustomValue: true
                    )
                )
            )
        )

        _ = control.handle(
            SurfaceInput.Stroke(
                key: .down
            )
        )
        _ = control.handle(
            SurfaceInput.Stroke(
                key: .enter
            )
        )
        _ = control.handle(
            .paste("reviewed")
        )

        guard case .submitted(
            .answer(
                .choice(
                    let answer
                )
            )
        )? = control.handle(
            SurfaceInput.Stroke(
                key: .enter
            )
        ),
              answer == .custom("reviewed")
        else {
            throw Failure.customChoiceReplyChanged
        }
    }

    private static func multiChoice() throws {
        var control = AgenticConversationUserInputControl(
            request: try UserInputRequest(
                prompt: "Capabilities",
                input: .choice(
                    SurfaceChoice(
                        options: [
                            SurfaceChoice.Option(
                                id: "read",
                                label: "Read",
                                value: "read"
                            ),
                            SurfaceChoice.Option(
                                id: "write",
                                label: "Write",
                                value: "write"
                            ),
                            SurfaceChoice.Option(
                                id: "test",
                                label: "Test",
                                value: "test"
                            ),
                        ],
                        rule: .many,
                        defaults: [
                            "read",
                        ]
                    )
                )
            )
        )

        _ = control.handle(
            SurfaceInput.Stroke(
                key: .down
            )
        )
        _ = control.handle(
            SurfaceInput.Stroke(
                key: .space
            )
        )

        guard case .submitted(
            .answer(
                .choice(
                    let answer
                )
            )
        )? = control.handle(
            SurfaceInput.Stroke(
                key: .enter
            )
        ),
              answer.selected == ["read", "write"]
        else {
            throw Failure.multiChoiceReplyChanged
        }
    }

    private static func confirmation() throws {
        var control = AgenticConversationUserInputControl(
            request: try UserInputRequest(
                prompt: "Continue?",
                input: .confirmation(
                    SurfaceConfirmation(
                        defaultValue: false,
                        confirmLabel: "Continue",
                        cancelLabel: "Stop"
                    )
                )
            )
        )

        guard case .submitted(
            .answer(
                .confirmation(false)
            )
        )? = control.handle(
            SurfaceInput.Stroke(
                key: .enter
            )
        ) else {
            throw Failure.confirmationReplyChanged
        }
    }

    private static func form() throws {
        let request = try UserInputRequest(
            prompt: "Package setup",
            input: .form(
                SurfaceForm(
                    fields: [
                        SurfaceForm.Field(
                            id: "name",
                            label: "Name",
                            defaultText: "AgenticFoo"
                        ),
                        SurfaceForm.Field(
                            id: "note",
                            label: "Note",
                            requirement: .optional
                        ),
                    ]
                )
            )
        )

        var omitted = AgenticConversationUserInputControl(
            request: request
        )

        guard case .submitted(
            .answer(
                .form(
                    let omittedAnswer
                )
            )
        )? = omitted.handle(
            SurfaceInput.Stroke(
                key: .enter,
                modifiers: .control
            )
        ),
              omittedAnswer.values == [
                  "name": "AgenticFoo",
              ]
        else {
            throw Failure.formOmissionChanged
        }

        var explicitEmpty = AgenticConversationUserInputControl(
            request: request
        )
        _ = explicitEmpty.handle(
            SurfaceInput.Stroke(
                key: .tab
            )
        )
        _ = explicitEmpty.handle(
            SurfaceInput.Stroke(
                key: .control("O")
            )
        )

        guard case .submitted(
            .answer(
                .form(
                    let includedAnswer
                )
            )
        )? = explicitEmpty.handle(
            SurfaceInput.Stroke(
                key: .enter,
                modifiers: .control
            )
        ),
              includedAnswer.values == [
                  "name": "AgenticFoo",
                  "note": "",
              ]
        else {
            throw Failure.formEmptyOptionalChanged
        }
    }

    private static func skip() throws {
        var optional = AgenticConversationUserInputControl(
            request: try UserInputRequest(
                prompt: "Optional note",
                requirement: .optional
            )
        )

        guard case .submitted(.skip)? = optional.handle(
            SurfaceInput.Stroke(
                key: .control("S")
            )
        ) else {
            throw Failure.optionalSkipChanged
        }

        var required = AgenticConversationUserInputControl(
            request: try UserInputRequest(
                prompt: "Required note"
            )
        )

        guard case .feedbackRequested(_)? = required.handle(
            SurfaceInput.Stroke(
                key: .control("S")
            )
        ) else {
            throw Failure.requiredSkipChanged
        }
    }

    private static func escape() throws {
        var control = AgenticConversationUserInputControl(
            request: try UserInputRequest(
                prompt: "Optional note",
                requirement: .optional
            )
        )

        // Esc and Ctrl-C switch the editor's mode; Ctrl-F leaves, as in the composer.
        guard control.handle(SurfaceInput.Stroke(key: .escape)) == nil,
              control.handle(SurfaceInput.Stroke(key: .control("C"))) == nil,
              case .closeRequested? = control.handle(
                SurfaceInput.Stroke(
                    key: .control("F")
                )
              ) else {
            throw Failure.escapeChanged
        }

        // Choice lists have no editor: Esc and Ctrl-C still close.
        var choices = AgenticConversationUserInputControl(
            request: try UserInputRequest(
                prompt: "Strategy",
                input: .choice(
                    SurfaceChoice(
                        options: [SurfaceChoice.Option(id: "direct", label: "Direct", value: "direct")],
                        allowsCustomValue: true
                    )
                )
            )
        )
        guard case .closeRequested? = choices.handle(SurfaceInput.Stroke(key: .control("C"))) else {
            throw Failure.escapeChanged
        }
        _ = choices.handle(SurfaceInput.Stroke(key: .down))
        _ = choices.handle(SurfaceInput.Stroke(key: .enter))
        guard choices.handle(SurfaceInput.Stroke(key: .escape)) == nil,
              choices.handle(SurfaceInput.Stroke(key: .control("F"))) == nil,
              case .closeRequested? = choices.handle(SurfaceInput.Stroke(key: .escape)) else {
            throw Failure.escapeChanged
        }
    }
}
