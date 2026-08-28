import AgenticExecution

public enum AgenticInterfaceApprovalResolution: Sendable, Codable, Hashable {
    case approved
    case denied
    case stopped(reason: String)

    public var approvalDecision: ApprovalDecision? {
        switch self {
        case .approved:
            return .approved

        case .denied:
            return .denied

        case .stopped:
            return nil
        }
    }
}

public protocol AgenticInterfaceApprovalDecider: Sendable {
    func decide(
        _ prompt: AgenticApprovalPrompt
    ) async throws -> AgenticInterfaceApprovalResolution
}

public struct ScriptedInterfaceApprovalDecider: AgenticInterfaceApprovalDecider {
    public var resolution: AgenticInterfaceApprovalResolution

    public init(
        resolution: AgenticInterfaceApprovalResolution
    ) {
        self.resolution = resolution
    }

    public static let approved = Self(
        resolution: .approved
    )

    public static let denied = Self(
        resolution: .denied
    )

    public static func stopped(
        reason: String = "Scripted interface approval decider stopped the run."
    ) -> Self {
        .init(
            resolution: .stopped(
                reason: reason
            )
        )
    }

    public func decide(
        _ prompt: AgenticApprovalPrompt
    ) async throws -> AgenticInterfaceApprovalResolution {
        _ = prompt
        return resolution
    }
}

extension TerminalApprovalPicker: AgenticInterfaceApprovalDecider {
    public func decide(
        _ prompt: AgenticApprovalPrompt
    ) async throws -> AgenticInterfaceApprovalResolution {
        let choice = try await pick(
            prompt
        )

        switch choice {
        case .approve:
            return .approved

        case .deny:
            return .denied

        case .stopRun:
            return .stopped(
                reason: "User stopped the run from the approval picker."
            )

        case .inspectDetails,
             .showDiff:
            return .stopped(
                reason: "Unexpected non-terminal picker choice escaped picker loop."
            )
        }
    }
}
