/// UI projection of recorded execution evidence. No hidden reasoning is inferred.
public struct AgenticConversationIterationPresentation: Sendable, Hashable {
    public let id: String
    public let number: Int
    public let assistantBody: String?
    public let events: [String]
    public let callIDs: [String]

    public init(
        id: String,
        number: Int,
        assistantBody: String?,
        events: [String],
        callIDs: [String]
    ) {
        self.id = id
        self.number = number
        self.assistantBody = assistantBody
        self.events = events
        self.callIDs = callIDs
    }
}
