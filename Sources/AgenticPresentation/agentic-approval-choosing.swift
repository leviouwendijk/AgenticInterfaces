public protocol AgenticApprovalChoosing: Sendable {
    func choose(
        _ prompt: AgenticApprovalPrompt
    ) async throws -> AgenticHostConsole.Action
}
