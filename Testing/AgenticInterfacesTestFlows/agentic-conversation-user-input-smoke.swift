import Agentic
import AgenticInterfaces
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
    }

    static func run() throws {
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

    private static func text() throws {
        var control = AgenticConversationUserInputControl(
            request: try UserInputRequest(
                prompt: "Name",
                input: .text(
                    TextUserInput(
                        placeholder: "package name"
                    )
                )
            )
        )

        _ = control.handle(
            .paste("AgenticFoo")
        )

        guard case .submitted(
            .answer(
                .text("AgenticFoo")
            )
        )? = control.handle(
            TerminalKeyStroke(
                key: .enter
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
                    TextUserInput(
                        multiline: true
                    )
                )
            )
        )

        _ = control.handle(
            .paste("first")
        )
        _ = control.handle(
            TerminalKeyStroke(
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
            TerminalKeyStroke(
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
                input: .single_choice(
                    SingleChoiceUserInput(
                        choices: [
                            UserInputChoice(
                                id: "hard-cut",
                                label: "Hard cut",
                                value: "hard-cut"
                            ),
                            UserInputChoice(
                                id: "compatibility",
                                label: "Compatibility layer",
                                value: "compatibility"
                            ),
                        ],
                        defaultChoiceID: "compatibility"
                    )
                )
            )
        )

        guard case .submitted(
            .answer(
                .single_choice(
                    .choice("compatibility")
                )
            )
        )? = control.handle(
            TerminalKeyStroke(
                key: .enter
            )
        ) else {
            throw Failure.singleChoiceReplyChanged
        }
    }

    private static func customChoice() throws {
        var control = AgenticConversationUserInputControl(
            request: try UserInputRequest(
                prompt: "Strategy",
                input: .single_choice(
                    SingleChoiceUserInput(
                        choices: [
                            UserInputChoice(
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
            TerminalKeyStroke(
                key: .down
            )
        )
        _ = control.handle(
            TerminalKeyStroke(
                key: .enter
            )
        )
        _ = control.handle(
            .paste("reviewed")
        )

        guard case .submitted(
            .answer(
                .single_choice(
                    .custom("reviewed")
                )
            )
        )? = control.handle(
            TerminalKeyStroke(
                key: .enter
            )
        ) else {
            throw Failure.customChoiceReplyChanged
        }
    }

    private static func multiChoice() throws {
        var control = AgenticConversationUserInputControl(
            request: try UserInputRequest(
                prompt: "Capabilities",
                input: .multi_choice(
                    MultiChoiceUserInput(
                        choices: [
                            UserInputChoice(
                                id: "read",
                                label: "Read",
                                value: "read"
                            ),
                            UserInputChoice(
                                id: "write",
                                label: "Write",
                                value: "write"
                            ),
                            UserInputChoice(
                                id: "test",
                                label: "Test",
                                value: "test"
                            ),
                        ],
                        defaultChoiceIDs: [
                            "read",
                        ]
                    )
                )
            )
        )

        _ = control.handle(
            TerminalKeyStroke(
                key: .down
            )
        )
        _ = control.handle(
            TerminalKeyStroke(
                key: .space
            )
        )

        guard case .submitted(
            .answer(
                .multi_choice(
                    let answer
                )
            )
        )? = control.handle(
            TerminalKeyStroke(
                key: .enter
            )
        ),
              answer.choiceIDs == ["read", "write"]
        else {
            throw Failure.multiChoiceReplyChanged
        }
    }

    private static func confirmation() throws {
        var control = AgenticConversationUserInputControl(
            request: try UserInputRequest(
                prompt: "Continue?",
                input: .confirmation(
                    ConfirmationUserInput(
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
            TerminalKeyStroke(
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
                FormUserInput(
                    fields: [
                        UserInputField(
                            id: "name",
                            label: "Name",
                            defaultText: "AgenticFoo"
                        ),
                        UserInputField(
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
            TerminalKeyStroke(
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
            TerminalKeyStroke(
                key: .tab
            )
        )
        _ = explicitEmpty.handle(
            TerminalKeyStroke(
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
            TerminalKeyStroke(
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
            TerminalKeyStroke(
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
            TerminalKeyStroke(
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

        guard case .closeRequested? = control.handle(
            TerminalKeyStroke(
                key: .escape
            )
        ) else {
            throw Failure.escapeChanged
        }
    }
}
