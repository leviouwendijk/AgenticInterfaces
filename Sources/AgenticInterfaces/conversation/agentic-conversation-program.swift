import AgenticPrograms
import Foundation
import Primitives

public struct AgenticConversationProgramInvocation:
    Sendable,
    Hashable
{
    public var program: AgentProgramIdentifier
    public var input: JSONValue

    public init(
        program: AgentProgramIdentifier,
        input: JSONValue
    ) {
        self.program = program
        self.input = input
    }
}

public enum AgenticConversationProgramExecutionOutcome:
    String,
    Sendable,
    Hashable
{
    case succeeded
    case failed
}

public struct AgenticConversationProgramStepPresentation:
    Sendable,
    Hashable
{
    public var index: Int
    public var title: String
    public var detail: String?
    public var failed: Bool
    public var durationMilliseconds: Int

    public init(
        index: Int,
        title: String,
        detail: String? = nil,
        failed: Bool = false,
        durationMilliseconds: Int = 0
    ) {
        self.index = index
        self.title = title
        self.detail = detail
        self.failed = failed
        self.durationMilliseconds = durationMilliseconds
    }
}

public struct AgenticConversationProgramExecutionPresentation:
    Sendable,
    Hashable
{
    public var id: String
    public var program: AgentProgramIdentifier
    public var title: String
    public var summary: String
    public var realization: AgentProgramRealizationIdentifier?
    public var outcome: AgenticConversationProgramExecutionOutcome
    public var input: String
    public var output: String?
    public var steps: [AgenticConversationProgramStepPresentation]
    public var failure: String?
    public var durationMilliseconds: Int

    public init(
        id: String,
        program: AgentProgramIdentifier,
        title: String,
        summary: String,
        realization: AgentProgramRealizationIdentifier? = nil,
        outcome: AgenticConversationProgramExecutionOutcome,
        input: String,
        output: String? = nil,
        steps: [AgenticConversationProgramStepPresentation] = [],
        failure: String? = nil,
        durationMilliseconds: Int = 0
    ) {
        self.id = id
        self.program = program
        self.title = title
        self.summary = summary
        self.realization = realization
        self.outcome = outcome
        self.input = input
        self.output = output
        self.steps = steps
        self.failure = failure
        self.durationMilliseconds = durationMilliseconds
    }

    public var transcriptTitle: String {
        switch outcome {
        case .succeeded:
            return "Program · completed"
        case .failed:
            return "Program · failed"
        }
    }

    public var transcriptBody: String {
        var lines = [title]

        for step in steps {
            let marker = step.failed ? "×" : "✓"
            var line = "\(marker) \(step.title)"

            if let detail = step.detail,
               !detail.isEmpty
            {
                line += " · \(detail)"
            }

            lines.append(line)
        }

        if let failure,
           !failure.isEmpty
        {
            lines.append(failure)
        }

        return lines.joined(separator: "\n")
    }

    public var detailsBody: String {
        var lines = [
            "program      \(program.rawValue)",
            "outcome      \(outcome.rawValue)",
            "duration     \(durationMilliseconds)ms",
        ]

        if let realization {
            lines.append(
                "realization  \(realization.rawValue)"
            )
        }

        lines.append("")
        lines.append("input")
        lines.append(input)

        if !steps.isEmpty {
            lines.append("")
            lines.append("steps")

            for step in steps {
                let marker = step.failed ? "×" : "✓"
                var line = "\(marker) \(step.title)"

                if let detail = step.detail,
                   !detail.isEmpty
                {
                    line += " · \(detail)"
                }

                line += " · \(step.durationMilliseconds)ms"
                lines.append(line)
            }
        }

        if let output {
            lines.append("")
            lines.append("output")
            lines.append(output)
        }

        if let failure {
            lines.append("")
            lines.append("failure")
            lines.append(failure)
        }

        return lines.joined(separator: "\n")
    }
}

public enum AgenticConversationProgramCommandError:
    Error,
    LocalizedError,
    Sendable,
    Hashable
{
    case missingProgramIdentifier
    case missingInput(String)
    case invalidInput(program: String, message: String)

    public var errorDescription: String? {
        switch self {
        case .missingProgramIdentifier:
            return "Program identifier is required after /program."

        case .missingInput(let program):
            return "Program '\(program)' requires an explicit JSON input value."

        case .invalidInput(let program, let message):
            return "Program '\(program)' input is not valid JSON: \(message)"
        }
    }
}

public enum AgenticConversationProgramCommand {
    public static func parse(
        _ source: String
    ) throws -> AgenticConversationProgramInvocation? {
        let source = source.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let command = "/program"

        guard source.hasPrefix(command) else {
            return nil
        }

        let commandEnd = source.index(
            source.startIndex,
            offsetBy: command.count
        )

        if commandEnd < source.endIndex,
           !source[commandEnd].isWhitespace
        {
            return nil
        }

        let remainder = String(
            source[commandEnd...]
        ).trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !remainder.isEmpty else {
            throw AgenticConversationProgramCommandError
                .missingProgramIdentifier
        }

        guard let separator = remainder.firstIndex(
            where: { character in
                character.isWhitespace
            }
        ) else {
            throw AgenticConversationProgramCommandError
                .missingInput(remainder)
        }

        let identifier = String(
            remainder[..<separator]
        ).trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let payload = String(
            remainder[separator...]
        ).trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !identifier.isEmpty else {
            throw AgenticConversationProgramCommandError
                .missingProgramIdentifier
        }

        guard !payload.isEmpty else {
            throw AgenticConversationProgramCommandError
                .missingInput(identifier)
        }

        do {
            let input = try JSONDecoder().decode(
                JSONValue.self,
                from: Data(payload.utf8)
            )

            return AgenticConversationProgramInvocation(
                program: AgentProgramIdentifier(
                    rawValue: identifier
                ),
                input: input
            )
        } catch {
            throw AgenticConversationProgramCommandError.invalidInput(
                program: identifier,
                message: error.localizedDescription
            )
        }
    }
}
