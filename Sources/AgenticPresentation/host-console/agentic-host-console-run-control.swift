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
    case stop_after_iteration
    case stop_urgent

    public var title: String {
        switch self {
        case .execute_run:
            return "Execute Run"

        case .execute_step_and_wait:
            return "Execute Step and Wait"

        case .pause:
            return "Pause"

        case .stop_after_iteration:
            return "Stop After Iteration"

        case .stop_urgent:
            return "Stop Urgently"
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

        case .stop_after_iteration:
            return "Finish the current agent iteration, including already-started tool work, then stop before the next model turn."

        case .stop_urgent:
            return "Stop at the earliest safe boundary. Streaming model output may stop immediately; an already-running effectful tool is allowed to settle first."
        }
    }

    public var isStopControl: Bool {
        switch self {
        case .stop_after_iteration,
             .stop_urgent:
            return true

        case .execute_run,
             .execute_step_and_wait,
             .pause:
            return false
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
                .stop_after_iteration,
                .stop_urgent,
            ]

        case .ready:
            return [
                .execute_run,
                .execute_step_and_wait,
            ]

        case .paused:
            return [
                .execute_run,
                .execute_step_and_wait,
                .stop_urgent,
            ]

        case .pause_pending,
             .awaitingApproval,
             .onHold:
            return [
                .stop_urgent,
            ]

        case .interrupted,
             .completed,
             .failed:
            return []
        }
    }
}
