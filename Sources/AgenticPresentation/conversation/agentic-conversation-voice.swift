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

    /// Where a transcription goes: decided when recording starts.
    public enum Target:
        Sendable,
        Hashable
    {
        /// The conversation composer's draft.
        case composer
        /// The active text field of the open answer menu.
        case userInput
    }

    public enum State:
        Sendable,
        Hashable
    {
        case idle
        case recording
        case transcribing
        case failed(String)

        public var isFailed: Bool {
            if case .failed = self {
                return true
            }
            return false
        }
    }
}