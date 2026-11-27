import Terminal
import Surface

/// Counted navigation (`23j`, `gg`, `G`, `ctrl-d`) for tree lists and settings
/// trees, over Surface's navigation grammar. Keys it does not consume go to
/// the list's own `handle`.
public struct AgenticListNavigator: Sendable {
    private var navigator = SurfaceBinding.Navigation()

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
        _ key: SurfaceInput.Key,
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
        _ key: SurfaceInput.Key,
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

    /// For flat lists: `event` is what the motion changed, if anything.
    /// Sideways motions pass, so `h`/`l` still move between panes.
    public mutating func handle<Item: Sendable, ID: Hashable & Sendable>(
        _ key: SurfaceInput.Key,
        list: inout SurfaceList.Control<Item, ID>,
        pageRows: Int,
        event: inout SurfaceList.Event<ID>?
    ) -> Bool {
        switch route(key, capturesInput: false) {
        case .move(.horizontal):
            return false
        case .move(let command):
            event = list.apply(command, pageRows: pageRows)
            return true
        case .consumed:
            event = nil
            return true
        case .passed:
            return false
        }
    }

    private enum Route {
        case move(SurfaceIntent.Navigation)
        case consumed
        case passed
    }

    private mutating func route(
        _ key: SurfaceInput.Key,
        capturesInput: Bool
    ) -> Route {
        // A typed filter owns every key.
        guard !capturesInput else {
            navigator.reset()
            return .passed
        }
        switch navigator.handle(key) {
        case .navigate(let command):
            return .move(command)
        case .pending, .cancelled:
            return .consumed
        case .unhandled:
            return .passed
        }
    }
}
