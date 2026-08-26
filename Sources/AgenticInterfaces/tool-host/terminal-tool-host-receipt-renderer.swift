import Agentic
import Terminal

public struct TerminalToolHostReceiptRenderer:
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

    public func render(
        _ envelope: AgenticToolHostEnvelope,
        copiedToClipboard: Bool = false
    ) -> String {
        if let invocation = envelope.invocation {
            return render(
                invocation,
                copiedToClipboard: copiedToClipboard
            )
        }

        if let plan = envelope.planResult {
            return render(
                plan,
                copiedToClipboard: copiedToClipboard
            )
        }

        return block(
            title: "Tool host result",
            fields: clipboardFields(
                copiedToClipboard
            )
        )
    }
}

private extension TerminalToolHostReceiptRenderer {
    func render(
        _ invocation: ToolInvocation.Result,
        copiedToClipboard: Bool
    ) -> String {
        let processing =
            invocation.toolResult?.processing
        let projection =
            processing?.projection

        var fields: [TerminalField] = [
            .init(
                "execution",
                executionStatus(
                    invocation
                )
            ),
            .init(
                "decision",
                invocation.decision.rawValue
            ),
            .init(
                "risk",
                invocation.review.preflight.risk.rawValue
            ),
            .init(
                "summary",
                projection?.summary
                    ?? invocation.review.preflight.summary
            ),
        ]

        if let projection {
            fields.insert(
                .init(
                    "operation",
                    projection.status
                ),
                at: 1
            )
        }

        fields.append(
            contentsOf:
                clipboardFields(
                    copiedToClipboard
                )
        )

        return block(
            title: invocation.review.call.name,
            fields: fields,
            body: processingBody(
                processing
            )
        )
    }

    func render(
        _ plan: AgentToolPlanResult,
        copiedToClipboard: Bool
    ) -> String {
        var fields: [TerminalField] = [
            .init(
                "execution",
                plan.outcome.rawValue
            ),
            .init(
                "executed",
                "\(plan.executedCount)"
            ),
            .init(
                "skipped",
                "\(plan.skippedCount)"
            ),
        ]

        fields.append(
            contentsOf:
                clipboardFields(
                    copiedToClipboard
                )
        )

        return block(
            title: "Tool plan",
            fields: fields,
            body:
                plan.records
                    .map(
                        recordBody
                    )
                    .joined(
                        separator: "\n\n"
                    )
        )
    }

    func recordBody(
        _ record: AgentToolPlanRecord
    ) -> String {
        let invocation = record.invocation
        let processing =
            invocation?
                .toolResult?
                .processing
        let projection =
            processing?
                .projection

        var details: [String] = [
            record.outcome.rawValue
        ]

        if let invocation {
            details.append(
                invocation.decision.rawValue
            )

            details.append(
                invocation.review
                    .preflight
                    .risk
                    .rawValue
            )
        }

        var lines = [
            "\(record.call.name)  \(details.joined(separator: " · "))"
        ]

        if let projection {
            lines.append(
                "  operation  \(projection.status)"
            )
        }

        if let summary = projection?.summary,
           !summary.isEmpty
        {
            lines.append(
                "  \(summary)"
            )
        }

        if let projection,
           !projection.facts.isEmpty
        {
            lines.append(
                contentsOf:
                    projection.facts.flatMap { fact in
                        projectionFactLines(
                            fact,
                            prefix: "  "
                        )
                    }
            )
        }

        if let processing,
           !processing.observations.isEmpty
        {
            lines.append("")

            for (
                index,
                observation
            ) in processing.observations.enumerated() {
                if index > 0 {
                    lines.append("")
                }

                lines.append(
                    contentsOf:
                        observationLines(
                            observation,
                            prefix: "  "
                        )
                )
            }
        }

        if let error = record.errorDescription,
           !error.isEmpty
        {
            lines.append(
                "  error  \(error)"
            )
        }

        if let reason = record.skipReason,
           !reason.isEmpty
        {
            lines.append(
                "  skipped  \(reason)"
            )
        }

        return lines.joined(
            separator: "\n"
        )
    }

    func executionStatus(
        _ invocation: ToolInvocation.Result
    ) -> String {
        if invocation.decision == .denied {
            return "denied"
        }

        if invocation.toolResult?.isError == true {
            return "failed"
        }

        if invocation.executed {
            return "succeeded"
        }

        return invocation.decision.rawValue
    }

    func processingBody(
        _ processing: AgentToolResultProcessing?
    ) -> String? {
        guard let processing else {
            return nil
        }

        var sections: [String] = []

        if let projection = processing.projection,
           !projection.facts.isEmpty
        {
            sections.append(
                projection.facts
                    .flatMap { fact in
                        projectionFactLines(
                            fact
                        )
                    }
                    .joined(
                        separator: "\n"
                    )
            )
        }

        sections.append(
            contentsOf:
                processing.observations.map { observation in
                    observationLines(
                        observation
                    )
                    .joined(
                        separator: "\n"
                    )
                }
        )

        guard !sections.isEmpty else {
            return nil
        }

        return sections.joined(
            separator: "\n\n"
        )
    }

    func projectionFactLines(
        _ fact: AgentToolResultProjection.Fact,
        prefix: String = ""
    ) -> [String] {
        labeledValueLines(
            label: fact.label,
            value: fact.value,
            prefix: prefix
        )
    }

    func observationLines(
        _ observation: AgentToolResultObservation,
        prefix: String = ""
    ) -> [String] {
        labeledValueLines(
            label:
                observation.label
                    ?? observationLabel(
                        observation.kind
                    ),
            value: observation.content,
            prefix: prefix
        )
    }

    func observationLabel(
        _ kind: AgentToolResultObservation.Kind
    ) -> String {
        switch kind {
        case .standard_output:
            return "stdout"

        case .standard_error:
            return "stderr"

        case .diagnostic:
            return "diagnostic"

        case .log:
            return "log"

        case .detail:
            return "detail"
        }
    }

    func labeledValueLines(
        label: String,
        value: String,
        prefix: String = ""
    ) -> [String] {
        var valueLines =
            value
                .split(
                    separator: "\n",
                    omittingEmptySubsequences: false
                )
                .map { line in
                    String(line)
                }

        while valueLines.first?.isEmpty == true {
            valueLines.removeFirst()
        }

        while valueLines.last?.isEmpty == true {
            valueLines.removeLast()
        }

        guard !valueLines.isEmpty else {
            return [
                "\(prefix)\(label)"
            ]
        }

        guard valueLines.count > 1 else {
            return [
                "\(prefix)\(label)  \(valueLines[0])"
            ]
        }

        return [
            "\(prefix)\(label)"
        ] + valueLines.map { line in
            "\(prefix)  \(line)"
        }
    }

    func clipboardFields(
        _ copied: Bool
    ) -> [TerminalField] {
        guard copied else {
            return []
        }

        return [
            .init(
                "clipboard",
                "result copied"
            ),
        ]
    }

    func block(
        title: String,
        fields: [TerminalField],
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
