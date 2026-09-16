public protocol AgenticWorkspaceAccessChoosing:
    Sendable
{
    func choose(
        _ prompt: AgenticWorkspaceAccessPrompt
    ) async throws -> AgenticWorkspaceAccessChoice
}
