import AgenticInterfaces
import DSL
import Foundation
import Reporting
import Search
import Terminal

private enum Failure: Error {
    case assertion(String)
}

@main
struct AgenticInterfacesReportingSmoke {
    static func main() throws {
        let dataset = try ReportDataset(
            id: "values",
            columns: [
                .init("month", kind: .text),
                .init("amount", kind: .decimal),
            ],
            rows: [
                .init(
                    values: [.text("January"), .decimal(100)],
                    sources: [.init(namespace: "entry", identifier: "42")]
                ),
                .init(values: [.text("February"), .decimal(-20)]),
            ],
            coverage: .complete
        )
        let report = try ReportDocument(
            title: "Verified report",
            datasets: [dataset],
            blocks: [
                .table(.init(
                    dataset: "values",
                    columns: ["month", "amount"],
                    title: "Monthly figures"
                )),
                .chart(.init(
                    dataset: "values", kind: .bar,
                    x: "month", y: "amount"
                )),
            ]
        )
        let presentation = AgenticHostConsoleDocumentPresentation(
            id: "report-document",
            runID: "report-run",
            stepID: "report-step",
            kind: .details,
            body: "canonical-report-fallback",
            structuredBody: .paragraph([.text("OLD-STRUCTURED-BODY")]),
            reportBody: report
        )
        let restored = try JSONDecoder().decode(
            AgenticHostConsoleDocumentPresentation.self,
            from: JSONEncoder().encode(presentation)
        )
        try expect(restored == presentation, "Typed report survives Codable roundtrip")
        try expect(restored.body == "canonical-report-fallback", "Raw body preserved")
        try expect(restored.reportBody?.datasets[0].rows[0].sources[0].identifier == "42", "Provenance preserved")

        let legacy = AgenticHostConsoleDocumentPresentation(
            id: "legacy", runID: "report-run",
            stepID: "report-step", kind: .details,
            body: "legacy raw content"
        )
        try expect(legacy.reportBody == nil, "Legacy constructor remains compatible")
        var legacyJSON = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(legacy)
        ) as! [String: Any]
        legacyJSON.removeValue(forKey: "reportBody")
        let decodedLegacy = try JSONDecoder().decode(
            AgenticHostConsoleDocumentPresentation.self,
            from: JSONSerialization.data(withJSONObject: legacyJSON)
        )
        try expect(decodedLegacy.reportBody == nil, "Legacy serialized documents decode")

        let snapshot = AgenticHostConsoleSnapshot(
            runs: [
                AgenticHostConsoleRunPresentation(
                    id: "report-run", title: "Report run",
                    state: .ready,
                    steps: [
                        AgenticHostConsoleStepPresentation(
                            id: "report-step", title: "Report",
                            state: .pending
                        )
                    ]
                )
            ],
            documents: [presentation]
        )
        var workflow = AgenticHostConsoleWorkflowControl(
            snapshot: snapshot,
            currentRunID: "report-run",
            currentStepID: "report-step"
        )
        _ = workflow.handle(.char("d"))
        try expect(workflow.currentDocument?.reportBody == report, "Typed report opens as existing document")
        var frame = TerminalFrame(rows: 35, columns: 100)
        workflow.render(
            into: &frame,
            in: TerminalRegion(rows: 35, columns: 100)
        )
        let visible = frame.resolved().spans.map(\.content).joined(separator: "\n")
        try expect(visible.contains("Verified report"), "Report rendered in console")
        try expect(visible.contains("Monthly figures"), "Typed table rendered")
        try expect(visible.contains("January"), "Dataset values rendered")
        try expect(!visible.contains("OLD-STRUCTURED-BODY"), "Report takes precedence over structured fallback")
        try expect(!visible.contains("canonical-report-fallback"), "Raw body is not substituted for report")
        print("AgenticInterfaces reporting smoke: passed")
    }

    static func expect(_ value: @autoclosure () -> Bool, _ message: String) throws {
        guard value() else { throw Failure.assertion(message) }
    }
}
