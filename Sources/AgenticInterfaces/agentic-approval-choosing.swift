public protocol AgenticApprovalChoosing: Sendable {
    func choose(
        _ prompt: AgenticApprovalPrompt
    ) async throws -> AgenticApprovalChoice
}

extension TerminalApprovalPicker: AgenticApprovalChoosing {
    public func choose(
        _ prompt: AgenticApprovalPrompt
    ) async throws -> AgenticApprovalChoice {
        try await pick(
            prompt
        )
    }
}
