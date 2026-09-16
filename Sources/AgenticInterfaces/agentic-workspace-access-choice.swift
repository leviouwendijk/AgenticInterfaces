public enum AgenticWorkspaceAccessChoice:
    String,
    Sendable,
    Codable,
    Hashable,
    CaseIterable
{
    case grant_for_turn
    case grant_for_session
    case deny

    public var title: String {
        switch self {
        case .grant_for_turn:
            return "This turn"

        case .grant_for_session:
            return "This session"

        case .deny:
            return "Deny"
        }
    }

    public var summary: String {
        switch self {
        case .grant_for_turn:
            return "Grant the requested workspace access until the current turn ends."

        case .grant_for_session:
            return "Grant the requested workspace access for the current session."

        case .deny:
            return "Deny this workspace access request."
        }
    }
}
