import Agentic
import AgenticExecution
import Primitives
import Schema

extension AgenticToolHostInvocationContract {
    static func diagnostics(
        _ value: JSONValue,
        capabilities: [AgentToolCapability]
    ) -> JSONDiagnostics {
        let contract = schema(
            capabilities: capabilities
        )

        guard case .oneOf(let forms) = contract.form,
              forms.count == 3
        else {
            return contract.diagnostics(
                value
            )
        }

        switch value {
        case .array(let values):
            return batchDiagnostics(
                values,
                contract: contract,
                batch: forms[1],
                capabilities: capabilities
            )

        case .object(let object):
            if isPlanNode(object) {
                return JSONDiagnostics(
                    [
                        JSONIssue(
                            kind: .missing,
                            path: JSONCodingPath(
                                [
                                    .key("root"),
                                ]
                            ),
                            reason: "Received an AgentToolPlan node as the top-level invocation. Wrap the node in an AgentToolPlan containing id and root."
                        ),
                    ]
                )
            }

            if object["root"] != nil {
                return JSONDiagnostics(
                    planCallIssues(
                        in: value,
                        path: JSONCodingPath(),
                        contract: contract,
                        capabilities: capabilities
                    )
                )
            }

            return directDiagnostics(
                value,
                object: object,
                direct: forms[0],
                contract: contract,
                capabilities: capabilities
            )

        default:
            return contract.diagnostics(
                value
            )
        }
    }
}

private extension AgenticToolHostInvocationContract {
    static func directDiagnostics(
        _ value: JSONValue,
        object: [String: JSONValue],
        direct: JSONSchema,
        contract: JSONSchema,
        capabilities: [AgentToolCapability]
    ) -> JSONDiagnostics {
        let structural = AgenticToolHostDirectInvocation
            .jsonschema
            .defining(
                contract.definitions
            )
            .diagnostics(
                value
            )

        guard case .string(let name) = object["name"] else {
            return structural
        }

        guard capabilities.contains(
            where: {
                $0.isModelFacing
                    && $0.definition.name == name
            }
        ) else {
            return JSONDiagnostics(
                structural.issues
                    + [
                        JSONIssue(
                            kind: .invalidValue,
                            path: JSONCodingPath(
                                [
                                    .key("name"),
                                ]
                            ),
                            reason: "No model-facing registered tool named '\(name)'."
                        ),
                    ]
            )
        }

        guard let branch = branch(
            named: name,
            in: direct
        ) else {
            return structural
        }

        return branch
            .defining(
                contract.definitions
            )
            .diagnostics(
                value
            )
    }

    static func batchDiagnostics(
        _ values: [JSONValue],
        contract: JSONSchema,
        batch: JSONSchema,
        capabilities: [AgentToolCapability]
    ) -> JSONDiagnostics {
        if values.isEmpty {
            return batch
                .defining(
                    contract.definitions
                )
                .diagnostics(
                    .array(values)
                )
        }

        var issues: [JSONIssue] = []

        for (
            index,
            value
        ) in values.enumerated() {
            let item = callDiagnostics(
                value,
                contract: contract,
                capabilities: capabilities
            )

            issues.append(
                contentsOf: prefixed(
                    item.issues,
                    by: [
                        .index(index),
                    ]
                )
            )
        }

        return JSONDiagnostics(
            issues
        )
    }

    static func callDiagnostics(
        _ value: JSONValue,
        contract: JSONSchema,
        capabilities: [AgentToolCapability]
    ) -> JSONDiagnostics {
        let structural = AgenticToolHostCall
            .jsonschema
            .defining(
                contract.definitions
            )
            .diagnostics(
                value
            )

        guard case .object(let object) = value,
              case .string(let name) = object["name"]
        else {
            return structural
        }

        guard capabilities.contains(
            where: {
                $0.isModelFacing
                    && $0.definition.name == name
            }
        ) else {
            return JSONDiagnostics(
                structural.issues
                    + [
                        JSONIssue(
                            kind: .invalidValue,
                            path: JSONCodingPath(
                                [
                                    .key("name"),
                                ]
                            ),
                            reason: "No model-facing registered tool named '\(name)'."
                        ),
                    ]
            )
        }

        guard let union = contract.definitions["AgentToolCall"],
              let branch = branch(
                named: name,
                in: union
              )
        else {
            return structural
        }

        return branch
            .defining(
                contract.definitions
            )
            .diagnostics(
                value
            )
    }

    static func planCallIssues(
        in value: JSONValue,
        path: JSONCodingPath,
        contract: JSONSchema,
        capabilities: [AgentToolCapability]
    ) -> [JSONIssue] {
        guard case .object(let object) = value else {
            return []
        }

        var issues: [JSONIssue] = []

        if let call = object["call"] {
            let callDiagnostics = callDiagnostics(
                call,
                contract: contract,
                capabilities: capabilities
            )

            issues.append(
                contentsOf: prefixed(
                    callDiagnostics.issues,
                    by: path.components
                        + [
                            .key("call"),
                        ]
                )
            )
        }

        for key in [
            "root",
            "children",
            "onSuccess",
            "onFailure",
            "onDenied",
        ] {
            guard let nested = object[key] else {
                continue
            }

            switch nested {
            case .object:
                issues.append(
                    contentsOf: planCallIssues(
                        in: nested,
                        path: JSONCodingPath(
                            path.components
                                + [
                                    .key(key),
                                ]
                        ),
                        contract: contract,
                        capabilities: capabilities
                    )
                )

            case .array(let values):
                for (
                    index,
                    child
                ) in values.enumerated() {
                    issues.append(
                        contentsOf: planCallIssues(
                            in: child,
                            path: JSONCodingPath(
                                path.components
                                    + [
                                        .key(key),
                                        .index(index),
                                    ]
                            ),
                            contract: contract,
                            capabilities: capabilities
                        )
                    )
                }

            default:
                break
            }
        }

        return issues
    }

    static func branch(
        named name: String,
        in schema: JSONSchema
    ) -> JSONSchema? {
        guard case .oneOf(let branches) = schema.form else {
            return nil
        }

        return branches.first {
            branch in

            guard case .object(let properties, _) = branch.form,
                  let property = properties.first(
                    where: {
                        $0.name == "name"
                    }
                  ),
                  case .constant(.string(let expected)) = property.schema.form
            else {
                return false
            }

            return expected == name
        }
    }

    static func isPlanNode(
        _ object: [String: JSONValue]
    ) -> Bool {
        object["root"] == nil
            && object["kind"] != nil
            && (
                object["children"] != nil
                    || object["call"] != nil
            )
    }

    static func prefixed(
        _ issues: [JSONIssue],
        by prefix: [JSONCodingPath.Component]
    ) -> [JSONIssue] {
        issues.map {
            issue in

            JSONIssue(
                kind: issue.kind,
                path: JSONCodingPath(
                    prefix
                        + issue.path.components
                ),
                reason: issue.reason
            )
        }
    }
}
