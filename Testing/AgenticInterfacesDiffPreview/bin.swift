import Agentic
import AgenticIO
import AgenticInterfaces
import Foundation
import Path
import Terminal
import Workspace

@main
struct AgenticInterfacesDiffPreview {
    enum Failure: Error {
        case invalidWidth
        case missingDifference
        case unexpectedMutation(String)
    }

    static func main() async throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard !(arguments.contains("--direct") && arguments.contains("--embedded")) else {
            throw Failure.invalidWidth
        }
        let embedded = !arguments.contains("--direct")
        let widthArguments = arguments.filter { $0 != "--embedded" && $0 != "--direct" }
        let terminalSize = Terminal.size(for: .standardError)
        let columns: Int
        if widthArguments.isEmpty {
            columns = terminalSize.columns
        } else if widthArguments.count == 2, widthArguments[0] == "--width" {
            columns = Int(widthArguments[1]) ?? 0
        } else {
            throw Failure.invalidWidth
        }
        guard columns >= 40 else { throw Failure.invalidWidth }

        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "agentic-interfaces-diffpreview-\(UUID().uuidString)",
            isDirectory: true
        )
        let sources = root.appendingPathComponent("Sources", isDirectory: true)
        try FileManager.default.createDirectory(
            at: sources,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }

        let orderOld = "let status = \"pending\"\nlet retries = 3\n"
        let orderNew = "let status = \"paid\"\nlet retries = 3\n"
        let payloadOld = "let payload = \"\(String(repeating: "segment-", count: 24))pending\"\n"
        let payloadNew = payloadOld.replacingOccurrences(
            of: "pending",
            with: "paid"
        )
        let largeOld = (["out-of-context-sentinel"] +
            (1...120).map { "record-\($0) = unchanged" })
            .joined(separator: "\n") + "\n"
        let largeNew = largeOld.replacingOccurrences(
            of: "record-60 = unchanged",
            with: "record-60 = modified"
        )
        let obsoleteOld = "let obsolete = true\n"

        let originals: [(path: String, content: String)] = [
            ("Sources/order.swift", orderOld),
            ("Sources/payload.swift", payloadOld),
            ("Sources/large.swift", largeOld),
            ("Sources/obsolete.swift", obsoleteOld)
        ]
        for original in originals {
            try original.content.write(
                to: root.appendingPathComponent(original.path),
                atomically: true,
                encoding: .utf8
            )
        }

        let rootID = PathAccessRootIdentifier(rawValue: "project")
        let grant = try WorkspaceGrant(
            id: WorkspaceGrantIdentifier("aint-diffpreview"),
            rootIdentifier: rootID,
            capabilities: Set(WorkspaceCapability.allCases)
        )
        let authority = try Workspace(
            root: PathAccessRoot(
                id: rootID,
                label: "Preview",
                scope: try PathAccessScope(root: root, policy: .defaults.workspace),
                isDefault: true
            ),
            grants: [grant]
        )
        let workspace = try authority.context(
            execution: .init(io: .blocking, mutations: .immediate)
        )

        let input = SystemIO.Tools.MutateFiles.Input(
            reason: "Preview only: multiple files, long lines, collapsed context",
            entries: [
                .init(kind: .replace_text, path: "Sources/order.swift", content: orderNew),
                .init(kind: .replace_text, path: "Sources/payload.swift", content: payloadNew),
                .init(kind: .replace_text, path: "Sources/large.swift", content: largeNew),
                .init(kind: .create_text, path: "Sources/created.swift", content: "let created = true\n"),
                .init(kind: .delete, path: "Sources/obsolete.swift")
            ]
        )
        let preparation = try await SystemIO.Tools.MutateFiles().prepare(
            input,
            in: ToolContext(workspace: workspace)
        )

        // Preparation must never apply its proposed file mutations.
        for original in originals {
            let current = try String(
                contentsOf: root.appendingPathComponent(original.path),
                encoding: .utf8
            )
            guard current == original.content else {
                throw Failure.unexpectedMutation(original.path)
            }
        }
        guard !FileManager.default.fileExists(
            atPath: root.appendingPathComponent("Sources/created.swift").path
        ) else {
            throw Failure.unexpectedMutation("Sources/created.swift")
        }

        // Exercise the same serializable preflight contract as Host.
        let encoded = try JSONEncoder().encode(preparation.review)
        let review = try JSONDecoder().decode(ToolPreflight.self, from: encoded)
        guard let difference = review.preview.difference else {
            throw Failure.missingDifference
        }

        let mode = difference.sections != nil ? "sections" :
            (difference.source != nil ? "source" : "legacy")
        let rendered = AgenticMutationDifferenceRenderer.render(
            difference,
            options: .init(width: .fixed(columns))
        )
        if embedded {
            let snapshot = AgenticHostConsoleSnapshot(
                runs: [
                    .init(
                        id: "preview-run",
                        title: "Mutation preview",
                        state: .awaitingApproval,
                        steps: [
                            .init(id: "mutation", title: "mutate_files", state: .active)
                        ]
                    )
                ],
                documents: [
                    .init(
                        id: "preview-diff",
                        runID: "preview-run",
                        stepID: "mutation",
                        kind: .diff,
                        title: difference.title ?? "File mutation preview",
                        body: rendered,
                        differenceBody: difference,
                        differencePrelude: "status     staged for approval"
                    )
                ]
            )
            var control = AgenticHostConsoleWorkflowControl(
                snapshot: snapshot,
                currentRunID: "preview-run",
                currentStepID: "mutation"
            )
            guard control.handle(.char("f")) == .documentOpened(
                documentID: "preview-diff",
                kind: .diff
            ) else {
                throw Failure.missingDifference
            }
            let rows = max(12, terminalSize.rows)
            var frame = TerminalFrame(rows: rows, columns: columns)
            control.render(
                into: &frame,
                in: TerminalRegion(rows: rows, columns: columns)
            )
            var renderer = TerminalFrameRenderer(stream: .standardError)
            renderer.render(frame)
            Terminal.showCursor(on: .standardError)
        } else {
            Terminal.write(
                "t_aint_diffpreview | width=\(columns) | mode=\(mode) | sections=\(difference.sections?.count ?? 0)\n\n",
                to: .standardError
            )
            Terminal.write(rendered + "\n", to: .standardError)
        }
    }
}
