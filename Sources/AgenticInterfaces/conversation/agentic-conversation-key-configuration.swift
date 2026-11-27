import Terminal
import Surface

/// UI input preference. Key grammar and timing remain implemented by Swim.
public struct AgenticConversationKeyConfiguration: Sendable {
    public var leader: SurfaceInput.Key
    public var timeout: Duration

    public init(
        leader: SurfaceInput.Key = .space,
        timeout: Duration = .milliseconds(750)
    ) {
        self.leader = leader
        self.timeout = timeout
    }
}
