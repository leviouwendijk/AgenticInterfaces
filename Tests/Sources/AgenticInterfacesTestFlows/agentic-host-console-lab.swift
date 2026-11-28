@_spi(Testing) import AgenticInterfaces
import AgenticPresentation
import Terminal

@main
enum AgenticInterfacesTestFlows {
    static func main() throws {
        let command = CommandLine.arguments
            .dropFirst()
            .first {
                !$0.hasPrefix("-")
            }

        switch command {
        case "host-console":
            try AgenticHostConsoleLab.run()

        case "conversation":
            try AgenticConversationLab.run()

        case "conversation-scrolling":
            try AgenticConversationScrollingSmoke.run()
            print("agentic conversation scrolling smoke passed")

        case "host-console-foundation":
            try AgenticHostConsoleFoundationSmoke.run()
            try AgenticHostConsoleWorkflowSmoke.run()
            try AgenticConversationSmoke.run()
            print(
                "agentic host console foundation smoke passed"
            )

        case nil:
            try AgenticHostConsoleFoundationSmoke.run()
            try AgenticHostConsoleWorkflowSmoke.run()
            try AgenticConversationSmoke.run()
            print(
                "agentic host console foundation smoke passed"
            )

        default:
            print(
                """
                usage:
                  swift run aginttest host-console
                  swift run aginttest conversation
                  swift run t_aint_main conversation-scrolling
                  swift run aginttest host-console-foundation
                """
            )
        }
    }
}

enum AgenticHostConsoleLab {
    static func run() throws {
        try AgenticHostConsoleFoundationSmoke.run()
        try AgenticHostConsoleWorkflowSmoke.run()

        let stream = TerminalStream.standardError
        let session = try TerminalSession(
            options: TerminalSession.Options(
                useAlternateScreen: true,
                hideCursor: true,
                useRawMode: true,
                useBracketedPaste: true,
                restoreOnInterrupt: true,
                outputStream: stream
            )
        )

        defer {
            session.restore()
        }

        let reader = TerminalKeyReader()
        var renderer = TerminalFrameRenderer(
            stream: stream
        )
        var console = AgenticHostConsole.Workflow.Control(
            snapshot: AgenticHostConsoleWorkflowFixture.make()
        )
        var size = Terminal.size(
            for: stream
        )

        func render() {
            var frame = TerminalFrame(
                rows: size.rows,
                columns: size.columns
            )

            console.render(
                into: &frame,
                in: TerminalRegion(
                    rows: size.rows,
                    columns: size.columns
                )
            )
            renderer.render(
                frame
            )
        }

        render()

        while true {
            let events = reader.readEvents(
                timeoutMilliseconds: 100,
                maximumCount: 128
            )

            if events.isEmpty {
                let currentSize = Terminal.size(
                    for: stream
                )

                if currentSize != size {
                    size = currentSize
                    render()
                }

                continue
            }

            var shouldExit = false

            for event in events {
                guard case .key(let key) = event else {
                    continue
                }

                if console.handle(
                    key
                )?.requestsExit == true {
                    shouldExit = true
                    break
                }
            }

            if shouldExit {
                return
            }

            size = Terminal.size(
                for: stream
            )
            render()
        }
    }

    static func fixture() -> AgenticHostConsole.Snapshot {
        AgenticHostConsole.Snapshot(
            context: "~/main/programming/libraries/swiftlibs",
            runs: [
                AgenticHostConsole.Run(
                    id: "persistent-host-console",
                    title: "persistent host console",
                    summary: "executing ToolPlan",
                    state: .active,
                    steps: [
                        AgenticHostConsole.Step(
                            id: "mutate",
                            title: "mutate",
                            detail: "AgenticInterfaces/Sources/AgenticInterfaces/host-console",
                            state: .completed,
                            fields: [
                                .init(
                                    "operation",
                                    "bounded mutation"
                                ),
                            ]
                        ),
                        AgenticHostConsole.Step(
                            id: "build",
                            title: "swift_tool_build",
                            detail: "AgenticInterfaces",
                            state: .completed,
                            fields: [
                                .init(
                                    "configuration",
                                    "release"
                                ),
                            ]
                        ),
                        AgenticHostConsole.Step(
                            id: "aitest",
                            title: "aginttest",
                            detail: "host-console",
                            state: .active,
                            fields: [
                                .init(
                                    "purpose",
                                    "interactive visual validation"
                                ),
                                .init(
                                    "focus",
                                    "timeline"
                                ),
                            ]
                        ),
                        AgenticHostConsole.Step(
                            id: "verify",
                            title: "swift_tool_build",
                            detail: "AgenticInterfaces",
                            state: .pending
                        ),
                        AgenticHostConsole.Step(
                            id: "diff",
                            title: "git_tool_diff",
                            state: .pending
                        ),
                    ]
                ),
                AgenticHostConsole.Run(
                    id: "recovery",
                    title: "recovery branch",
                    summary: "failed child awaiting recovery",
                    state: .failed,
                    steps: [
                        AgenticHostConsole.Step(
                            id: "failed-mutate",
                            title: "mutate",
                            detail: "Sources/AgenticInterfaces",
                            state: .failed,
                            fields: [
                                .init(
                                    "error",
                                    "edit match not found"
                                ),
                            ]
                        ),
                        AgenticHostConsole.Step(
                            id: "skipped-build",
                            title: "swift_tool_build",
                            state: .skipped
                        ),
                    ]
                ),
                AgenticHostConsole.Run(
                    id: "approval",
                    title: "repository mutation",
                    summary: "needs human review",
                    state: .awaitingApproval,
                    steps: [
                        AgenticHostConsole.Step(
                            id: "prepare",
                            title: "git_tool_prepare_commit",
                            detail: "AgenticInterfaces",
                            state: .active,
                            fields: [
                                .init(
                                    "requirement",
                                    "needs_human_review"
                                ),
                            ]
                        ),
                    ]
                ),
                AgenticHostConsole.Run(
                    id: "terminal-foundation",
                    title: "Terminal foundation",
                    summary: "published",
                    state: .completed,
                    steps: [
                        AgenticHostConsole.Step(
                            id: "terminal-performance",
                            title: "rendering performance improvements",
                            detail: "d227e0f",
                            state: .completed
                        ),
                    ]
                ),
            ]
        )
    }
}
