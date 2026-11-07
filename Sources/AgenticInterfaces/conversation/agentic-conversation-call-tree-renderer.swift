import AgenticStandard
import Foundation
import Primitives
import Terminal

/// Conversation-only presentation of validated call occurrences.
/// A proposed tree must never be presented as an observed runtime trace.
public enum AgenticConversationCallTreeRenderer {
    public static func rows(
        _ output: Standard.Tools.CreateCallTree.Output,
        columns: Int,
        includeTitle: Bool = true
    ) -> [String] {
        let width = max(1, columns)
        var lines: [String] = includeTitle ? ["Call tree"] : []
        let occurrenceCount = output.tree.walk().reduce(0) { count, _ in count + 1 }
        lines.append("\(output.provenance.rawValue) · \(occurrenceCount) occurrences")

        func append(
            _ node: Tree<Standard.Tools.CreateCallTree.Occurrence>.Node,
            prefix: String,
            isLast: Bool
        ) {
            let branch = isLast ? "└── " : "├── "
            let occurrence = node.value
            let label = safe(occurrence.label)
            let id = safe(occurrence.id)
            let symbol = safe(occurrence.symbol_id)
            let name = label == symbol ? label : "\(label) (\(symbol))"
            lines.append(contentsOf: TerminalTextWrap.lines(
                "\(prefix)\(branch)\(name) [\(id)]", width: width
            ))
            let childPrefix = prefix + (isLast ? "    " : "│   ")
            if let value = occurrence.value,
               let data = try? JSONEncoder().encode(value),
               let json = String(data: data, encoding: .utf8) {
                lines.append(contentsOf: TerminalTextWrap.lines(
                    "\(childPrefix)value: \(safe(json))", width: width
                ))
            }
            for (index, child) in node.children.enumerated() {
                append(child, prefix: childPrefix, isLast: index == node.children.count - 1)
            }
        }

        for (index, root) in output.tree.roots.enumerated() {
            append(root, prefix: "", isLast: index == output.tree.roots.count - 1)
        }
        return lines
    }

    private static func safe(_ value: String) -> String {
        value.unicodeScalars.map { scalar in
            CharacterSet.controlCharacters.contains(scalar) ? " " : String(scalar)
        }.joined()
    }
}
