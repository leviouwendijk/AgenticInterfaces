import Agentic
import AgenticInterfaces
import Difference

/// Confirms that native tree+text layouts survive the preflight presentation seam.
enum AgenticNativeDifferenceRenderSmoke {
    enum Failure: Error {
        case missing_tree
        case missing_text
        case missing_tree_only
        case missing_text_only
        case missing_graph
        case missing_graph_only
    }

    static func run() throws {
        let text = DifferenceLayout(lines: [
            .init(role: .headerOld, text: "a/example.swift"),
            .init(role: .headerNew, text: "b/example.swift"),
            .init(role: .delete, text: "obsolete_line", coordinate: .init(old: 1)),
            .init(role: .insert, text: "replacement_line", coordinate: .init(new: 1)),
        ])
        let tree = TreeDifferenceLayout(lines: [
            .init(
                depth: 0,
                is_last_child: true,
                ancestor_last: [],
                change: .modified,
                label: "tree_only_marker.swift",
                id: "path:example"
            ),
        ])
        let combined = ToolPreflight.Preview.Difference(layout: text, tree: tree)
        let rendered = AgenticMutationDifferenceRenderer.render(combined)
        guard rendered.contains("tree_only_marker.swift") else { throw Failure.missing_tree }
        guard rendered.contains("replacement_line") else { throw Failure.missing_text }
        let tree_only = AgenticMutationDifferenceRenderer.render(
            .init(layout: .init(lines: []), tree: tree)
        )
        guard tree_only.contains("tree_only_marker.swift") else { throw Failure.missing_tree_only }
        let text_only = AgenticMutationDifferenceRenderer.render(
            .init(layout: text)
        )
        guard text_only.contains("replacement_line") else { throw Failure.missing_text_only }

        let graph = GraphDifferenceLayout(
            nodes: [
                .init(
                    id: "guest",
                    change: .added,
                    before: nil,
                    after: .init(label: "Guest VLAN")
                ),
                .init(
                    id: "wan",
                    change: .unchanged,
                    before: .init(label: "WAN"),
                    after: .init(label: "WAN")
                ),
            ],
            edges: [
                .init(
                    id: "allow",
                    change: .added,
                    before: nil,
                    after: .init(
                        endpoints: .init(source: "guest", destination: "wan"),
                        presentation: .init(label: "allow HTTPS")
                    )
                ),
            ]
        )
        let graph_only = AgenticMutationDifferenceRenderer.render(
            .init(graph: graph)
        )
        guard graph_only.contains("Guest VLAN"),
              graph_only.contains("guest ──▶ wan") else {
            throw Failure.missing_graph_only
        }
        let all = AgenticMutationDifferenceRenderer.render(
            .init(layout: text, tree: tree, graph: graph)
        )
        guard all.contains("tree_only_marker.swift"),
              all.contains("replacement_line"),
              all.contains("guest ──▶ wan") else {
            throw Failure.missing_graph
        }
    }
}
