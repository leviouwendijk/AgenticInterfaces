import Agentic
import AgenticInterfaces
import Difference
// import DifferenceTerminal
import Foundation
import TestFlows
import Terminal

struct TestFlowApprovalPicker: Sendable {
    var interaction: any TestFlowInteraction
    var presenter: (any AgenticRunPresenter)?

    init(
        interaction: any TestFlowInteraction,
        presenter: (any AgenticRunPresenter)? = nil
    ) {
        self.interaction = interaction
        self.presenter = presenter
    }

    func pick(
        _ prompt: AgenticApprovalPrompt
    ) async throws -> AgenticApprovalChoice {
        try await presenter?.present(
            .approvalRequested(
                prompt
            )
        )

        while true {
            let choice = try await pickChoice(
                prompt
            )

            try await presenter?.present(
                .approvalChoice(
                    choice
                )
            )

            switch choice {
            case .inspectDetails:
                renderDetails(
                    prompt
                )

            case .showDiff:
                renderDiff(
                    prompt
                )

            case .approve,
                 .deny,
                 .stopRun:
                return choice
            }
        }
    }
}

private extension TestFlowApprovalPicker {
    func pickChoice(
        _ prompt: AgenticApprovalPrompt
    ) async throws -> AgenticApprovalChoice {
        let choice: TestFlowChoice

        do {
            choice = try await interaction.choose(
                .init(
                    key: "approval-choice",
                    title: "\(prompt.title): \(prompt.toolName)",
                    summary: prompt.preflight.summary,
                    choices: AgenticApprovalChoice.allCases.map { choice in
                        TestFlowChoice(
                            id: choice.title,
                            title: choice.title,
                            summary: choice.summary
                        )
                    },
                    allowsCancel: true
                )
            )
        } catch let error as TestFlowInteractionError {
            if case .cancelled = error {
                return .stopRun
            }

            throw error
        }

        if let approvalChoice = AgenticApprovalChoice.allCases.first(where: { $0.title == choice.id }) {
            return approvalChoice
        }

        if let approvalChoice = AgenticApprovalChoice(
            rawValue: choice.id
        ) {
            return approvalChoice
        }

        throw TestFlowInteractionError.unknown_choice(
            key: "approval-choice",
            value: choice.id,
            available: AgenticApprovalChoice.allCases.map(\.title)
        )
    }

    func renderDetails(
        _ prompt: AgenticApprovalPrompt
    ) {
        let preflight = prompt.preflight
        var lines: [String] = [
            "",
            "staged intent details",
            "",
            "title: \(prompt.title)",
            "tool: \(prompt.toolName)",
            "requirement: \(prompt.requirement.rawValue)",
            "risk: \(preflight.risk.rawValue)",
            "summary: \(preflight.summary)"
        ]

        if let toolCall = prompt.toolCall {
            lines.append(
                "tool call id: \(toolCall.id)"
            )
        }

        if let workspaceRoot = preflight.workspaceRoot {
            lines.append(
                "workspace: \(workspaceRoot)"
            )
        }

        if !preflight.rootIDs.isEmpty {
            lines.append(
                "roots: \(preflight.rootIDs.joined(separator: ", "))"
            )
        }

        if !preflight.capabilitiesRequired.isEmpty {
            lines.append(
                "capabilities: \(preflight.capabilitiesRequired.map(\.rawValue).joined(separator: ", "))"
            )
        }

        if !preflight.targetPaths.isEmpty {
            lines.append(
                "targets: \(preflight.targetPaths.joined(separator: ", "))"
            )
        }

        if let commandPreview = preflight.commandPreview {
            lines.append(
                "command: \(commandPreview)"
            )
        }

        if let diffPreview = preflight.diffPreview {
            lines.append(
                "diff preview: \(diffPreview.insertedLineCount) insertions, \(diffPreview.deletedLineCount) deletions, context \(diffPreview.contextLineCount)"
            )
        }

        if preflight.estimatedWriteCount > 0 {
            lines.append(
                "estimated writes: \(preflight.estimatedWriteCount)"
            )
        }

        if let estimatedByteCount = preflight.estimatedByteCount {
            lines.append(
                "estimated bytes: \(estimatedByteCount)"
            )
        }

        if let estimatedRuntimeSeconds = preflight.estimatedRuntimeSeconds {
            lines.append(
                "estimated runtime seconds: \(estimatedRuntimeSeconds)"
            )
        }

        if !preflight.sideEffects.isEmpty {
            lines.append(
                "side effects:"
            )
            lines.append(
                contentsOf: preflight.sideEffects.map {
                    "    - \($0)"
                }
            )
        }

        if !preflight.warnings.isEmpty {
            lines.append(
                "warnings:"
            )
            lines.append(
                contentsOf: preflight.warnings.map {
                    "    - \($0)"
                }
            )
        }

        lines.append(
            ""
        )

        write(
            lines.joined(
                separator: "\n"
            )
        )
    }

    func renderDiff(
        _ prompt: AgenticApprovalPrompt
    ) {
        guard let diffPreview = prompt.preflight.diffPreview,
              !diffPreview.isEmpty else {
            write(
                """

                no diff preview available

                """
            )

            return
        }

        let renderedDiff: String

        if let layout = diffPreview.layout,
           !layout.isEmpty {
            renderedDiff = TerminalDifferenceRenderer.render(
                layout,
                options: TerminalDifferenceRenderOptions(
                    base: DifferenceRenderOptions(
                        showHeader: true,
                        showUnchangedLines: false,
                        contextLineCount: diffPreview.contextLineCount
                    )
                )
            )
        } else {
            renderedDiff = diffPreview.text
        }

        guard !renderedDiff.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty else {
            write(
                """

                \(diffPreview.title ?? "diff preview")
                format: \(diffPreview.format)
                context lines: \(diffPreview.contextLineCount)
                changes: +\(diffPreview.insertedLineCount) -\(diffPreview.deletedLineCount)

                diff preview body was empty even though preflight reported a diff preview

                """
            )

            return
        }

        write(
            """

            \(diffPreview.title ?? "diff preview")
            format: \(diffPreview.format)
            context lines: \(diffPreview.contextLineCount)
            changes: +\(diffPreview.insertedLineCount) -\(diffPreview.deletedLineCount)

            \(renderedDiff)

            """
        )
    }

    func write(
        _ text: String
    ) {
        fputs(
            text,
            stderr
        )
    }
}
