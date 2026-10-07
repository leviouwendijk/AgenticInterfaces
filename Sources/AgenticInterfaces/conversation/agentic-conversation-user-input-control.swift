import Agentic
import Foundation
import Swim
import SwimTerminal
import Terminal

package enum AgenticConversationUserInputEvent:
    Sendable,
    Hashable
{
    case submitted(UserInputReply)
    case closeRequested
    case feedbackRequested(String)
}

package struct AgenticConversationUserInputControl:
    Sendable
{
    private enum State: Sendable {
        case text(TextState)
        case single_choice(SingleChoiceState)
        case multi_choice(MultiChoiceState)
        case confirmation(ConfirmationState)
        case form(FormState)
    }

    private struct TextEditor: Sendable {
        var surface: SwimTerminalSurface

        init(
            text: String = "",
            placeholder: String = "",
            maximumRows: Int = 6
        ) {
            let presentation = SwimTerminalPresentation(
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
                    text: text,
                    mode: .insert
                ),
                sizePolicy: SwimTerminalSurfaceSizePolicy(
                    minimumRows: 1,
                    maximumRows: maximumRows
                ),
                compactPresentation: presentation,
                expandedPresentation: presentation,
                placeholder: placeholder
            )
        }

        var text: String {
            surface.text
        }

        func resolvedRows(
            in region: TerminalRegion
        ) -> Int {
            surface.resolvedRows(
                columns: region.columns,
                availableRows: region.rows
            )
        }

        @discardableResult
        mutating func handle(
            _ event: TerminalInputEvent
        ) -> Bool {
            let previous = surface.text

            switch event {
            case .keyStroke(let keyStroke):
                _ = handle(
                    keyStroke
                )

            case .key(let key):
                _ = surface.handle(
                    key
                )

            case .paste(_):
                _ = surface.handle(
                    event
                )
            }

            return surface.text != previous
        }

        @discardableResult
        mutating func handle(
            _ keyStroke: TerminalKeyStroke
        ) -> Bool {
            let previous = surface.text
            let key: TerminalKey =
                keyStroke.key == .control("C")
                ? .escape
                : keyStroke.key

            _ = surface.handle(
                key
            )

            return surface.text != previous
        }

        mutating func insertNewline() {
            _ = surface.handle(
                .enter
            )
        }

        mutating func render(
            into frame: inout TerminalFrame,
            in region: TerminalRegion,
            isFocused: Bool
        ) {
            let rows = resolvedRows(
                in: region
            )

            guard rows > 0 else {
                return
            }

            surface.render(
                into: &frame,
                in: TerminalRegion(
                    top: region.top,
                    leading: region.leading,
                    rows: rows,
                    columns: region.columns
                ),
                isFocused: isFocused
            )
        }
    }

    private struct TextState: Sendable {
        let specification: TextUserInput
        var input: TextEditor
    }

    private enum SingleChoiceItem:
        Sendable,
        Hashable
    {
        case choice(UserInputChoice)
        case custom

        var id: String {
            switch self {
            case .choice(let choice):
                return "choice:\(choice.id)"

            case .custom:
                return "custom"
            }
        }

        var title: String {
            switch self {
            case .choice(let choice):
                return choice.label

            case .custom:
                return "Custom value"
            }
        }

        var detail: String? {
            switch self {
            case .choice(let choice):
                return choice.description

            case .custom:
                return "Enter a value not listed above."
            }
        }
    }

    private struct SingleChoiceState: Sendable {
        let specification: SingleChoiceUserInput
        var list: TerminalListControl<SingleChoiceItem, String>
        var customInput: TextEditor?
    }

    private struct MultiChoiceState: Sendable {
        let specification: MultiChoiceUserInput
        var list: TerminalMultiSelectControl<UserInputChoice, String>
    }

    private struct ConfirmationItem: Sendable, Hashable {
        let value: Bool
        let title: String
    }

    private struct ConfirmationState: Sendable {
        let specification: ConfirmationUserInput
        var list: TerminalListControl<ConfirmationItem, Bool>
    }

    private struct FormState: Sendable {
        let specification: FormUserInput
        var inputs: [String: TextEditor]
        var includedFieldIDs: Set<String>
        var focus: TerminalFocusState<String>

        init(
            specification: FormUserInput
        ) {
            self.specification = specification
            self.inputs = Dictionary(
                uniqueKeysWithValues: specification.fields.map { field in
                    (
                        field.id,
                        TextEditor(
                            text: field.defaultText ?? "",
                            placeholder: field.placeholder ?? "",
                            maximumRows: field.multiline
                                ? 4
                                : 1
                        )
                    )
                }
            )
            self.includedFieldIDs = Set(
                specification.fields.compactMap { field in
                    field.requirement == .required
                        || field.defaultText != nil
                        ? field.id
                        : nil
                }
            )
            self.focus = TerminalFocusState(
                order: specification.fields.map(\.id)
            )
        }
    }

    package let request: UserInputRequest
    private var state: State

    package init(
        request: UserInputRequest
    ) {
        self.request = request

        switch request.input {
        case .text(let specification):
            self.state = .text(
                TextState(
                    specification: specification,
                    input: TextEditor(
                        text: specification.defaultText ?? "",
                        placeholder: specification.placeholder ?? "",
                        maximumRows: specification.multiline
                            ? 6
                            : 1
                    )
                )
            )

        case .single_choice(let specification):
            let choices = Self.orderedChoices(
                specification.choices,
                presentation: request.presentation
            )
            var items = choices.map(
                SingleChoiceItem.choice
            )

            if specification.allowsCustomValue {
                items.append(
                    .custom
                )
            }

            let currentID = specification.defaultChoiceID.map {
                "choice:\($0)"
            }

            self.state = .single_choice(
                SingleChoiceState(
                    specification: specification,
                    list: TerminalListControl(
                        items: items,
                        currentID: currentID,
                        id: \.id
                    ),
                    customInput: nil
                )
            )

        case .multi_choice(let specification):
            let choices = Self.orderedChoices(
                specification.choices,
                presentation: request.presentation
            )

            self.state = .multi_choice(
                MultiChoiceState(
                    specification: specification,
                    list: TerminalMultiSelectControl(
                        items: choices,
                        currentID: specification.defaultChoiceIDs.first,
                        selectedIDs: Set(
                            specification.defaultChoiceIDs
                        ),
                        id: \.id
                    )
                )
            )

        case .confirmation(let specification):
            let items = [
                ConfirmationItem(
                    value: true,
                    title: specification.confirmLabel
                ),
                ConfirmationItem(
                    value: false,
                    title: specification.cancelLabel
                ),
            ]

            self.state = .confirmation(
                ConfirmationState(
                    specification: specification,
                    list: TerminalListControl(
                        items: items,
                        currentID: specification.defaultValue,
                        id: \.value
                    )
                )
            )

        case .form(let specification):
            self.state = .form(
                FormState(
                    specification: specification
                )
            )
        }
    }

    package var footer: String {
        let base: String

        switch state {
        case .text(let text):
            base = text.specification.multiline
                ? "enter newline  ctrl-enter submit  ctrl-c normal  esc back"
                : "enter submit  ctrl-c normal  esc back"

        case .single_choice(let single):
            base = single.customInput == nil
                ? "j/k choose  enter select  esc back"
                : "enter submit custom  ctrl-c normal  esc choices"

        case .multi_choice:
            base = "j/k choose  space toggle  enter submit  esc back"

        case .confirmation:
            base = "j/k choose  enter select  esc back"

        case .form:
            base = "tab/shift-tab field  ctrl-enter submit  ctrl-o include/omit optional  esc back"
        }

        guard request.requirement == .optional else {
            return base
        }

        return base + "  ctrl-s skip"
    }

    package mutating func handle(
        _ event: TerminalInputEvent
    ) -> AgenticConversationUserInputEvent? {
        switch event {
        case .paste(let text):
            return handlePaste(
                text
            )

        case .key(let key):
            return handle(
                TerminalKeyStroke(
                    key: key
                )
            )

        case .keyStroke(let keyStroke):
            return handle(
                keyStroke
            )
        }
    }

    package mutating func handle(
        _ keyStroke: TerminalKeyStroke
    ) -> AgenticConversationUserInputEvent? {
        if case .single_choice(var single) = state,
           single.customInput != nil,
           keyStroke.key == .escape
        {
            single.customInput = nil
            state = .single_choice(
                single
            )
            return nil
        }

        if keyStroke.key == .escape {
            return .closeRequested
        }

        if keyStroke.key == .control("S") {
            guard request.requirement == .optional else {
                return .feedbackRequested(
                    "This input is required and cannot be skipped."
                )
            }

            return .submitted(
                .skip
            )
        }

        switch state {
        case .text(var text):
            let event = handleText(
                keyStroke,
                state: &text
            )
            state = .text(
                text
            )
            return event

        case .single_choice(var single):
            let event = handleSingleChoice(
                keyStroke,
                state: &single
            )
            state = .single_choice(
                single
            )
            return event

        case .multi_choice(var multi):
            let event = handleMultiChoice(
                keyStroke,
                state: &multi
            )
            state = .multi_choice(
                multi
            )
            return event

        case .confirmation(var confirmation):
            let event = handleConfirmation(
                keyStroke,
                state: &confirmation
            )
            state = .confirmation(
                confirmation
            )
            return event

        case .form(var form):
            let event = handleForm(
                keyStroke,
                state: &form
            )
            state = .form(
                form
            )
            return event
        }
    }

    package mutating func render(
        into frame: inout TerminalFrame,
        in region: TerminalRegion
    ) {
        let body = renderHeader(
            into: &frame,
            in: region
        )

        guard !body.isEmpty else {
            return
        }

        switch state {
        case .text(var text):
            text.input.render(
                into: &frame,
                in: body,
                isFocused: true
            )
            state = .text(
                text
            )

        case .single_choice(var single):
            renderSingleChoice(
                &single,
                into: &frame,
                in: body
            )
            state = .single_choice(
                single
            )

        case .multi_choice(let multi):
            renderMultiChoice(
                multi,
                into: &frame,
                in: body
            )

        case .confirmation(let confirmation):
            renderConfirmation(
                confirmation,
                into: &frame,
                in: body
            )

        case .form(var form):
            renderForm(
                &form,
                into: &frame,
                in: body
            )
            state = .form(
                form
            )
        }
    }
}

private extension AgenticConversationUserInputControl {
    static func orderedChoices(
        _ choices: [UserInputChoice],
        presentation: UserInputPresentation?
    ) -> [UserInputChoice] {
        guard presentation?.ordering == .alphabetical else {
            return choices
        }

        return choices.sorted { lhs, rhs in
            lhs.label.localizedCaseInsensitiveCompare(
                rhs.label
            ) == .orderedAscending
        }
    }

    mutating func handlePaste(
        _ text: String
    ) -> AgenticConversationUserInputEvent? {
        switch state {
        case .text(var value):
            _ = value.input.handle(
                .paste(text)
            )
            state = .text(
                value
            )

        case .single_choice(var value):
            guard var custom = value.customInput else {
                return nil
            }

            _ = custom.handle(
                .paste(text)
            )
            value.customInput = custom
            state = .single_choice(
                value
            )

        case .form(var value):
            guard let fieldID = value.focus.focused,
                  var input = value.inputs[fieldID] else {
                return nil
            }

            if input.handle(
                .paste(text)
            ) {
                value.includedFieldIDs.insert(
                    fieldID
                )
            }

            value.inputs[fieldID] = input
            state = .form(
                value
            )

        case .multi_choice,
             .confirmation:
            return nil
        }

        return nil
    }

    private func handleText(
        _ keyStroke: TerminalKeyStroke,
        state: inout TextState
    ) -> AgenticConversationUserInputEvent? {
        if keyStroke.key == .enter,
           keyStroke.modifiers.contains(.control)
        {
            return .submitted(
                .text(
                    state.input.text
                )
            )
        }

        _ = state.input.handle(
            keyStroke
        )
        return nil
    }

    private func handleSingleChoice(
        _ keyStroke: TerminalKeyStroke,
        state: inout SingleChoiceState
    ) -> AgenticConversationUserInputEvent? {
        if var custom = state.customInput {
            if keyStroke.key == .enter {
                return .submitted(
                    .single_choice(
                        .custom(
                            custom.text
                        )
                    )
                )
            }

            _ = custom.handle(
                keyStroke
            )
            state.customInput = custom
            return nil
        }

        guard let event = state.list.handle(
            keyStroke.key
        ) else {
            return nil
        }

        guard case .accepted = event,
              let item = state.list.currentItem else {
            return nil
        }

        switch item {
        case .choice(let choice):
            return .submitted(
                .single_choice(
                    .choice(
                        choice.id
                    )
                )
            )

        case .custom:
            state.customInput = TextEditor(
                placeholder: "custom value",
                maximumRows: 1
            )
            return nil
        }
    }

    private func handleMultiChoice(
        _ keyStroke: TerminalKeyStroke,
        state: inout MultiChoiceState
    ) -> AgenticConversationUserInputEvent? {
        guard let event = state.list.handle(
            keyStroke.key
        ) else {
            return nil
        }

        guard case .accepted(let ids) = event else {
            return nil
        }

        return .submitted(
            .multi_choice(
                MultiChoiceUserInputAnswer(
                    choiceIDs: ids
                )
            )
        )
    }

    private func handleConfirmation(
        _ keyStroke: TerminalKeyStroke,
        state: inout ConfirmationState
    ) -> AgenticConversationUserInputEvent? {
        guard let event = state.list.handle(
            keyStroke.key
        ) else {
            return nil
        }

        guard case .accepted(let value) = event else {
            return nil
        }

        return .submitted(
            .confirmation(
                value
            )
        )
    }

    private func handleForm(
        _ keyStroke: TerminalKeyStroke,
        state: inout FormState
    ) -> AgenticConversationUserInputEvent? {
        if keyStroke.key == .enter,
           keyStroke.modifiers.contains(.control)
        {
            return .submitted(
                formReply(
                    state
                )
            )
        }

        if keyStroke.key == .tab {
            if keyStroke.modifiers.contains(.shift) {
                _ = state.focus.movePrevious()
            } else {
                _ = state.focus.moveNext()
            }
            return nil
        }

        guard let fieldID = state.focus.focused,
              let field = state.specification.fields.first(where: {
                  $0.id == fieldID
              }),
              var input = state.inputs[fieldID] else {
            return nil
        }

        if keyStroke.key == .control("O") {
            guard field.requirement == .optional else {
                return .feedbackRequested(
                    "Required form fields cannot be omitted."
                )
            }

            if state.includedFieldIDs.contains(fieldID) {
                state.includedFieldIDs.remove(
                    fieldID
                )
            } else {
                state.includedFieldIDs.insert(
                    fieldID
                )
            }

            return nil
        }

        if keyStroke.key == .enter {
            if field.multiline {
                input.insertNewline()
                state.inputs[fieldID] = input
                state.includedFieldIDs.insert(
                    fieldID
                )
            } else {
                _ = state.focus.moveNext()
            }

            return nil
        }

        if input.handle(
            keyStroke
        ) {
            state.includedFieldIDs.insert(
                fieldID
            )
        }

        state.inputs[fieldID] = input
        return nil
    }

    private func formReply(
        _ state: FormState
    ) -> UserInputReply {
        var values: [String: String] = [:]

        for field in state.specification.fields {
            guard field.requirement == .required
                    || state.includedFieldIDs.contains(field.id),
                  let input = state.inputs[field.id] else {
                continue
            }

            values[field.id] = input.text
        }

        return .form(
            FormUserInputAnswer(
                values: values
            )
        )
    }

    func renderHeader(
        into frame: inout TerminalFrame,
        in region: TerminalRegion
    ) -> TerminalRegion {
        let width = max(
            1,
            region.columns
        )
        var lines: [String] = []

        if let title = request.presentation?.title,
           !title.isEmpty {
            lines.append(
                contentsOf: TerminalTextWrap.lines(
                    title,
                    width: width
                ).map {
                    TerminalStyle.bold.apply(
                        $0
                    )
                }
            )
        }

        lines.append(
            contentsOf: TerminalTextWrap.lines(
                request.prompt,
                width: width
            )
        )

        if let reason = request.reason,
           !reason.isEmpty {
            lines.append(
                contentsOf: TerminalTextWrap.lines(
                    reason,
                    width: width
                ).map {
                    TerminalStyle.dim.apply(
                        $0
                    )
                }
            )
        }

        if let help = request.presentation?.help,
           !help.isEmpty {
            lines.append(
                contentsOf: TerminalTextWrap.lines(
                    help,
                    width: width
                ).map {
                    TerminalStyle.dim.apply(
                        $0
                    )
                }
            )
        }

        let visibleLines = Array(
            lines.prefix(
                region.rows
            )
        )
        frame.write(
            visibleLines,
            in: region
        )

        let consumed = min(
            region.rows,
            visibleLines.count
                + (visibleLines.isEmpty ? 0 : 1)
        )

        return TerminalRegion(
            top: region.top + consumed,
            leading: region.leading,
            rows: max(
                0,
                region.rows - consumed
            ),
            columns: region.columns
        )
    }

    private func renderSingleChoice(
        _ state: inout SingleChoiceState,
        into frame: inout TerminalFrame,
        in region: TerminalRegion
    ) {
        if var custom = state.customInput {
            custom.render(
                into: &frame,
                in: region,
                isFocused: true
            )
            state.customInput = custom
            return
        }

        state.list.render(
            into: &frame,
            in: region
        ) { row in
            let marker = row.isCurrent
                ? ">"
                : " "
            let detail = row.item.detail.map {
                "  \($0)"
            } ?? ""

            let value = TerminalDisplay.fitted(
                "\(marker) \(row.item.title)\(detail)",
                columns: region.columns
            )

            return row.isCurrent
                ? TerminalStyle(
                    .inverse
                ).apply(
                    value
                )
                : value
        }
    }

    private func renderMultiChoice(
        _ state: MultiChoiceState,
        into frame: inout TerminalFrame,
        in region: TerminalRegion
    ) {
        state.list.render(
            into: &frame,
            in: region
        ) { row in
            let marker = row.isCurrent
                ? ">"
                : " "
            let selection = row.isSelected
                ? "[x]"
                : "[ ]"
            let detail = row.item.description.map {
                "  \($0)"
            } ?? ""

            let value = TerminalDisplay.fitted(
                "\(marker) \(selection) \(row.item.label)\(detail)",
                columns: region.columns
            )

            return row.isCurrent
                ? TerminalStyle(
                    .inverse
                ).apply(
                    value
                )
                : value
        }
    }

    private func renderConfirmation(
        _ state: ConfirmationState,
        into frame: inout TerminalFrame,
        in region: TerminalRegion
    ) {
        state.list.render(
            into: &frame,
            in: region
        ) { row in
            let marker = row.isCurrent
                ? ">"
                : " "

            let value = TerminalDisplay.fitted(
                "\(marker) \(row.item.title)",
                columns: region.columns
            )

            return row.isCurrent
                ? TerminalStyle(
                    .inverse
                ).apply(
                    value
                )
                : value
        }
    }

    private func renderForm(
        _ state: inout FormState,
        into frame: inout TerminalFrame,
        in region: TerminalRegion
    ) {
        var row = region.top
        let end = region.top + region.rows

        for field in state.specification.fields {
            guard row < end else {
                break
            }

            let isFocused = state.focus.focused == field.id
            let focusMarker = isFocused
                ? ">"
                : " "
            let requirement = field.requirement == .required
                ? "required"
                : state.includedFieldIDs.contains(field.id)
                    ? "optional, included"
                    : "optional, omitted"

            let label = TerminalDisplay.fitted(
                "\(focusMarker) \(field.label)  [\(requirement)]",
                columns: region.columns
            )
            frame.write(
                isFocused
                    ? TerminalStyle(
                        .inverse
                    ).apply(
                        label
                    )
                    : label,
                in: TerminalRegion(
                    top: row,
                    leading: region.leading,
                    rows: 1,
                    columns: region.columns
                )
            )
            row += 1

            guard row < end,
                  var input = state.inputs[field.id] else {
                continue
            }

            let inputRegion = TerminalRegion(
                top: row,
                leading: region.leading + 2,
                rows: max(
                    0,
                    end - row
                ),
                columns: max(
                    0,
                    region.columns - 2
                )
            )
            let inputRows = input.resolvedRows(
                in: inputRegion
            )

            input.render(
                into: &frame,
                in: inputRegion,
                isFocused: isFocused
            )
            state.inputs[field.id] = input
            row += inputRows
        }
    }
}
