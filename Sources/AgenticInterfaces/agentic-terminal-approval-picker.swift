import Agentic
import Foundation
import Terminal
import Difference
// import DifferenceTerminal

public typealias TerminalApprovalHandler = TerminalApprovalPicker

extension TerminalApprovalPicker: ToolApprovalHandler {
    public func decide(
        on preflight: ToolPreflight,
        requirement: ApprovalRequirement
    ) async throws -> ApprovalDecision {
        if requirement.isDenied {
            return .denied
        }

        if !requirement.requiresHumanReview {
            return .approved
        }

        let choice = try await pick(
            AgenticApprovalPrompt(
                preflight: preflight,
                requirement: requirement
            )
        )

        switch choice {
        case .approve:
            return .approved

        case .deny:
            return .denied

        case .stopRun:
            throw TerminalApprovalPickerError.stoppedRun

        case .inspectDetails,
             .showDiff:
            return .needshuman
        }
    }
}

extension TerminalApprovalPicker {
    func runMenu(
        _ prompt: AgenticApprovalPrompt
    ) throws -> AgenticApprovalChoice {
        let width = Terminal.size(
            for: stream
        ).columns

        let menu = TerminalInteractiveMenu<AgenticApprovalChoice, String>(
            items: AgenticApprovalChoice.allCases,
            configuration: .inline(
                title: "\(prompt.title): \(prompt.toolName)",
                instructions: prompt.preflight.summary,
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
                    return "\(theme.label.apply("selected")) \(theme.warning.apply("Stop run"))\n"
                }
            }
        )

        switch try menu.run() {
        case .picked(let item, _):
            return item

        case .cancelled:
            return .stopRun
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
    }

    func renderDiff(
        _ prompt: AgenticApprovalPrompt
    ) {
        guard let diffPreview = prompt.preflight.diffPreview,
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

        let renderedDiff: String

        if let layout = diffPreview.layout {
            renderedDiff = TerminalDifferenceRenderer.render(
                layout,
                options: .init(
                    base: .init(
                        showHeader: true,
                        showUnchangedLines: false,
                        contextLineCount: diffPreview.contextLineCount
                    )
                )
            )
        } else {
            renderedDiff = diffPreview.text
        }

        Terminal.write(
            TerminalBlock(
                title: diffPreview.title ?? "Diff preview",
                fields: [
                    .init("format", diffPreview.format),
                    .init("context", "\(diffPreview.contextLineCount)"),
                    .init("changes", "+\(diffPreview.insertedLineCount) -\(diffPreview.deletedLineCount)"),
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
