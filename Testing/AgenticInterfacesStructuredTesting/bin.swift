import Agentic
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
        typealias G = Graph<String, JSONValue, String, JSONValue>
        let graph = try G(
            nodes: [
                .init(id: "root", value: .string("Root")),
                .init(id: "a", value: .string("Branch A")),
                .init(id: "b", value: .string("Branch B")),
            ],
            edges: [
                .init(id: "ra", source: "root", destination: "a", value: .null),
                .init(id: "rb", source: "root", destination: "b", value: .null),
            ]
        )
        let refs = try ReferenceSet<String, String>(references: [
            .init(id: "main", target: "root")
        ])
        let graphView = AgenticConversationStructuredPresentation(
            id: "run:tool:graph",
            sourceCallID: "graph",
            iteration: 1,
            content: .graph(graph, refs)
        )
        try check(graphView.rows(columns: 80).joined(separator: "\n").contains("Root"), "graph lanes")
        let decoded = try JSONDecoder().decode(
            AgenticConversationStructuredPresentation.self,
            from: JSONEncoder().encode(graphView)
        )
        try check(decoded == graphView, "graph view Codable")
        let cyclic = try G(
            nodes: graph.nodes,
            edges: graph.edges + [.init(id: "cycle", source: "a", destination: "root", value: .null)]
        )
        let cyclicView = AgenticConversationStructuredPresentation(
            id: "run:tool:cycle", sourceCallID: "cycle", iteration: 2,
            content: .graph(cyclic, refs)
        )
        try check(cyclicView.rows(columns: 60).joined(separator: "\n").contains("edge cycle"), "cyclic fallback")
        let document = try ReportDocument(
            title: "Example",
            datasets: [],
            blocks: [.narrative(.paragraph([.text("Sample narrative")]))]
        )
        let reportView = AgenticConversationStructuredPresentation(
            id: "run:tool:report", sourceCallID: "report", iteration: 3,
            content: .report(document)
        )
        try check(reportView.rows(columns: 60).joined(separator: "\n").contains("Sample narrative"), "report renderer")
        let history = AgenticConversationIterationPresentation(
            id: "run:iteration:1", number: 1, assistantBody: "Draft",
            events: ["assistant_response · draft"], toolCallIDs: ["graph"]
        )
        let message = AgenticConversationMessagePresentation(
            id: "run-assistant", role: .assistant, body: "Final",
            attachments: [.structured(graphView), .structured(reportView), .trace(runID: "run")],
            iterations: [history]
        )
        try check(message.attachments.count == 3 && message.iterations[0].number == 1, "message attachment history")
        print("Conversation structured presentation smoke: passed")
    }

    static func check(_ condition: @autoclosure () -> Bool, _ description: String) throws {
        guard condition() else { throw SmokeFailure.check(description) }
    }
}
