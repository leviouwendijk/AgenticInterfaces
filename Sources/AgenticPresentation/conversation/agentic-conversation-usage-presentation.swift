import Agentic
import Foundation

/// UI-only projection of canonical Core cost records. The Host supplies run-ID
/// keyed records; this type never estimates tokens or prices an invocation.
public struct AgenticConversationUsage: Sendable, Hashable {
    public var records: [String: AgentCostRecord]

    public init(records: [String: AgentCostRecord] = [:]) {
        self.records = records
    }

    public var projections: [AgentCostProjection] {
        records.values.flatMap { record in
            if record.turns.isEmpty {
                return [record.actual ?? record.projected].compactMap { $0 }
            }
            return record.turns.compactMap { $0.actual ?? $0.projected }
        }
    }

    public var actualTurns: Int {
        records.values.reduce(0) { count, record in
            count + (record.turns.isEmpty
                ? (record.actual == nil ? 0 : 1)
                : record.turns.filter { $0.actual != nil }.count)
        }
    }

    public var projectedTurns: Int {
        records.values.reduce(0) { count, record in
            count + (record.turns.isEmpty
                ? (record.actual == nil && record.projected != nil ? 1 : 0)
                : record.turns.filter { $0.actual == nil && $0.projected != nil }.count)
        }
    }

    public var inputTokens: Int {
        projections.reduce(0) { $0 + $1.usage.inputTokens }
    }

    public var outputTokens: Int {
        projections.reduce(0) { $0 + $1.usage.outputTokens }
    }

    public var cachedInputReadTokens: Int {
        projections.reduce(0) { $0 + $1.usage.cachedInputReadTokens }
    }

    public var cachedInputWriteTokens: Int {
        projections.reduce(0) { $0 + $1.usage.cachedInputWriteTokens }
    }

    public var reasoningOutputTokens: Int {
        projections.reduce(0) { $0 + $1.usage.reasoningOutputTokens }
    }

    /// Largest context any single request sent: how full the window got,
    /// as opposed to the cumulative totals billed across requests.
    public var peakContextTokens: Int {
        projections.map {
            $0.usage.inputTokens
                + $0.usage.cachedInputReadTokens
                + $0.usage.cachedInputWriteTokens
        }.max() ?? 0
    }

    /// Share of all input served from a prompt cache; nil before any input.
    public var cacheHitRate: Double? {
        let total = inputTokens + cachedInputReadTokens + cachedInputWriteTokens
        guard total > 0 else { return nil }
        return Double(cachedInputReadTokens) / Double(total)
    }

    /// Currency-separated amounts. Missing prices are not treated as zero-cost.
    public var amounts: [String: Int64] {
        var totals: [String: Int64] = [:]
        for projection in projections {
            guard let amount = projection.amount else { continue }
            let current = totals[amount.currencyCode, default: 0]
            let sum = current.addingReportingOverflow(amount.micros)
            totals[amount.currencyCode] = sum.overflow ? Int64.max : sum.partialValue
        }
        return totals
    }

    public var costDescription: String {
        guard !amounts.isEmpty else { return "not priced" }
        return amounts.keys.sorted().map { currency in
            let micros = amounts[currency, default: 0]
            return String(format: "%.4f %@", Double(micros) / 1_000_000, currency)
        }.joined(separator: " · ")
    }

    public var scopeDescription: String {
        "\(records.count) runs · \(actualTurns) actual turns · \(projectedTurns) projected turns"
    }

    /// Everything the requests read, cached or not: what a provider's
    /// per-request "prompt tokens" counts.
    public var totalInputTokens: Int {
        inputTokens + cachedInputReadTokens + cachedInputWriteTokens
    }

    /// Input and output across all requests: the sum of a provider's
    /// per-request token counts.
    public var totalTokens: Int {
        totalInputTokens + outputTokens
    }

    public var shortSummary: String {
        guard !projections.isEmpty else { return "usage not reported" }
        let provenance = projectedTurns > 0 ? " (includes estimates)" : ""
        var input = "in \(Self.compact(totalInputTokens))"
        if cachedInputReadTokens > 0 || cachedInputWriteTokens > 0 {
            var cache = ["\(Self.compact(cachedInputReadTokens)) cached"]
            if cachedInputWriteTokens > 0 {
                cache.append("\(Self.compact(cachedInputWriteTokens)) cache write")
            }
            input += " (" + cache.joined(separator: ", ") + ")"
        }
        return [
            "\(Self.compact(totalTokens)) tok",
            input,
            "out \(Self.compact(outputTokens))",
            "peak \(Self.compact(peakContextTokens))",
        ].joined(separator: " · ") + provenance
    }

    static func compact(_ tokens: Int) -> String {
        switch tokens {
        case 1_000_000...: String(format: "%.2fM", Double(tokens) / 1_000_000)
        case 1_000...: String(format: "%.1fk", Double(tokens) / 1_000)
        default: String(tokens)
        }
    }
}
