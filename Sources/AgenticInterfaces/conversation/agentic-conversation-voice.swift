public enum AgenticConversationVoice {
    public enum Availability:
        Sendable,
        Hashable
    {
        case available
        case unconfigured
        case unavailable(String)
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
