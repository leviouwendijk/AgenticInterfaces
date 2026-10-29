import Terminal

/// UI input preference. Key grammar and timing remain implemented by Swim.
public struct AgenticConversationKeyConfiguration: Sendable {
    public var leader: TerminalKey
    public var timeout: Duration

    public init(
        leader: TerminalKey = .space,
        timeout: Duration = .milliseconds(750)
    ) {
        self.leader = leader
        self.timeout = timeout
    }
}
