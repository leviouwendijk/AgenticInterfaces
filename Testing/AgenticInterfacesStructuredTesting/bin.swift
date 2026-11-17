import Agentic
import AgenticStandard
import AgenticInterfaces
import Foundation
import Primitives
import Reporting

private enum SmokeFailure: Error {
    case check(String)
}

@main
struct ConversationStructuredSmoke {
    static func main() throws {
        typealias GraphTool = Standard.Tools.CreateGraph
        let nodes: [GraphTool.Node] = [
            .init(id: "root", label: "Root", value: .null),
            .init(id: "a", value: .string("Branch A")),
            .init(id: "b", value: .string("Branch B")),
        ]
        let edges: [GraphTool.Edge] = [
            .init(id: "ra", source: "root", destination: "a", value: .null),
            .init(id: "rb", source: "root", destination: "b", value: .null),
        ]
        let refs: [GraphTool.Reference] = [.init(id: "main", target: "root")]
        func presented(_ input: GraphTool.Input) throws -> ReportDocument {
            guard let document = GraphTool().present(try GraphTool.evaluate(input), input: input) else {
                throw SmokeFailure.check("graph presentation")
            }
            return document
        }
        let graph = try presented(.init(nodes: nodes, edges: edges, references: refs))
        let graphView = AgenticConversationStructuredPresentation(
            id: "run:tool:graph",
            sourceCallID: "graph",
            iteration: 1,
            content: .document(graph)
        )
        try check(graphView.rows(columns: 80).joined(separator: "\n").contains("Root"), "graph lanes")
        let decoded = try JSONDecoder().decode(
            AgenticConversationStructuredPresentation.self,
            from: JSONEncoder().encode(graphView)
        )
        try check(decoded == graphView, "graph view Codable")
        try check(graphView.summary == "graph · 3 nodes · 2 edges", "graph summary")
        let callTreeOutput = try Standard.Tools.CreateCallTree.evaluate(.init(calls: [
            .init(id: "root", symbol_id: "GoalLoop"),
            .init(id: "first", symbol_id: "Search", parent_id: "root"),
            .init(id: "second", symbol_id: "Search", parent_id: "root", label: "Search again"),
        ]))
        let callTreeView = AgenticConversationStructuredPresentation(
            id: "run:tool:call-tree", sourceCallID: "call-tree", iteration: 4,
            content: .call_tree(callTreeOutput)
        )
        let callTreeRows = callTreeView.rows(columns: 80)
        let callTreeText = callTreeRows.joined(separator: "\n")
        try check(callTreeView.title == "Call tree", "call tree title")
        try check(callTreeView.summary.contains("3 occurrences · proposed"), "proposed call tree summary")
        try check(callTreeText.contains("GoalLoop") && callTreeText.contains("Search again"), "call tree inline content")
        try check(callTreeText.contains("[first]") && callTreeText.contains("[second]"), "occurrence IDs")
        try check(callTreeView.previewRows(columns: 80).count <= 12, "call tree preview is bounded")
        let roundtripTree = try JSONDecoder().decode(
            AgenticConversationStructuredPresentation.self,
            from: JSONEncoder().encode(callTreeView)
        )
        try check(roundtripTree == callTreeView, "call tree view Codable")
        let cyclic = try presented(.init(
            nodes: nodes,
            edges: edges + [.init(id: "cycle", source: "a", destination: "root", value: .null)],
            references: refs
        ))
        let cyclicView = AgenticConversationStructuredPresentation(
            id: "run:tool:cycle", sourceCallID: "cycle", iteration: 2,
            content: .document(cyclic)
        )
        try check(cyclicView.rows(columns: 60).joined(separator: "\n").contains("edge cycle"), "cyclic fallback")
        let merged = try presented(.init(
            nodes: nodes + [.init(id: "merge", value: .string("Merge"))],
            edges: edges + [
                .init(id: "am", source: "a", destination: "merge", value: .null),
                .init(id: "bm", source: "b", destination: "merge", value: .null),
            ],
            references: refs
        ))
        let mergedView = AgenticConversationStructuredPresentation(
            id: "run:tool:merged", sourceCallID: "merged", iteration: 2,
            content: .document(merged)
        )
        let preview = mergedView.previewRows(columns: 80)
        try check(preview.joined(separator: "\n").contains("Merge"), "Four-node graph is fully previewed")
        try check(preview.count <= 12, "Preview is bounded")
        let document = try ReportDocument(
            title: "Example",
            datasets: [],
            blocks: [.narrative(.paragraph([.text("Sample narrative")]))]
        )
        let reportView = AgenticConversationStructuredPresentation(
            id: "run:tool:report", sourceCallID: "report", iteration: 3,
            content: .document(document)
        )
        try check(reportView.rows(columns: 60).joined(separator: "\n").contains("Sample narrative"), "report renderer")
        try check(!reportView.rows(columns: 60, includeTitle: false).contains("Example"),
                  "Expanded inspection uses surrounding title")
        let longDocument = try ReportDocument(
            title: "Long report", datasets: [],
            blocks: [.narrative(.collection((0..<24).map { index in
                .paragraph([.text("Entry \(index)")])
            }))]
        )
        let longView = AgenticConversationStructuredPresentation(
            id: "run:tool:long", sourceCallID: "long", iteration: 3,
            content: .document(longDocument)
        )
        let longPreview = longView.previewRows(columns: 60)
        try check(longPreview.count == 12, "Long preview has row budget")
        try check(longPreview.last?.contains("more rows") == true, "Truncation is explicit")
        let history = AgenticConversationIterationPresentation(
            id: "run:iteration:1", number: 1, assistantBody: "Draft",
            events: ["assistant_response · draft"], callIDs: ["graph"]
        )
        let message = AgenticConversationMessagePresentation(
            id: "run-assistant", role: .assistant, body: "Final",
            attachments: [.structured(graphView), .structured(reportView), .structured(callTreeView), .trace(runID: "run")],
            iterations: [history]
        )
        try check(message.attachments.count == 4 && message.iterations[0].number == 1, "message attachment history")
        print("Conversation structured presentation smoke: passed")
    }

    static func check(_ condition: @autoclosure () -> Bool, _ description: String) throws {
        guard condition() else { throw SmokeFailure.check(description) }
    }
}
