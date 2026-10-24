import Foundation

/// Presentation DTO. This is a view of recorded identities, not a second
/// execution record or a substitute for checkpoint persistence.
public struct AgenticHostConsoleTraceNode: Sendable, Codable, Hashable, Identifiable {
    public let id: String
    public let title: String
    public let detail: String?
    public let reference_id: String?
    public let children: [Self]

    public init(
        id: String,
        title: String,
        detail: String? = nil,
        reference_id: String? = nil,
        children: [Self] = []
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.reference_id = reference_id
        self.children = children
    }
}

public struct AgenticHostConsoleTraceNavigation: Sendable {
    public struct Row: Sendable, Hashable {
        public let node: AgenticHostConsoleTraceNode
        public let depth: Int
        public let is_expanded: Bool
        public let is_selected: Bool
    }

    public enum Error: Swift.Error, Sendable, Equatable {
        case duplicate_id(String)
    }

    public private(set) var roots: [AgenticHostConsoleTraceNode]
    public private(set) var selected_id: String?
    public private(set) var collapsed_ids: Set<String>

    public init(roots: [AgenticHostConsoleTraceNode]) throws {
        try Self.validate(roots)
        self.roots = roots
        self.selected_id = roots.first?.id
        self.collapsed_ids = []
    }

    public var rows: [Row] {
        var result: [Row] = []
        func visit(_ nodes: [AgenticHostConsoleTraceNode], depth: Int) {
            for node in nodes {
                let expanded = !collapsed_ids.contains(node.id)
                result.append(.init(node: node, depth: depth,
                                    is_expanded: expanded, is_selected: selected_id == node.id))
                if expanded { visit(node.children, depth: depth + 1) }
            }
        }
        visit(roots, depth: 0)
        return result
    }

    public var selected_node: AgenticHostConsoleTraceNode? {
        rows.first(where: { $0.is_selected })?.node
    }

    public mutating func move(_ delta: Int) {
        let visible = rows
        guard !visible.isEmpty else { return }
        let current = visible.firstIndex { $0.node.id == selected_id } ?? 0
        selected_id = visible[max(0, min(visible.count - 1, current + delta))].node.id
    }

    public mutating func collapse() {
        guard let node = selected_node, !node.children.isEmpty else { return }
        collapsed_ids.insert(node.id)
    }

    public mutating func expand() {
        guard let node = selected_node else { return }
        collapsed_ids.remove(node.id)
    }

    public mutating func toggle() {
        guard let node = selected_node, !node.children.isEmpty else { return }
        if collapsed_ids.contains(node.id) { collapsed_ids.remove(node.id) }
        else { collapsed_ids.insert(node.id) }
    }

    /// Preserve selection/expansion when a suspended run publishes a newer snapshot.
    public mutating func update(roots: [AgenticHostConsoleTraceNode]) throws {
        try Self.validate(roots)
        let previous = selected_id
        let previously_collapsed = collapsed_ids
        self.roots = roots
        let all_ids = Self.identities(roots)
        collapsed_ids = previously_collapsed.intersection(all_ids)
        if let previous, rows.contains(where: { $0.node.id == previous }) {
            selected_id = previous
        } else {
            selected_id = roots.first?.id
        }
    }

    private static func identities(_ roots: [AgenticHostConsoleTraceNode]) -> Set<String> {
        var seen: Set<String> = []
        func visit(_ nodes: [AgenticHostConsoleTraceNode]) {
            for node in nodes { seen.insert(node.id); visit(node.children) }
        }
        visit(roots)
        return seen
    }

    private static func validate(_ roots: [AgenticHostConsoleTraceNode]) throws {
        var seen = Set<String>()
        func visit(_ nodes: [AgenticHostConsoleTraceNode]) throws {
            for node in nodes {
                guard seen.insert(node.id).inserted else { throw Error.duplicate_id(node.id) }
                try visit(node.children)
            }
        }
        try visit(roots)
    }
}
