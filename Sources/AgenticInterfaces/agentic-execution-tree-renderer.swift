import Difference
import Primitives
import Terminal

/// Presentation-only traversal; identity and chronology stay in the runtime.
public enum AgenticExecutionTreeRenderer {
    public static func render<Value>(
        _ tree: Tree<Value>,
        label: (Value) -> String
    ) -> String {
        var lines: [String] = []
        func visit(_ nodes: [Tree<Value>.Node], prefix: String, at_root: Bool) {
            for (index, node) in nodes.enumerated() {
                let last = index == nodes.count - 1
                let branch = at_root ? "" : (last ? "└── " : "├── ")
                lines.append(prefix + branch + label(node.value))
                visit(
                    node.children,
                    prefix: prefix + (at_root ? "" : (last ? "    " : "│   ")),
                    at_root: false
                )
            }
        }
        visit(tree.roots, prefix: "", at_root: true)
        return lines.joined(separator: "\n")
    }

    public static func render(_ layout: TreeDifferenceLayout) -> String {
        TerminalDifferenceRenderer.render(layout)
    }
}
