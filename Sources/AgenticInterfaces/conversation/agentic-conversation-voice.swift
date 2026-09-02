public enum AgenticConversationVoice {
    public enum Availability:
        Sendable,
        Hashable
    {
        case available
        case unconfigured
        case unavailable(String)
    }

    public struct Status:
        Sendable,
        Hashable
    {
        public var elapsedSeconds: Double
        public var level: Double?

        public init(
            elapsedSeconds: Double,
            level: Double? = nil
        ) {
            self.elapsedSeconds = max(
                0,
                elapsedSeconds
            )
            self.level = level
        }
    }

    public enum State:
        Sendable,
        Hashable
    {
        case idle
        case recording
        case transcribing
        case failed(String)
    }
}