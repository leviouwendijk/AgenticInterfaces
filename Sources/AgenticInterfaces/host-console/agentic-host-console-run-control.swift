public enum AgenticHostConsoleRunControl:
    String,
    Sendable,
    Codable,
    Hashable,
    CaseIterable
{
    case execute_run
    case execute_step_and_wait
    case pause

    public var title: String {
        switch self {
        case .execute_run:
            return "Execute Run"

        case .execute_step_and_wait:
            return "Execute Step and Wait"

        case .pause:
            return "Pause"
        }
    }

    public var summary: String {
        switch self {
        case .execute_run:
            return "Execute the remaining ToolPlan continuously until completion or a semantic interruption."

        case .execute_step_and_wait:
            return "Execute one authored ToolPlan step and pause at the next safe boundary."

        case .pause:
            return "Pause after the currently executing ToolPlan step finishes."
        }
    }

    public static var startControls: [Self] {
        [
            .execute_run,
            .execute_step_and_wait,
        ]
    }
}

public extension AgenticHostConsoleRunState {
    var executionControls: [AgenticHostConsoleRunControl] {
        switch self {
        case .active:
            return [
                .pause,
            ]

        case .ready,
             .paused:
            return [
                .execute_run,
                .execute_step_and_wait,
            ]

        case .pause_pending,
             .awaitingApproval,
             .onHold,
             .completed,
             .failed:
            return []
        }
    }
}
