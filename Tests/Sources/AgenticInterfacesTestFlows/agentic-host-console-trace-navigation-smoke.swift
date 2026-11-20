import AgenticInterfaces

private enum TraceNavigationSmokeError: Error { case failed }

enum AgenticHostConsoleTraceNavigationSmoke {
    static func run() throws {
        let root = AgenticHostConsoleTraceNode(id: "root", title: "agent", children: [
            .init(id: "model", title: "model", children: [
                .init(id: "tool", title: "tool", reference_id: "tool-record")
            ])
        ])
        var control = try AgenticHostConsoleTraceNavigation(roots: [root])
        guard control.rows.count == 3 else { throw TraceNavigationSmokeError.failed }
        control.move(1)
        guard control.selected_id == "model" else { throw TraceNavigationSmokeError.failed }
        control.collapse()
        guard control.rows.count == 2 else { throw TraceNavigationSmokeError.failed }
        try control.update(roots: [root])
        guard control.selected_id == "model", control.rows.count == 2 else {
            throw TraceNavigationSmokeError.failed
        }
        control.expand()
        control.move(1)
        guard control.selected_node?.reference_id == "tool-record" else {
            throw TraceNavigationSmokeError.failed
        }
        do {
            _ = try AgenticHostConsoleTraceNavigation(roots: [root, root])
            throw TraceNavigationSmokeError.failed
        } catch AgenticHostConsoleTraceNavigation.Error.duplicate_id { }
    }
}
