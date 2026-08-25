import Agentic
import AgenticInterfaces
import Foundation
import Primitives
import TestFlows

enum ToolHostTestCase {
    static func makeListDescribe() -> AgenticInterfaceTestCase {
        .init(
            id: "tool-host-list-describe",
            summary: "List and describe registered tools through AgenticToolHost."
        ) { _ in
            try await runListDescribe()
        }
    }

    static func makeJSONRoundtrip() -> AgenticInterfaceTestCase {
        .init(
            id: "tool-host-json-roundtrip",
            summary: "Round-trip tool-host request and response envelopes through JSON."
        ) { _ in
            try await runJSONRoundtrip()
        }
    }

    static func makePreflightNoExecution() -> AgenticInterfaceTestCase {
        .init(
            id: "tool-host-preflight-no-execution",
            summary: "Preflight a host tool call without executing it."
        ) { _ in
            try await runPreflightNoExecution()
        }
    }

    static func makeInvokeObserve() -> AgenticInterfaceTestCase {
        .init(
            id: "tool-host-invoke-observe",
            summary: "Invoke an observe tool through governed host-call execution."
        ) { _ in
            try await runInvokeObserve()
        }
    }

    static func makeInvokeApprovedReview() -> AgenticInterfaceTestCase {
        .init(
            id: "tool-host-invoke-approved-review",
            summary: "Route approval-gated host invocation through ToolApprovalHandler."
        ) { _ in
            try await runInvokeApprovedReview()
        }
    }
}

private extension ToolHostTestCase {
    static func runListDescribe() async throws {
        let probe = ToolHostProbe()
        let host = makeHost(
            risk: .observe,
            autonomyMode: .auto_observe,
            probe: probe
        )

        let listed = try await host.execute(
            .init(
                action: .list
            )
        )

        guard let definitions = listed.definitions else {
            throw toolHostAssertionFailure(
                "Expected list action to return tool definitions."
            )
        }

        try Expect.equal(
            definitions.map(\.name),
            [
                "tool_host_probe"
            ],
            "tool host lists exact registry definitions"
        )

        let described = try await host.execute(
            .init(
                action: .describe,
                name: "tool_host_probe"
            )
        )

        guard let definition = described.definition else {
            throw toolHostAssertionFailure(
                "Expected describe action to return one definition."
            )
        }

        try Expect.equal(
            definition.name,
            "tool_host_probe",
            "tool host describes named tool"
        )
    }

    static func runJSONRoundtrip() async throws {
        let request = AgenticToolHostRequest(
            action: .describe,
            name: "tool_host_probe"
        )

        let requestData = try AgenticToolHostJSON.encode(
            request
        )

        let decodedRequest = try AgenticToolHostJSON.decodeRequest(
            requestData
        )

        try Expect.equal(
            decodedRequest,
            request,
            "tool host request JSON roundtrip"
        )

        let probe = ToolHostProbe()
        let host = makeHost(
            risk: .observe,
            autonomyMode: .auto_observe,
            probe: probe
        )

        let envelope = try await host.execute(
            decodedRequest
        )

        let envelopeData = try AgenticToolHostJSON.encode(
            envelope
        )

        let decodedEnvelope = try AgenticToolHostJSON.decodeEnvelope(
            envelopeData
        )

        try Expect.equal(
            decodedEnvelope,
            envelope,
            "tool host envelope JSON roundtrip"
        )

        let json = try AgenticToolHostJSON.encodeString(
            envelope
        )

        try Expect.equal(
            json.contains("\"action\":\"describe\""),
            true,
            "machine JSON includes action"
        )

        try Expect.equal(
            json.contains("\"tool_host_probe\""),
            true,
            "machine JSON includes tool identifier"
        )
    }

    static func runPreflightNoExecution() async throws {
        let probe = ToolHostProbe()
        let host = makeHost(
            risk: .observe,
            autonomyMode: .auto_observe,
            probe: probe
        )
        let call = try makeCall(
            marker: "preflight"
        )

        let envelope = try await host.execute(
            .init(
                action: .preflight,
                call: call
            )
        )

        guard let review = envelope.review else {
            throw toolHostAssertionFailure(
                "Expected preflight action to return review."
            )
        }

        let executionCount = await probe.count()

        try Expect.equal(
            review.call,
            call,
            "preflight retains exact AgentToolCall"
        )

        try Expect.equal(
            review.requirement,
            .no_approval_needed,
            "observe preflight is automatically allowed"
        )

        try Expect.equal(
            executionCount,
            0,
            "preflight never executes"
        )
    }

    static func runInvokeObserve() async throws {
        let probe = ToolHostProbe()
        let host = makeHost(
            risk: .observe,
            autonomyMode: .auto_observe,
            probe: probe
        )
        let call = try makeCall(
            marker: "observe"
        )

        let envelope = try await host.execute(
            .init(
                action: .invoke,
                call: call
            )
        )

        guard
            let invocation = envelope.invocation,
            let toolResult = invocation.toolResult
        else {
            throw toolHostAssertionFailure(
                "Expected observe host invocation to execute."
            )
        }

        let output = try JSONToolBridge.decode(
            ToolHostProbeOutput.self,
            from: toolResult.output
        )

        let executionCount = await probe.count()

        try Expect.equal(
            invocation.decision,
            .approved,
            "observe host invocation approved"
        )

        try Expect.equal(
            invocation.executed,
            true,
            "observe host invocation reports execution"
        )

        try Expect.equal(
            executionCount,
            1,
            "observe host invocation executes once"
        )

        try Expect.equal(
            output.executionMode,
            AgentToolExecutionMode.host_call.rawValue,
            "host transport preserves host_call provenance"
        )

        try Expect.equal(
            output.toolCallID,
            call.id,
            "host transport preserves tool call id"
        )

        try Expect.equal(
            output.sessionID,
            "tool-host-session",
            "host transport preserves session id"
        )

        try Expect.equal(
            output.source,
            "web-bridge",
            "host transport preserves metadata"
        )
    }

    static func runInvokeApprovedReview() async throws {
        let probe = ToolHostProbe()
        let host = makeHost(
            risk: .boundedmutate,
            autonomyMode: .auto_observe,
            probe: probe,
            approvalHandler: StaticToolHostApprovalHandler(
                decision: .approved
            )
        )
        let call = try makeCall(
            marker: "approved"
        )

        let envelope = try await host.execute(
            .init(
                action: .invoke,
                call: call
            )
        )

        guard let invocation = envelope.invocation else {
            throw toolHostAssertionFailure(
                "Expected approval-gated host invocation result."
            )
        }

        let executionCount = await probe.count()

        try Expect.equal(
            invocation.review.requirement,
            .needs_human_review,
            "bounded mutation enters human review"
        )

        try Expect.equal(
            invocation.decision,
            .approved,
            "host approval handler decision is honored"
        )

        try Expect.equal(
            invocation.executed,
            true,
            "approved host invocation executes"
        )

        try Expect.equal(
            executionCount,
            1,
            "approved host invocation executes exactly once"
        )
    }
}

private actor ToolHostProbe {
    private var executionCount = 0

    func record() {
        executionCount += 1
    }

    func count() -> Int {
        executionCount
    }
}

private struct ToolHostProbeTool: AgentTool {
    let identifier: AgentToolIdentifier = "tool_host_probe"
    let description = "Records one interface-hosted Agentic tool call."
    let risk: ActionRisk
    let probe: ToolHostProbe

    func preflight(
        input _: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> ToolPreflight {
        ToolPreflight(
            toolName: identifier.rawValue,
            risk: risk,
            workspaceRoot: workspace?.rootURL.path,
            summary: description
        )
    }

    func call(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> JSONValue {
        try await call(
            input: input,
            context: .init(
                workspace: workspace
            )
        )
    }

    func call(
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> JSONValue {
        let decoded = try JSONToolBridge.decode(
            ToolHostProbeInput.self,
            from: input
        )

        await probe.record()

        return try JSONToolBridge.encode(
            ToolHostProbeOutput(
                marker: decoded.marker,
                toolCallID: context.toolCallID,
                executionMode: context.executionMode.rawValue,
                sessionID: context.sessionID,
                source: context.metadata["source"]
            )
        )
    }
}

private struct ToolHostProbeInput: Sendable, Codable, Hashable {
    let marker: String
}

private struct ToolHostProbeOutput: Sendable, Codable, Hashable {
    let marker: String
    let toolCallID: String?
    let executionMode: String
    let sessionID: String?
    let source: String?
}

private struct StaticToolHostApprovalHandler: ToolApprovalHandler {
    let decision: ApprovalDecision

    func decide(
        on _: ToolPreflight,
        requirement _: ApprovalRequirement
    ) async throws -> ApprovalDecision {
        decision
    }
}

private extension ToolHostTestCase {
    static func makeHost(
        risk: ActionRisk,
        autonomyMode: AutonomyMode,
        probe: ToolHostProbe,
        approvalHandler: (any ToolApprovalHandler)? = nil
    ) -> AgenticToolHost {
        let registry = ToolRegistry(
            tools: [
                ToolHostProbeTool(
                    risk: risk,
                    probe: probe
                )
            ]
        )

        return AgenticToolHost(
            registry: registry,
            policy: .init(
                autonomyMode: autonomyMode
            ),
            context: .init(
                sessionID: "tool-host-session",
                metadata: [
                    "source": "web-bridge"
                ]
            ),
            approvalHandler: approvalHandler
        )
    }

    static func makeCall(
        marker: String
    ) throws -> AgentToolCall {
        AgentToolCall(
            id: "tool-host-\(marker)",
            name: "tool_host_probe",
            input: try JSONToolBridge.encode(
                ToolHostProbeInput(
                    marker: marker
                )
            )
        )
    }
}

private func toolHostAssertionFailure(
    _ message: String
) -> TestFlowAssertionFailure {
    TestFlowAssertionFailure(
        label: "tool host",
        message: message
    )
}
