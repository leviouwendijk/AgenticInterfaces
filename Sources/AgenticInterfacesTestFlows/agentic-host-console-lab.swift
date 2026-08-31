import AgenticInterfaces
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

        case "host-console-foundation":
            try AgenticHostConsoleFoundationSmoke.run()
            try AgenticHostConsoleWorkflowSmoke.run()
            print(
                "agentic host console foundation smoke passed"
            )

        case nil:
            try AgenticHostConsoleFoundationSmoke.run()
            try AgenticHostConsoleWorkflowSmoke.run()
            print(
                "agentic host console foundation smoke passed"
            )

        default:
            print(
                """
                usage:
                  swift run aginttest host-console
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
        var console = AgenticHostConsoleWorkflowControl(
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

    static func fixture() -> AgenticHostConsoleSnapshot {
        AgenticHostConsoleSnapshot(
            context: "~/main/programming/libraries/swiftlibs",
            runs: [
                AgenticHostConsoleRunPresentation(
                    id: "persistent-host-console",
                    title: "persistent host console",
                    summary: "executing ToolPlan",
                    state: .active,
                    steps: [
                        AgenticHostConsoleStepPresentation(
                            id: "mutate",
                            title: "mutate_files",
                            detail: "AgenticInterfaces/Sources/AgenticInterfaces/host-console",
                            state: .completed,
                            fields: [
                                .init(
                                    "operation",
                                    "bounded mutation"
                                ),
                            ]
                        ),
                        AgenticHostConsoleStepPresentation(
                            id: "build",
                            title: "swift_build",
                            detail: "AgenticInterfaces",
                            state: .completed,
                            fields: [
                                .init(
                                    "configuration",
                                    "release"
                                ),
                            ]
                        ),
                        AgenticHostConsoleStepPresentation(
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
                        AgenticHostConsoleStepPresentation(
                            id: "verify",
                            title: "swift_build",
                            detail: "AgenticInterfaces",
                            state: .pending
                        ),
                        AgenticHostConsoleStepPresentation(
                            id: "diff",
                            title: "git_diff",
                            state: .pending
                        ),
                    ]
                ),
                AgenticHostConsoleRunPresentation(
                    id: "recovery",
                    title: "recovery branch",
                    summary: "failed child awaiting recovery",
                    state: .failed,
                    steps: [
                        AgenticHostConsoleStepPresentation(
                            id: "failed-mutate",
                            title: "mutate_files",
                            detail: "Sources/AgenticInterfaces",
                            state: .failed,
                            fields: [
                                .init(
                                    "error",
                                    "edit match not found"
                                ),
                            ]
                        ),
                        AgenticHostConsoleStepPresentation(
                            id: "skipped-build",
                            title: "swift_build",
                            state: .skipped
                        ),
                    ]
                ),
                AgenticHostConsoleRunPresentation(
                    id: "approval",
                    title: "repository mutation",
                    summary: "needs human review",
                    state: .awaitingApproval,
                    steps: [
                        AgenticHostConsoleStepPresentation(
                            id: "prepare",
                            title: "git_prepare_commit",
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
                AgenticHostConsoleRunPresentation(
                    id: "terminal-foundation",
                    title: "Terminal foundation",
                    summary: "published",
                    state: .completed,
                    steps: [
                        AgenticHostConsoleStepPresentation(
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
