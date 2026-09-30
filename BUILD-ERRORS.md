# Build Errors Overview

Captured from a production (`release`) build. All errors are in `Sources/AgenticInterfaces/`.

---

## 1. Missing Types

These types are referenced but do not exist in scope — likely removed or renamed upstream.

| Type | Referenced In |
|---|---|
| `AgentToolExecutionContext` | `tool-host/agentic-tool-host.swift:106, 112` |
| `AgentToolPlan` | `tool-host/agentic-tool-host.swift:26, 34, 231, 244` |
| `AgentGuidelineRelation` | `tool-host/agentic-tool-host-invocation-contract.swift:137, 142` |
| `AgentGuidelineRelationship` | `tool-host/agentic-tool-host-invocation-contract.swift:623` |
| `AgentToolResultProcessing` | `tool-host/terminal-tool-host-receipt-renderer.swift:295` |
| `AgentToolResultObservation` | `tool-host/terminal-tool-host-receipt-renderer.swift:352, 367` |

## 2. `ToolCall` API Changes

The `ToolCall` initializer label changed from `name:` to `tool:`, and the parameter type changed from `String` to `ToolIdentifier`.

| Error | Location |
|---|---|
| Incorrect label `name:` → expected `tool:` | `agentic-tool-host-invocation-contract.swift:34, 121, 425` |
| `String` not convertible to `ToolIdentifier` | `agentic-tool-host-invocation-contract.swift:36, 123, 427` |
| `ToolCall` has no member `name` | `agentic-tool-host-invocation-contract.swift:227` |
| `ToolCall` has no member `name` | `agentic-tool-host-invocation-parser.swift:107` |

## 3. `ToolResult` API Changes

`ToolResult` no longer has a `processing` member.

| Location |
|---|
| `terminal-tool-host-receipt-renderer.swift:55` |
| `terminal-tool-host-receipt-renderer.swift:165` |

## 4. Missing Variable in Scope

| Error | Location |
|---|---|
| `realization` used in `if let` but never declared | `conversation/agentic-conversation-program.swift:150` |

## 5. Cascading Conformance Failures

These are not independent errors — they cascade from the missing types above.

| Struct | Failed Conformances | Root Cause |
|---|---|---|
| `AgenticToolHostPlan` | `Codable`, `Hashable`, `Equatable` | `guidelineRelations: [AgentGuidelineRelation]?` — type missing |
| `AgenticToolHostRequest` | `Codable`, `Hashable`, `Equatable` | `plan: AgentToolPlan?` — type missing |

## 6. Extra / Unresolved Arguments

| Error | Location |
|---|---|
| Extra argument `guidelineRelations` in `AgenticToolHostPlan.init` | `agentic-tool-host-invocation-contract.swift:159` |
| Extra argument `context` in `invoker.invoke` | `agentic-tool-host.swift:194, 210, 248` |
| Cannot infer `.invoke` contextual base | `agentic-tool-host-invocation-parser.swift:57, 76, 115` |
| Cannot infer `.batch` / `.call` contextual base | `agentic-tool-host.swift:232, 234` |
