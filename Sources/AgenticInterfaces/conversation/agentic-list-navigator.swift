import SwimTerminal
import Terminal

/// Counted navigation (`23j`, `gg`, `G`, `ctrl-d`) for tree lists and settings
/// trees, so hosts get it without importing SwimTerminal. Keys it does not
/// consume go to the list's own `handle`.
public struct AgenticListNavigator: Sendable {
    private var navigator = SwimTerminalNavigator()

    public init() {}

    /// A pending count or `g`, for the footer.
    public var pendingText: String? {
        navigator.pendingText
    }

    /// Call when the view changes so a count cannot leak.
    public mutating func reset() {
        navigator.reset()
    }

    /// `true` when the key moved the cursor or extended or cancelled a pending
    /// sequence; the caller then skips the list's own handling.
    public mutating func handle<ID: Hashable & Sendable>(
        _ key: TerminalKey,
        list: inout TerminalTreeList<ID>
    ) -> Bool {
        switch route(key, capturesInput: list.capturesInput) {
        case .move(let command):
            list.apply(command)
            return true
        case .consumed:
            return true
        case .passed:
            return false
        }
    }

    public mutating func handle<ID: Hashable & Sendable>(
        _ key: TerminalKey,
        tree: inout TerminalSettingsTreeControl<ID>
    ) -> Bool {
        switch route(key, capturesInput: tree.list.capturesInput) {
        case .move(let command):
            tree.apply(command)
            return true
        case .consumed:
            return true
        case .passed:
            return false
        }
    }

    private enum Route {
        case move(TerminalNavigationCommand)
        case consumed
        case passed
    }

    private mutating func route(
        _ key: TerminalKey,
        capturesInput: Bool
    ) -> Route {
        // A typed filter owns every key.
        guard !capturesInput else {
            navigator.reset()
            return .passed
        }
        switch navigator.handle(key) {
        case .command(let command):
            return .move(command)
        case .pending, .cancelled:
            return .consumed
        case .unhandled:
            return .passed
        }
    }
}
