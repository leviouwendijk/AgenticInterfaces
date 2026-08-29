import Agentic
import AgenticExecution
import Primitives
import Schema

/// Canonical model-facing Agentic tool call payload.
@JSONSchema
public struct AgenticToolHostCall:
    Sendable,
    Codable,
    Hashable
{
    /// Stable identifier for this tool call within the invocation or plan.
    public let id: String

    /// Exact identifier of one currently registered tool.
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

/// Execution metadata that remains outside the semantic tool input.
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

    /// Exact identifier of one currently registered tool.
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

    public func agentToolPlan() throws -> AgentToolPlan {
        let plan = AgentToolPlan(
            id: id,
            root: try root.agentToolPlanNode(),
            guidelineRelations: guidelineRelations ?? []
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

    public func agentToolPlanNode() throws -> AgentToolPlanNode {
        .init(
            kind: kind,
            call: call?.agentToolCall,
            execution: execution?.jsonvalue,
            children: try children.map {
                try $0.agentToolPlanNode()
            },
            onSuccess: try onSuccess.map {
                try $0.agentToolPlanNode()
            },
            onFailure: try onFailure.map {
                try $0.agentToolPlanNode()
            },
            onDenied: try onDenied.map {
                try $0.agentToolPlanNode()
            }
        )
    }
}

/// Runtime-specialized host invocation contract generated from the registered ToolRegistry.
public enum AgenticToolHostInvocationContract {
    public static func schema(
        capabilities: [AgentToolCapability]
    ) -> JSONSchema {
        let indexed = Array(
            capabilities.enumerated()
        )

        let callDefinitions = Dictionary(
            uniqueKeysWithValues: indexed.map {
                index,
                capability in

                (
                    callDefinitionName(
                        index: index,
                        capability: capability
                    ),
                    callSchema(
                        for: capability
                    )
                )
            }
        )

        let callUnion = JSONSchema.oneOf(
            indexed.map {
                index,
                capability in

                JSONSchema.reference(
                    "#/$defs/\(callDefinitionName(index: index, capability: capability))"
                )
            },
            description: "One AgentToolCall specialized to the tools registered for this host session."
        )

        let direct = JSONSchema.oneOf(
            capabilities.map {
                directInvocationSchema(
                    for: $0
                )
            },
            description: "One direct registered-tool invocation."
        )

        let batch = JSONSchema.array(
            description: "Non-empty batch of independent AgentToolCall values. Use AgentToolPlan when execution targeting or dependencies are needed.",
            items: .reference(
                "#/$defs/AgentToolCall"
            ),
            minItems: 1
        )

        let plan = planSchema()
        let planNode = planNodeSchema(
            indexedCapabilities: indexed
        )

        var definitions = callDefinitions
        definitions["AgentToolCall"] = callUnion
        definitions["AgentToolPlanNode"] = planNode

        return JSONSchema.oneOf(
            [
                direct,
                batch,
                plan,
            ],
            description: "Canonical JSON accepted by agentic host bridge: direct invocation, non-empty call batch, or recursive AgentToolPlan."
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
        if capability.supportsWorkspaceTargeting {
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
    static func semanticInputSchema(
        for capability: AgentToolCapability
    ) -> JSONSchema {
        if let schema = capability.semanticInputSchema {
            return schema
        }

        if capability.definition.inputSchema != nil {
            return .any.described(
                "This legacy tool has a lowered input schema but no semantic JSONSchema projection yet."
            )
        }

        return .object(
            description: "This tool declares no model-facing input fields.",
            additionalProperties: .disallowed
        )
    }

    static func callSchema(
        for capability: AgentToolCapability
    ) -> JSONSchema {
        specializeObject(
            AgenticToolHostCall.jsonschema,
            description: capability.definition.description
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
                    schema: semanticInputSchema(
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
            description: capability.definition.description
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
                    schema: semanticInputSchema(
                        for: capability
                    )
                )

            case "execution":
                guard capability.supportsWorkspaceTargeting else {
                    return nil
                }

                return replacing(
                    property,
                    schema: executionSchema()
                )

            default:
                return property
            }
        }
    }

    static func executionSchema() -> JSONSchema {
        specializeObject(
            AgenticToolHostExecution.jsonschema,
            description: "Invocation execution metadata. This changes the working location, not the workspace authority boundary."
        ) { property in
            guard property.name == "workspace" else {
                return property
            }

            return .init(
                name: property.name,
                schema: strictObject(
                    AgenticToolHostWorkspaceTarget.jsonschema
                ),
                required: true,
                description: property.description
            )
        }
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

    static func planNodeSchema(
        indexedCapabilities: [(offset: Int, element: AgentToolCapability)]
    ) -> JSONSchema {
        let callVariants = indexedCapabilities.map {
            index,
            capability in

            planCallNodeSchema(
                callDefinition: callDefinitionName(
                    index: index,
                    capability: capability
                ),
                capability: capability
            )
        }

        return .oneOf(
            callVariants + [
                planContainerNodeSchema(
                    kind: .sequence
                ),
                planContainerNodeSchema(
                    kind: .batch
                ),
            ],
            description: "Recursive AgentToolPlan node specialized to registered tool capabilities."
        )
    }

    static func planCallNodeSchema(
        callDefinition: String,
        capability: AgentToolCapability
    ) -> JSONSchema {
        let recursive = JSONSchema.reference(
            "#/$defs/AgentToolPlanNode"
        )

        return JSONSchema.object(
            description: "Call node for \(capability.definition.name).",
            additionalProperties: .disallowed
        ) {
            JSONSchema.property(
                "kind",
                schema: JSONSchema.constant(
                    JSONValue.string(
                        AgentToolPlanNodeKind.call.rawValue
                    )
                ),
                required: true
            )

            JSONSchema.property(
                "call",
                schema: JSONSchema.reference(
                    "#/$defs/\(callDefinition)"
                ),
                required: true
            )

            if capability.supportsWorkspaceTargeting {
                JSONSchema.property(
                    "execution",
                    schema: executionSchema()
                )
            }

            JSONSchema.array(
                "children",
                required: true,
                description: "Call nodes cannot contain ordinary children.",
                items: recursive,
                maxItems: 0
            )

            JSONSchema.array(
                "onSuccess",
                required: true,
                description: "Nodes to run only after this call succeeds.",
                items: recursive
            )

            JSONSchema.array(
                "onFailure",
                required: true,
                description: "Nodes to run only after this call fails.",
                items: recursive
            )

            JSONSchema.array(
                "onDenied",
                required: true,
                description: "Nodes to run only after this call is denied.",
                items: recursive
            )
        }
    }

    static func planContainerNodeSchema(
        kind: AgentToolPlanNodeKind
    ) -> JSONSchema {
        let recursive = JSONSchema.reference(
            "#/$defs/AgentToolPlanNode"
        )
        let emptyRecursiveArray = JSONSchema.array(
            items: recursive,
            maxItems: 0
        )

        return JSONSchema.object(
            description: "\(kind.rawValue) plan node.",
            additionalProperties: .disallowed
        ) {
            JSONSchema.property(
                "kind",
                schema: JSONSchema.constant(
                    JSONValue.string(
                        kind.rawValue
                    )
                ),
                required: true
            )

            JSONSchema.array(
                "children",
                required: true,
                description:
                    kind == .sequence
                        ? "Ordered success-gated child nodes."
                        : "Independent child nodes executed with batch semantics.",
                items: recursive
            )

            JSONSchema.property(
                "onSuccess",
                schema: emptyRecursiveArray,
                required: true,
                description: "Container nodes do not define outcome branches."
            )

            JSONSchema.property(
                "onFailure",
                schema: emptyRecursiveArray,
                required: true,
                description: "Container nodes do not define outcome branches."
            )

            JSONSchema.property(
                "onDenied",
                schema: emptyRecursiveArray,
                required: true,
                description: "Container nodes do not define outcome branches."
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

    static func callDefinitionName(
        index: Int,
        capability: AgentToolCapability
    ) -> String {
        let suffix = capability.definition.name.map { character in
            character.isLetter || character.isNumber
                ? character
                : "_"
        }

        return "ToolCall_\(index)_\(String(suffix))"
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

    static func strictObject(
        _ schema: JSONSchema
    ) -> JSONSchema {
        specializeObject(
            schema,
            description: schema.description
        ) {
            $0
        }
    }

    static func replacing(
        _ property: JSONSchema.Property,
        schema: JSONSchema
    ) -> JSONSchema.Property {
        .init(
            name: property.name,
            schema: schema,
            required: property.required,
            description: property.description
        )
    }

    static func exampleCapability(
        _ capabilities: [AgentToolCapability]
    ) -> AgentToolCapability? {
        capabilities
            .filter {
                $0.semanticInputSchema != nil
            }
            .min { lhs, rhs in
            if lhs.supportsWorkspaceTargeting != rhs.supportsWorkspaceTargeting {
                return lhs.supportsWorkspaceTargeting
            }

            let lhsRequired = requiredPropertyCount(
                semanticInputSchema(
                    for: lhs
                )
            )
            let rhsRequired = requiredPropertyCount(
                semanticInputSchema(
                    for: rhs
                )
            )

            if lhsRequired != rhsRequired {
                return lhsRequired < rhsRequired
            }

            return lhs.definition.name < rhs.definition.name
        }
    }

    static func requiredPropertyCount(
        _ schema: JSONSchema
    ) -> Int {
        guard case let .object(
            properties,
            _
        ) = schema.form
        else {
            return 1
        }

        return properties.filter(\.required).count
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
