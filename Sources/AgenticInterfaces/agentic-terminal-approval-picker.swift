import Agentic
import Foundation
import Terminal
import Difference
// import DifferenceTerminal

extension TerminalApprovalPicker {
    func runMenu(
        _ prompt: AgenticApprovalPrompt
    ) throws -> AgenticApprovalChoice {
        let width = Terminal.size(
            for: stream
        ).columns

        var instructions = prompt.preflight.summary

        if let guidelines = AgenticGuidelinePresentation.summary(
            prompt.guidelineReferences
        ) {
            instructions += "\n\nguidelines\n\(guidelines)"
        }

        let menu = TerminalInteractiveMenu<AgenticApprovalChoice, String>(
            items: AgenticApprovalChoice.allCases,
            configuration: .inline(
                title: "\(prompt.title): \(prompt.toolName)",
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
                let selection: String

                switch result {
                case .picked(let item, _):
                    selection = theme.value.apply(
                        item.title
                    )

                case .cancelled:
                    selection = theme.warning.apply(
                        "Stop run"
                    )
                }

                return """
                \(theme.label.apply("selected")) \(selection) · \(theme.value.apply(prompt.toolName))
                \(theme.label.apply("intent")) \(theme.value.apply(prompt.preflight.summary))

                """
            }
        )

        switch try menu.run() {
        case .picked(let item, _):
            return item

        case .cancelled:
            return .stop_run
        }
    }

    func renderDetails(
        _ prompt: AgenticApprovalPrompt
    ) {
        let document = prompt.preflight.inspectionDocument(
            title: "Staged intent details",
            toolName: prompt.toolName,
            toolCallID: prompt.toolCall?.id,
            requirement: prompt.requirement
        )

        Terminal.write(
            AgenticTerminalInspectionRenderer.render(
                document,
                stream: stream,
                theme: theme,
                layout: .agentic
            ),
            to: stream
        )

        if let guidelineDetails = AgenticGuidelinePresentation.details(
            prompt.guidelineReferences
        ) {
            Terminal.write(
                TerminalBlock(
                    title: "Guideline rationale",
                    body: guidelineDetails,
                    theme: theme,
                    layout: .agentic
                ).render(
                    stream: stream
                ),
                to: stream
            )
        }
    }

    func renderDiff(
        _ prompt: AgenticApprovalPrompt
    ) {
        guard let diffPreview = prompt.preflight.preview.difference,
              !diffPreview.isEmpty
        else {
            Terminal.write(
                TerminalBlock(
                    title: "Diff preview",
                    fields: [
                        .init("status", "no diff preview available"),
                    ],
                    theme: theme,
                    layout: .agentic
                ).render(
                    stream: stream
                ),
                to: stream
            )

            return
        }

        let renderedDiff = TerminalDifferenceRenderer.render(
            diffPreview.layout,
            options: .init(
                base: .init(
                    showHeader: true,
                    showUnchangedLines: false
                )
            )
        )

        Terminal.write(
            TerminalBlock(
                title: diffPreview.title ?? "Diff preview",
                fields: [
                    .init(
                        "changes",
                        "+\(diffPreview.layout.changes.insertions.count) -\(diffPreview.layout.changes.deletions.count)"
                    ),
                ],
                body: renderedDiff,
                theme: theme,
                layout: .agentic
            ).render(
                stream: stream
            ),
            to: stream
        )
    }
}
