import Agentic
import AgenticPresentation
import Terminal
import Foundation
public struct TerminalAgenticRunPresenter: AgenticRunPresenter {
    public var stream: TerminalStream
    public var sinks: [any AgenticInterfaceEventSink]
    public var theme: TerminalTheme
    public var showsVerboseEvents: Bool

    public init(
        stream: TerminalStream = .standardError,
        sinks: [any AgenticInterfaceEventSink] = [],
        theme: TerminalTheme = .agentic,
        showsVerboseEvents: Bool = false
    ) {
        self.stream = stream
        self.sinks = sinks
        self.theme = theme
        self.showsVerboseEvents = showsVerboseEvents
    }

    public func present(
        _ event: AgenticInterfaceEvent
    ) async throws {
        for sink in sinks {
            try await sink.record(
                event
            )
        }

        let rendered = render(
            event
        )

        guard !rendered.isEmpty else {
            return
        }

        Terminal.write(
            rendered,
            to: stream
        )
    }

    public func present(
        _ result: AgenticRun
    ) async throws {
        let rendered = render(
            result
        )

        guard !rendered.isEmpty else {
            return
        }

        Terminal.write(
            rendered,
            to: stream
        )
    }
}

private extension TerminalAgenticRunPresenter {
    func render(
        _ result: AgenticRun
    ) -> String {
        switch result.state {
        case .awaiting_approval:
            var fields: [TerminalField] = [
                .init("session", result.sessionID),
                .init("awaiting", "approval"),
            ]

            if let toolName = result.toolName {
                fields.append(
                    .init("tool", toolName)
                )
            }

            if let summary = result.summary {
                fields.append(
                    .init("summary", summary)
                )
            }

            return block(
                title: "Run suspended",
                fields: fields
            )

        case .awaiting_user_input:
            return block(
                title: "Run suspended",
                fields: [
                    .init("session", result.sessionID),
                    .init("awaiting", "user input"),
                ]
            )

        case .awaiting_run_limit:
            return block(
                title: "Run suspended",
                fields: [
                    .init("session", result.sessionID),
                    .init("awaiting", "run limit"),
                ],
                body: result.summary
            )

        case .interrupted:
            return block(
                title: "Run stopped",
                fields: [
                    .init("session", result.sessionID),
                ],
                body: result.summary
            )

        case .completed:
            return block(
                title: "Run completed",
                fields: [
                    .init("session", result.sessionID),
                ],
                body: result.body ?? "<empty>"
            )

        case .active:
            return block(
                title: "Run result",
                fields: [
                    .init("session", result.sessionID),
                    .init("state", "active"),
                ]
            )
        }
    }

    func render(
        _ event: AgenticInterfaceEvent
    ) -> String {
        switch event {
        case .runStarted(let prompt):
            return block(
                title: "Agentic run",
                fields: [
                    .init("prompt", prompt),
                ]
            )

        case .functionCallProposed(let functionCall):
            return block(
                title: "Tool proposed",
                fields: [
                    .init("tool", functionCall.name),
                    .init("id", functionCall.id),
                ]
            )

        case .toolPreflight(let preflight):
            var fields: [TerminalField] = [
                .init("tool", preflight.tool.rawValue),
                .init("risk", preflight.risk.rawValue),
                .init("summary", preflight.summary),
            ]

            if !preflight.access.targets.isEmpty {
                fields.append(
                    .init(
                        "targets",
                        preflight.access.targets.joined(
                            separator: ", "
                        )
                    )
                )
            }

            return block(
                title: "Tool preflight",
                fields: fields
            )

        case .approvalRequested(let prompt):
            var fields: [TerminalField] = [
                .init("tool", prompt.toolName),
                .init("requirement", prompt.requirement.rawValue),
                .init("risk", prompt.preflight.risk.rawValue),
                .init("summary", prompt.preflight.summary),
            ]

            if let guidelines = AgenticGuidelinePresentation.summary(
                prompt.guidelineReferences
            ) {
                fields.append(
                    .init(
                        "guidelines",
                        guidelines
                    )
                )
            }

            return block(
                title: "Approval required",
                fields: fields
            )

        case .approvalChoice(let choice):
            guard showsVerboseEvents else {
                return ""
            }

            return block(
                title: "Approval menu choice",
                fields: [
                    .init("choice", choice.id),
                ]
            )

        case .approvalDecision(let decision):
            return block(
                title: "Approval decision",
                fields: [
                    .init("decision", decision.rawValue),
                ]
            )

        case .runStopped(let reason):
            return block(
                title: "Run stopped",
                fields: [
                    .init("reason", reason),
                ]
            )

        case .runCompleted(let summary):
            return block(
                title: "Run completed",
                body: summary
            )
        }
    }

    func block(
        title: String,
        fields: [TerminalField] = [],
        body: String? = nil
    ) -> String {
        TerminalBlock(
            title: title,
            fields: fields,
            body: body,
            theme: theme,
            layout: .agentic
        ).render(
            stream: stream
        )
    }
}


public struct TerminalApprovalPicker: Sendable {
    public var stream: TerminalStream
    public var presenter: (any AgenticRunPresenter)?
    public var theme: TerminalTheme

    public init(
        stream: TerminalStream = .standardError,
        presenter: (any AgenticRunPresenter)? = nil,
        theme: TerminalTheme = .agentic
    ) {
        self.stream = stream
        self.presenter = presenter
        self.theme = theme
    }

    public func pick(
        _ prompt: AgenticApprovalPrompt
    ) async throws -> AgenticHostConsole.Action {
        try await presenter?.present(
            .approvalRequested(
                prompt
            )
        )

        while true {
            let choice = try runMenu(
                prompt
            )

            try await presenter?.present(
                .approvalChoice(
                    choice
                )
            )

            switch choice {
            case .inspect_details:
                renderDetails(
                    prompt
                )

            case .show_diff:
                renderDiff(
                    prompt
                )

            default:
                return choice
            }
        }
    }
}

extension TerminalApprovalPicker: AgenticApprovalChoosing {
    public func choose(
        _ prompt: AgenticApprovalPrompt
    ) async throws -> AgenticHostConsole.Action {
        try await pick(
            prompt
        )
    }
}
