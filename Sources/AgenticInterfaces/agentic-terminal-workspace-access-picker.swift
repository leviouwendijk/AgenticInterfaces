import Terminal

public struct TerminalWorkspaceAccessPicker:
    Sendable
{
    public var stream: TerminalStream
    public var theme: TerminalTheme

    public init(
        stream: TerminalStream = .standardError,
        theme: TerminalTheme = .agentic
    ) {
        self.stream = stream
        self.theme = theme
    }

    public func pick(
        _ prompt: AgenticWorkspaceAccessPrompt
    ) throws -> AgenticWorkspaceAccessChoice {
        let width = Terminal.size(
            for: stream
        ).columns
        var instructions = prompt.summary

        if !prompt.fields.isEmpty {
            instructions += "\n\n"
            instructions += prompt.fields.map { field in
                "\(field.label)  \(field.value)"
            }.joined(
                separator: "\n"
            )
        }

        let menu = TerminalInteractiveMenu<
            AgenticWorkspaceAccessChoice,
            String
        >(
            items: AgenticWorkspaceAccessChoice.allCases,
            configuration: .inline(
                title: prompt.title,
                instructions: instructions,
                outputStream: stream,
                completionPresentation: .leaveSummary,
                currentRowStyle: .none
            ),
            id: { choice in
                choice.rawValue
            },
            row: { row in
                TerminalMenuRowContent(
                    title: row.item.title,
                    caption: row.item.summary
                ).render(
                    isCurrent: row.isCurrent,
                    isEnabled: row.isEnabled,
                    theme: theme,
                    width: width
                )
            },
            summary: { result in
                switch result {
                case .picked(let item, _):
                    return "\(theme.label.apply("selected")) \(theme.value.apply(item.title))\n"

                case .cancelled:
                    return "\(theme.label.apply("selected")) \(theme.warning.apply(AgenticWorkspaceAccessChoice.deny.title))\n"
                }
            }
        )

        switch try menu.run() {
        case .picked(let item, _):
            return item

        case .cancelled:
            return .deny
        }
    }
}

extension TerminalWorkspaceAccessPicker:
    AgenticWorkspaceAccessChoosing
{
    public func choose(
        _ prompt: AgenticWorkspaceAccessPrompt
    ) async throws -> AgenticWorkspaceAccessChoice {
        try pick(
            prompt
        )
    }
}
