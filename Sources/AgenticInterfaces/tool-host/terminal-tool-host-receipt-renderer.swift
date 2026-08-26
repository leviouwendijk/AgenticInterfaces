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
        let receipt =
            invocation.toolResult?.receipt

        var fields: [TerminalField] = [
            .init(
                "result",
                status(
                    invocation,
                    receipt: receipt
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
                receipt?.summary
                    ?? invocation.review.preflight.summary
            ),
        ]

        fields.append(
            contentsOf:
                clipboardFields(
                    copiedToClipboard
                )
        )

        return block(
            title: invocation.review.call.name,
            fields: fields,
            body: receiptBody(
                receipt
            )
        )
    }

    func render(
        _ plan: AgentToolPlanResult,
        copiedToClipboard: Bool
    ) -> String {
        var fields: [TerminalField] = [
            .init(
                "result",
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
                        separator: "\n"
                    )
        )
    }

    func recordBody(
        _ record: AgentToolPlanRecord
    ) -> String {
        let invocation = record.invocation
        let receipt =
            invocation?
                .toolResult?
                .receipt

        var details: [String] = [
            receipt?.status
                ?? record.outcome.rawValue
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

        if let summary = receipt?.summary,
           !summary.isEmpty
        {
            lines.append(
                "  \(summary)"
            )
        }

        if let receipt {
            lines.append(
                contentsOf:
                    receipt.items.map { item in
                        "  \(item.label)  \(item.value)"
                    }
            )
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

    func status(
        _ invocation: ToolInvocation.Result,
        receipt: AgentToolReceipt?
    ) -> String {
        if invocation.decision == .denied {
            return "denied"
        }

        if let receipt {
            return receipt.status
        }

        if invocation.toolResult?.isError == true {
            return "failed"
        }

        if invocation.executed {
            return "succeeded"
        }

        return invocation.decision.rawValue
    }

    func receiptBody(
        _ receipt: AgentToolReceipt?
    ) -> String? {
        guard let receipt,
              !receipt.items.isEmpty
        else {
            return nil
        }

        return receipt.items
            .map { item in
                "\(item.label)  \(item.value)"
            }
            .joined(
                separator: "\n"
            )
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
