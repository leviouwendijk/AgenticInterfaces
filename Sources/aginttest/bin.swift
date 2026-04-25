import Agentic
import AgenticApple
import AgenticInterfaces
import Foundation

@main
struct AgenticInterfaceTest {
    static func main() async throws {
        let workspaceRoot = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath,
            isDirectory: true
        )

        let workspace = try AgentWorkspace(
            root: workspaceRoot
        )

        let targetPath = CommandLine.arguments.dropFirst().first
            ?? "agentic-interface-hello.txt"

        let generatedMiddle = try await AppleStructuredQuoteGenerator().generateMiddleFragment()

        let content = FileContentComposer.compose(
            workspaceRoot: workspaceRoot,
            generatedMiddle: generatedMiddle
        )

        let prompt = "write \(targetPath) with an Apple-generated philosophical middle fragment"

        var registry = ToolRegistry()
        try registry.register(
            WriteFileTool()
        )

        let historyStore = FileHistoryStore(
            sessionsdir: FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "agentic-interface-test-\(UUID().uuidString)",
                    isDirectory: true
                )
        )

        let presenter = TerminalAgenticRunPresenter()
        let picker = TerminalApprovalPicker(
            presenter: presenter
        )

        let runner = AgentRunner(
            adapter: ScriptedWriteModelAdapter(
                path: targetPath,
                content: content
            ),
            configuration: .init(
                maximumIterations: 4,
                autonomyMode: .auto_observe,
                historyPersistenceMode: .checkpointmutation
            ),
            toolRegistry: registry,
            workspace: workspace,
            historyStore: historyStore
        )

        try await presenter.present(
            .runStarted(
                prompt: prompt
            )
        )

        let initialResult = try await runner.run(
            AgentRequest(
                messages: [
                    .init(
                        role: .user,
                        text: prompt
                    )
                ]
            )
        )

        guard let pendingApproval = initialResult.pendingApproval else {
            try await presenter.present(
                initialResult
            )

            try await presenter.present(
                .runCompleted(
                    summary: "Run did not suspend for approval."
                )
            )
            return
        }

        try await presenter.present(
            .toolCallProposed(
                pendingApproval.toolCall
            )
        )

        try await presenter.present(
            .toolPreflight(
                pendingApproval.preflight
            )
        )

        try await presenter.present(
            initialResult
        )

        let choice = try await picker.pick(
            AgenticApprovalPrompt(
                pendingApproval: pendingApproval,
                title: "Runtime suspended for approval"
            )
        )

        switch choice {
        case .approve:
            try await presenter.present(
                .approvalDecision(
                    .approved
                )
            )

            let resumed = try await runner.resume(
                sessionID: initialResult.sessionID,
                approvalDecision: .approved,
                metadata: [
                    "summary": "approved from aginttest terminal interface"
                ]
            )

            try await presenter.present(
                resumed
            )

        case .deny:
            try await presenter.present(
                .approvalDecision(
                    .denied
                )
            )

            let resumed = try await runner.resume(
                sessionID: initialResult.sessionID,
                approvalDecision: .denied,
                metadata: [
                    "summary": "denied from aginttest terminal interface"
                ]
            )

            try await presenter.present(
                resumed
            )

        case .stopRun:
            try await presenter.present(
                .runStopped(
                    reason: "User stopped the run from the approval picker."
                )
            )

        case .inspectDetails,
             .showDiff:
            try await presenter.present(
                .runStopped(
                    reason: "Unexpected non-terminal picker choice escaped picker loop."
                )
            )
        }
    }
}

private struct PhilosophicalMiddleFragment: Sendable, Codable, Hashable {
    var title: String
    var quote: String
    var reflection: String
}

private struct AppleStructuredQuoteGenerator: Sendable {
    func generateMiddleFragment() async throws -> PhilosophicalMiddleFragment {
        let adapter = AppleFoundationModelAdapter()

        let response = try await adapter.respond(
            request: AgentRequest(
                messages: [
                    .init(
                        role: .system,
                        text: """
                        Return only one compact JSON object.

                        Schema:
                        {
                            "title": "string, 2 to 8 words",
                            "quote": "string, one original philosophical sentence, no attribution",
                            "reflection": "string, one plain sentence explaining the quote"
                        }

                        No markdown.
                        No code fences.
                        No extra keys.
                        """
                    ),
                    .init(
                        role: .user,
                        text: """
                        Generate a fresh philosophical middle fragment about attention, agency, and the ordinary world.

                        Make it feel spontaneous, but keep the JSON shape exact.
                        """
                    ),
                ]
            )
        )

        let text = response.message.content.text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let fragment = try decodeFragment(
            from: text
        )

        return try normalize(
            fragment
        )
    }
}

private extension AppleStructuredQuoteGenerator {
    func decodeFragment(
        from text: String
    ) throws -> PhilosophicalMiddleFragment {
        let data = Data(
            try extractJSONObject(
                from: text
            ).utf8
        )

        return try JSONDecoder().decode(
            PhilosophicalMiddleFragment.self,
            from: data
        )
    }

    func extractJSONObject(
        from text: String
    ) throws -> String {
        let trimmed = text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        if trimmed.hasPrefix("{"),
           trimmed.hasSuffix("}") {
            return trimmed
        }

        guard let start = trimmed.firstIndex(of: "{"),
              let end = trimmed.lastIndex(of: "}"),
              start <= end
        else {
            throw AppleGeneratedFragmentError.missingJSONObject(
                trimmed
            )
        }

        return String(
            trimmed[start...end]
        )
    }

    func normalize(
        _ fragment: PhilosophicalMiddleFragment
    ) throws -> PhilosophicalMiddleFragment {
        let title = try normalizedRequired(
            fragment.title,
            field: "title",
            maxCharacters: 80
        )

        let quote = try normalizedRequired(
            fragment.quote,
            field: "quote",
            maxCharacters: 220
        )

        let reflection = try normalizedRequired(
            fragment.reflection,
            field: "reflection",
            maxCharacters: 260
        )

        return .init(
            title: title,
            quote: quote,
            reflection: reflection
        )
    }

    func normalizedRequired(
        _ value: String,
        field: String,
        maxCharacters: Int
    ) throws -> String {
        let normalized = value
            .replacingOccurrences(
                of: "\n",
                with: " "
            )
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !normalized.isEmpty else {
            throw AppleGeneratedFragmentError.emptyField(
                field
            )
        }

        guard normalized.count <= maxCharacters else {
            throw AppleGeneratedFragmentError.fieldTooLong(
                field: field,
                count: normalized.count,
                maximum: maxCharacters
            )
        }

        return normalized
    }
}

private enum AppleGeneratedFragmentError: Error, Sendable, LocalizedError {
    case missingJSONObject(String)
    case emptyField(String)
    case fieldTooLong(field: String, count: Int, maximum: Int)

    var errorDescription: String? {
        switch self {
        case .missingJSONObject(let text):
            return "Apple generated output did not contain a JSON object: \(text)"

        case .emptyField(let field):
            return "Apple generated fragment field '\(field)' was empty."

        case .fieldTooLong(let field, let count, let maximum):
            return "Apple generated fragment field '\(field)' was too long: \(count)/\(maximum)."
        }
    }
}

private enum FileContentComposer {
    static func compose(
        workspaceRoot: URL,
        generatedMiddle: PhilosophicalMiddleFragment
    ) -> String {
        """
        hello from AgenticInterfaces

        This file was written through:
        model tool call -> AgentRunner suspension -> Terminal approval -> AgentRunner resume -> write_file.

        Apple-generated middle fragment
        --------------------------------
        \(generatedMiddle.title)

        "\(generatedMiddle.quote)"

        \(generatedMiddle.reflection)
        --------------------------------

        Workspace root: \(workspaceRoot.path)
        Generated at: \(Date().formatted(.iso8601))

        """
    }
}

private struct ScriptedWriteModelAdapter: AgentModelAdapter {
    let path: String
    let content: String

    var response: AgentModelResponseProviding {
        ScriptedWriteModelResponseProvider(
            path: path,
            content: content
        )
    }
}

private struct ScriptedWriteModelResponseProvider: AgentModelResponseProviding {
    let path: String
    let content: String

    func buffered(
        request: AgentRequest
    ) async throws -> AgentResponse {
        if let toolResult = latestToolResult(
            in: request
        ) {
            return .init(
                message: .init(
                    role: .assistant,
                    text: finalMessage(
                        from: toolResult
                    )
                ),
                stopReason: .end_turn
            )
        }

        let toolCall = AgentToolCall(
            id: "tool-call-write-apple-fragment",
            name: WriteFileTool.identifier.rawValue,
            input: try JSONToolBridge.encode(
                WriteFileToolInput(
                    path: path,
                    content: content
                )
            )
        )

        return .init(
            message: .init(
                role: .assistant,
                content: .init(
                    blocks: [
                        .tool_call(
                            toolCall
                        )
                    ]
                )
            ),
            stopReason: .tool_use
        )
    }

    func stream(
        request: AgentRequest
    ) -> AsyncThrowingStream<AgentStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let response = try await buffered(
                        request: request
                    )

                    continuation.yield(
                        .completed(
                            response
                        )
                    )

                    continuation.finish()
                } catch {
                    continuation.finish(
                        throwing: error
                    )
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

private extension ScriptedWriteModelResponseProvider {
    func latestToolResult(
        in request: AgentRequest
    ) -> AgentToolResult? {
        request.messages
            .flatMap(\.content.blocks)
            .compactMap { block -> AgentToolResult? in
                guard case .tool_result(let result) = block else {
                    return nil
                }

                return result
            }
            .last {
                $0.name == WriteFileTool.identifier.rawValue
            }
    }

    func finalMessage(
        from toolResult: AgentToolResult
    ) -> String {
        if toolResult.isError {
            return """
            write_file did not execute.

            result: \(toolResult.output)
            """
        }

        guard let output = try? JSONToolBridge.decode(
            WriteFileToolOutput.self,
            from: toolResult.output
        ) else {
            return """
            write_file executed, but the scripted harness could not decode the tool output.

            result: \(toolResult.output)
            """
        }

        return """
        write_file executed after approval.

        path: \(output.path)
        bytes: \(output.bytesWritten)
        changes: \(output.changeCount)
        diff: +\(output.diffSummary.insertedLineCount) -\(output.diffSummary.deletedLineCount)
        """
    }
}
