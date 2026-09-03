import Agentic
import AgenticExecution
import Primitives
import Schema
import SchemaMacros

/// Canonical model-facing Agentic tool-call payload.
@JSONSchema
public struct AgenticToolHostCall:
    Sendable,
    Codable,
    Hashable
{
    /// Stable identifier for this tool call within the invocation or plan.
    public let id: String

    /// Exact identifier of one currently registered model-facing tool.
    public let name: String

    /// Input payload conforming to the selected tool's semantic input schema.
    public let input: JSONValue

    public init(
        id: String,
        name: String,
        input: JSONValue
    ) {
        self.id = id
        self.name = name
        self.input = input
    }

    public var agentToolCall: AgentToolCall {
        .init(
            id: id,
            name: name,
            input: input
        )
    }
}

/// Workspace working-location selection for one targetable invocation.
@JSONSchema
public struct AgenticToolHostWorkspaceTarget:
    Sendable,
    Codable,
    Hashable
{
    /// Existing directory beneath the host workspace authority root.
    public let subpath: String

    public init(
        subpath: String
    ) {
        self.subpath = subpath
    }
}

/// Execution metadata that remains outside semantic tool input.
@JSONSchema
public struct AgenticToolHostExecution:
    Sendable,
    Codable,
    Hashable
{
    /// Optional working location beneath the host workspace authority root.
    public let workspace: AgenticToolHostWorkspaceTarget?

    public init(
        workspace: AgenticToolHostWorkspaceTarget? = nil
    ) {
        self.workspace = workspace
    }

    public func toolExecution() throws
        -> ToolInvocation.Execution
    {
        try JSONToolBridge.decode(
            ToolInvocation.Execution.self,
            from: JSONToolBridge.encode(self)
        )
    }

    public var jsonvalue: JSONValue? {
        try? JSONToolBridge.encode(self)
    }
}

/// Canonical flattened direct invocation accepted by `agentic host bridge`.
@JSONSchema
public struct AgenticToolHostDirectInvocation:
    Sendable,
    Codable,
    Hashable
{
    /// Stable identifier for this tool call.
    public let id: String

    /// Exact identifier of one currently registered model-facing tool.
    public let name: String

    /// Input payload conforming to the selected tool's semantic input schema.
    public let input: JSONValue

    /// Optional execution metadata. Workspace targeting is admitted only for tools that advertise it.
    public let execution: AgenticToolHostExecution?

    public init(
        id: String,
        name: String,
        input: JSONValue,
        execution: AgenticToolHostExecution? = nil
    ) {
        self.id = id
        self.name = name
        self.input = input
        self.execution = execution
    }

    public var call: AgentToolCall {
        .init(
            id: id,
            name: name,
            input: input
        )
    }
}

/// Canonical recursive AgentToolPlan wire payload accepted by the host bridge.
public struct AgenticToolHostPlan:
    Sendable,
    Codable,
    Hashable
{
    public let id: String
    public let root: AgenticToolHostPlanNode
    public let guidelineRelations: [AgentGuidelineRelation]?

    public init(
        id: String,
        root: AgenticToolHostPlanNode,
        guidelineRelations: [AgentGuidelineRelation]? = nil
    ) {
        self.id = id
        self.root = root
        self.guidelineRelations = guidelineRelations
    }

    public func agentToolPlan(
        registry: ToolRegistry
    ) throws -> AgentToolPlan {
        let plan = AgentToolPlan(
            id: id,
            root:
                try root.agentToolPlanNode(
                    registry: registry
                ),
            guidelineRelations:
                guidelineRelations ?? []
        )

        try plan.validate()

        return plan
    }
}

/// Canonical recursive plan node. Execution is a sibling of `call`, never part of tool input.
public struct AgenticToolHostPlanNode:
    Sendable,
    Codable,
    Hashable
{
    public let kind: AgentToolPlanNodeKind
    public let call: AgenticToolHostCall?
    public let execution: AgenticToolHostExecution?
    public let children: [AgenticToolHostPlanNode]
    public let onSuccess: [AgenticToolHostPlanNode]
    public let onFailure: [AgenticToolHostPlanNode]
    public let onDenied: [AgenticToolHostPlanNode]

    public init(
        kind: AgentToolPlanNodeKind,
        call: AgenticToolHostCall? = nil,
        execution: AgenticToolHostExecution? = nil,
        children: [AgenticToolHostPlanNode] = [],
        onSuccess: [AgenticToolHostPlanNode] = [],
        onFailure: [AgenticToolHostPlanNode] = [],
        onDenied: [AgenticToolHostPlanNode] = []
    ) {
        self.kind = kind
        self.call = call
        self.execution = execution
        self.children = children
        self.onSuccess = onSuccess
        self.onFailure = onFailure
        self.onDenied = onDenied
    }

    public func agentToolPlanNode(
        registry: ToolRegistry
    ) throws -> AgentToolPlanNode {
        switch kind {
        case .call:
            guard let call,
                  children.isEmpty
            else {
                throw AgenticToolHostError
                    .invalidInvocationPayload(
                        "Call plan nodes require one call and cannot contain ordinary children."
                    )
            }

            let parsedCall = try registry
                .parseModelCall(
                    call.agentToolCall
                )

            if execution != nil,
               parsedCall
                    .capability
                    .execution
                    .workingLocation != .targetable
            {
                throw AgenticToolHostError
                    .invalidInvocationPayload(
                        "Tool '\(parsedCall.call.name)' does not support execution.workspace.subpath."
                    )
            }

            return .call(
                parsedCall.call,
                execution:
                    execution?.jsonvalue,
                onSuccess:
                    try onSuccess.map {
                        try $0.agentToolPlanNode(
                            registry: registry
                        )
                    },
                onFailure:
                    try onFailure.map {
                        try $0.agentToolPlanNode(
                            registry: registry
                        )
                    },
                onDenied:
                    try onDenied.map {
                        try $0.agentToolPlanNode(
                            registry: registry
                        )
                    }
            )

        case .sequence,
             .batch:
            guard call == nil,
                  execution == nil,
                  onSuccess.isEmpty,
                  onFailure.isEmpty,
                  onDenied.isEmpty
            else {
                throw AgenticToolHostError
                    .invalidInvocationPayload(
                        "\(kind.rawValue) plan nodes contain children only."
                    )
            }

            let nodes = try children.map {
                try $0.agentToolPlanNode(
                    registry: registry
                )
            }

            return
                kind == .sequence
                    ? .sequence(nodes)
                    : .batch(nodes)
        }
    }
}

/// Macro-derived nonrecursive structural source for recursive plan-node schemas.
///
/// Runtime composition replaces JSONValue placeholders with the recursive node
/// reference and exact registered-tool call variant. Core Agentic remains
/// Schema-free.
@JSONSchema
private struct AgenticToolHostPlanNodeSchemaShape:
    Codable
{
    let kind: String
    let call: JSONValue?
    let execution: AgenticToolHostExecution?
    let children: [JSONValue]
    let onSuccess: [JSONValue]
    let onFailure: [JSONValue]
    let onDenied: [JSONValue]
}

/// Runtime-specialized host invocation contract generated from the registered ToolRegistry.
public enum AgenticToolHostInvocationContract {
    public static func schema(
        capabilities: [AgentToolCapability]
    ) -> JSONSchema {
        let modelCapabilities = capabilities.filter(
            \.isModelFacing
        )

        let callDefinitions = Dictionary(
            uniqueKeysWithValues:
                modelCapabilities.map {
                    capability in

                    (
                        callDefinitionName(
                            capability
                        ),
                        callSchema(
                            for: capability
                        )
                    )
                }
        )

        let callUnion = callUnionSchema(
            modelCapabilities,
            description:
                "One AgentToolCall specialized to model-facing tools registered for this host session."
        )

        let direct = JSONSchema.oneOf(
            modelCapabilities.map {
                directInvocationSchema(
                    for: $0
                )
            },
            description:
                "One direct model-facing registered-tool invocation."
        )

        let batch = JSONSchema.array(
            description:
                "Non-empty batch of independent AgentToolCall values. Use AgentToolPlan when execution targeting or dependencies are needed.",
            items: .reference(
                "#/$defs/AgentToolCall"
            ),
            minItems: 1
        )

        let targetable =
            modelCapabilities.filter {
                $0.execution.workingLocation == .targetable
            }

        let nonTargetable =
            modelCapabilities.filter {
                $0.execution.workingLocation != .targetable
            }

        let plan = planSchema()
        let planNode = planNodeSchema(
            hasTargetableCalls:
                !targetable.isEmpty,
            hasNonTargetableCalls:
                !nonTargetable.isEmpty
        )

        var definitions = callDefinitions
        definitions["AgentToolCall"] = callUnion
        definitions["AgentToolExecution"] =
            executionSchema()
        definitions["AgentToolPlanNode"] =
            planNode

        if !targetable.isEmpty {
            definitions[
                "WorkspaceTargetableAgentToolCall"
            ] = callUnionSchema(
                targetable,
                description:
                    "Registered calls that admit execution.workspace.subpath."
            )
        }

        if !nonTargetable.isEmpty {
            definitions[
                "NonWorkspaceTargetableAgentToolCall"
            ] = callUnionSchema(
                nonTargetable,
                description:
                    "Registered calls that do not admit execution.workspace.subpath."
            )
        }

        return JSONSchema.oneOf(
            [
                direct,
                batch,
                plan,
            ],
            description:
                "Canonical JSON accepted by agentic host bridge: direct invocation, non-empty call batch, or recursive AgentToolPlan."
        )
        .defining(
            definitions
        )
    }

    public static func canonicalPlanExample(
        capabilities: [AgentToolCapability]
    ) -> AgentToolPlan? {
        guard let capability = exampleCapability(
            capabilities
        ) else {
            return nil
        }

        let input = exampleValue(
            for: semanticInputSchema(
                for: capability
            )
        )

        let call = AgentToolCall(
            id: "example-call",
            name: capability.definition.name,
            input: input
        )

        let execution: JSONValue?

        if capability.execution.workingLocation == .targetable {
            execution = AgenticToolHostExecution(
                workspace: .init(
                    subpath: "DependentPackage"
                )
            ).jsonvalue
        } else {
            execution = nil
        }

        return AgentToolPlan(
            id: "example-plan",
            root: .sequence(
                [
                    .call(
                        call,
                        execution: execution
                    ),
                ]
            )
        )
    }
}

private extension AgenticToolHostInvocationContract {
    static func modelCapabilities(
        _ capabilities: [AgentToolCapability]
    ) -> [AgentToolCapability] {
        capabilities.filter(
            \.isModelFacing
        )
    }

    static func semanticInputSchema(
        for capability: AgentToolCapability
    ) -> JSONSchema {
        guard case .modelFacing(
            let inputSchema
        ) = capability.modelContract else {
            preconditionFailure(
                "Host invocation schema requested for host-only tool '\(capability.definition.name)'."
            )
        }

        return inputSchema
    }

    static func callDefinitionName(
        _ capability: AgentToolCapability
    ) -> String {
        "toolcall_\(capability.definition.name)"
    }

    static func callUnionSchema(
        _ capabilities: [AgentToolCapability],
        description: String
    ) -> JSONSchema {
        JSONSchema.oneOf(
            capabilities.map {
                JSONSchema.reference(
                    "#/$defs/\(callDefinitionName($0))"
                )
            },
            description: description
        )
    }

    static func callSchema(
        for capability: AgentToolCapability
    ) -> JSONSchema {
        specializeObject(
            AgenticToolHostCall.jsonschema,
            description:
                capability.definition.description
        ) { property in
            switch property.name {
            case "name":
                return replacing(
                    property,
                    schema: .constant(
                        .string(
                            capability.definition.name
                        )
                    )
                )

            case "input":
                return replacing(
                    property,
                    schema:
                        semanticInputSchema(
                            for: capability
                        )
                )

            default:
                return property
            }
        }
    }

    static func directInvocationSchema(
        for capability: AgentToolCapability
    ) -> JSONSchema {
        specializeObject(
            AgenticToolHostDirectInvocation.jsonschema,
            description:
                capability.definition.description
        ) { property in
            switch property.name {
            case "name":
                return replacing(
                    property,
                    schema: .constant(
                        .string(
                            capability.definition.name
                        )
                    )
                )

            case "input":
                return replacing(
                    property,
                    schema:
                        semanticInputSchema(
                            for: capability
                        )
                )

            case "execution":
                guard capability
                    .execution
                    .workingLocation == .targetable
                else {
                    return nil
                }

                return property

            default:
                return property
            }
        }
    }

    static func executionSchema() -> JSONSchema {
        AgenticToolHostExecution.jsonschema
    }

    static func planSchema() -> JSONSchema {
        JSONSchema.object(
            description: "Recursive AgentToolPlan. Call-node execution is a sibling of call and is available only on targetable tool variants.",
            additionalProperties: .disallowed
        ) {
            JSONSchema.string(
                "id",
                required: true,
                description: "Stable plan identifier."
            )

            JSONSchema.property(
                "root",
                schema: JSONSchema.reference(
                    "#/$defs/AgentToolPlanNode"
                ),
                required: true,
                description: "Root recursive plan node."
            )

            JSONSchema.array(
                "guidelineRelations",
                description: "Optional guideline relations attached to the plan.",
                items: guidelineRelationSchema()
            )
        }
    }

    static func guidelineRelationSchema() -> JSONSchema {
        JSONSchema.object(
            additionalProperties: .disallowed
        ) {
            JSONSchema.string(
                "reference",
                required: true,
                description: "Stable guideline reference."
            )

            JSONSchema.string(
                "relationship",
                required: true,
                cases: AgentGuidelineRelationship.allCases.map(\.rawValue)
            )

            JSONSchema.string(
                "reasoning",
                description: "Optional rationale for the relation."
            )
        }
    }

    static func planNodeSchema(
        hasTargetableCalls: Bool,
        hasNonTargetableCalls: Bool
    ) -> JSONSchema {
        let shape =
            AgenticToolHostPlanNodeSchemaShape
                .jsonschema

        let recursiveArray = JSONSchema.array(
            description:
                "Recursive AgentToolPlanNode values.",
            items: .reference(
                "#/$defs/AgentToolPlanNode"
            )
        )
        let emptyRecursiveArray = JSONSchema.array(
            description:
                "This plan-node array must be empty for the selected node kind.",
            items: .reference(
                "#/$defs/AgentToolPlanNode"
            ),
            maxItems: 0
        )

        let sequence = specializeObject(
            shape,
            description:
                "Run children sequentially; later children execute only after earlier success."
        ) { property in
            switch property.name {
            case "kind":
                replacing(
                    property,
                    schema: .constant(
                        .string("sequence")
                    ),
                    isRequired: true
                )

            case "children":
                replacing(
                    property,
                    schema: recursiveArray,
                    isRequired: true
                )

            case "call",
                 "execution":
                nil

            case "onSuccess",
                 "onFailure",
                 "onDenied":
                replacing(
                    property,
                    schema: emptyRecursiveArray,
                    isRequired: true
                )

            default:
                property
            }
        }

        let batch = specializeObject(
            shape,
            description:
                "Run independent child nodes as a batch."
        ) { property in
            switch property.name {
            case "kind":
                replacing(
                    property,
                    schema: .constant(
                        .string("batch")
                    ),
                    isRequired: true
                )

            case "children":
                replacing(
                    property,
                    schema: recursiveArray,
                    isRequired: true
                )

            case "call",
                 "execution":
                nil

            case "onSuccess",
                 "onFailure",
                 "onDenied":
                replacing(
                    property,
                    schema: emptyRecursiveArray,
                    isRequired: true
                )

            default:
                property
            }
        }

        var variants: [JSONSchema] = [
            sequence,
            batch,
        ]

        if hasTargetableCalls {
            variants.append(
                callPlanNodeSchema(
                    shape: shape,
                    callReference:
                        "#/$defs/WorkspaceTargetableAgentToolCall",
                    allowsExecution: true,
                    recursiveArray: recursiveArray
                )
            )
        }

        if hasNonTargetableCalls {
            variants.append(
                callPlanNodeSchema(
                    shape: shape,
                    callReference:
                        "#/$defs/NonWorkspaceTargetableAgentToolCall",
                    allowsExecution: false,
                    recursiveArray: recursiveArray
                )
            )
        }

        return .oneOf(
            variants,
            description:
                "Recursive AgentToolPlan node. Call nodes specialize tool input and execution capability through shared registered-tool unions."
        )
    }

    static func callPlanNodeSchema(
        shape: JSONSchema,
        callReference: String,
        allowsExecution: Bool,
        recursiveArray: JSONSchema
    ) -> JSONSchema {
        let emptyRecursiveArray = JSONSchema.array(
            description:
                "Call plan nodes cannot contain ordinary children.",
            items: .reference(
                "#/$defs/AgentToolPlanNode"
            ),
            maxItems: 0
        )

        return specializeObject(
            shape,
            description:
                allowsExecution
                    ? "Invoke one workspace-targetable registered tool and optionally branch on outcome."
                    : "Invoke one non-workspace-targetable registered tool and optionally branch on outcome."
        ) { property in
            switch property.name {
            case "kind":
                replacing(
                    property,
                    schema: .constant(
                        .string("call")
                    ),
                    isRequired: true
                )

            case "call":
                replacing(
                    property,
                    schema: .reference(
                        callReference
                    ),
                    isRequired: true
                )

            case "execution":
                allowsExecution
                    ? replacing(
                        property,
                        schema: .reference(
                            "#/$defs/AgentToolExecution"
                        )
                    )
                    : nil

            case "children":
                replacing(
                    property,
                    schema: emptyRecursiveArray,
                    isRequired: true
                )

            case "onSuccess",
                 "onFailure",
                 "onDenied":
                replacing(
                    property,
                    schema: recursiveArray,
                    isRequired: true
                )

            default:
                property
            }
        }
    }

    static func specializeObject(
        _ schema: JSONSchema,
        description: String?,
        transform: (JSONSchema.Property) -> JSONSchema.Property?
    ) -> JSONSchema {
        guard case let .object(
            properties,
            _
        ) = schema.form
        else {
            return schema.described(
                description
            )
        }

        return JSONSchema(
            form: .object(
                properties: properties.compactMap(
                    transform
                ),
                additionalProperties: .disallowed
            ),
            description: description,
            definitions: schema.definitions
        )
    }

    static func replacing(
        _ property: JSONSchema.Property,
        schema: JSONSchema,
        isRequired: Bool? = nil
    ) -> JSONSchema.Property {
        .init(
            name: property.name,
            schema: schema,
            required: isRequired ?? property.required,
            description: property.description
        )
    }

    static func exampleCapability(
        _ capabilities: [AgentToolCapability]
    ) -> AgentToolCapability? {
        let modelFacing = modelCapabilities(
            capabilities
        )

        return modelFacing.first {
            $0.execution.workingLocation == .targetable
        } ?? modelFacing.first
    }

    static func exampleValue(
        for schema: JSONSchema
    ) -> JSONValue {
        exampleValue(
            for: schema,
            definitions: schema.definitions
        )
    }

    static func exampleValue(
        for schema: JSONSchema,
        definitions: [String: JSONSchema]
    ) -> JSONValue {
        let availableDefinitions = definitions.merging(
            schema.definitions
        ) { _, new in
            new
        }

        switch schema.form {
        case .any:
            return .object([:])

        case .null:
            return .null

        case .boolean:
            return .bool(false)

        case .integer(let cases):
            return .int(
                cases.first ?? 0
            )

        case .number(let cases):
            return .double(
                cases.first ?? 0
            )

        case .string(let cases):
            return .string(
                cases.first ?? "value"
            )

        case let .array(
            items,
            minItems,
            _,
            _
        ):
            let count = minItems ?? 0
            return .array(
                (0..<count).map { _ in
                    exampleValue(
                        for: items,
                        definitions: availableDefinitions
                    )
                }
            )

        case let .object(
            properties,
            _
        ):
            return .object(
                Dictionary(
                    uniqueKeysWithValues:
                        properties
                            .filter(\.required)
                            .map { property in
                                (
                                    property.name,
                                    exampleValue(
                                        for: property.schema,
                                        definitions: availableDefinitions
                                    )
                                )
                            }
                )
            )

        case .oneOf(let schemas):
            guard let first = schemas.first else {
                return .object([:])
            }

            return exampleValue(
                for: first,
                definitions: availableDefinitions
            )

        case .constant(let value):
            return value

        case .reference(let reference):
            let prefix = "#/$defs/"
            guard reference.hasPrefix(prefix) else {
                return .object([:])
            }

            let name = String(
                reference.dropFirst(
                    prefix.count
                )
            )

            guard let resolved = availableDefinitions[name] else {
                return .object([:])
            }

            return exampleValue(
                for: resolved,
                definitions: availableDefinitions
            )
        }
    }
}
