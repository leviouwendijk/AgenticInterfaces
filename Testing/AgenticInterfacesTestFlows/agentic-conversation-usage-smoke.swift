import Agentic
import AgenticInterfaces

/// Verify read-only projection does not count a turn's estimate and actual
/// together or treat missing prices as free.
enum AgenticConversationUsageSmoke {
    enum Failure: Error { case projection, deduplication, currency }

    static func run() throws {
        let estimated = AgentCostProjection(
            status: .available, confidence: .estimated,
            usage: .init(inputTokens: 90, outputTokens: 20),
            amount: .init(currencyCode: "USD", micros: 1_000)
        )
        let reported = AgentCostProjection(
            status: .available, confidence: .providerReported,
            usage: .init(inputTokens: 80, outputTokens: 16),
            amount: .init(currencyCode: "USD", micros: 800)
        )
        let record = AgentCostRecord(
            runID: "run-a",
            turns: [
                .init(turnIndex: 0, projected: estimated, actual: reported),
                .init(turnIndex: 1, projected: estimated),
            ]
        )
        var usage = AgenticConversationUsagePresentation(records: ["run-a": record])
        guard usage.inputTokens == 170,
              usage.outputTokens == 36,
              usage.actualTurns == 1,
              usage.projectedTurns == 1,
              usage.shortSummary.contains("includes estimates")
        else { throw Failure.projection }
        usage.records["run-a"] = record
        guard usage.inputTokens == 170 else { throw Failure.deduplication }
        guard usage.amounts["USD"] == 1_800 else { throw Failure.currency }
    }
}
