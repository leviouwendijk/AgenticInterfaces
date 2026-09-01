import AgenticInterfaces
import Terminal

enum AgenticHostConsoleInspectionSurfaceSmoke {
    enum Failure:
        Error
    {
        case unexpectedGeometry
        case unexpectedFieldWrapping
        case unexpectedInspectorOpen
        case unexpectedInspectorPresentation
    }

    static func run() throws {
        try runGeometryProbe()
        try runFieldWrappingProbe()
        try runInspectorIntegrationProbe()
    }

    private static func runGeometryProbe() throws {
        let region = TerminalRegion(
            rows: 24,
            columns: 120
        )
        let overlay =
            AgenticHostConsoleInspectionSurface.overlay(
                in: region
            )
        let actual = overlay.region(
            in: region
        )
        let expected = TerminalRegion(
            top: 1,
            leading: 2,
            rows: 22,
            columns: 116
        )

        guard actual == expected else {
            throw Failure.unexpectedGeometry
        }
    }

    private static func runFieldWrappingProbe() throws {
        let lines =
            AgenticHostConsoleInspectionSurface.fieldLines(
                [
                    AgenticHostConsoleField(
                        "summary",
                        "alpha beta gamma delta"
                    ),
                ],
                columns: 20
            )
        let continuationPrefix = String(
            repeating: " ",
            count: 9
        )

        guard lines.count == 2,
              lines.allSatisfy({
                TerminalDisplay.width(
                    of: $0
                ) <= 20
              }),
              lines[1] == continuationPrefix + "gamma delta"
        else {
            throw Failure.unexpectedFieldWrapping
        }
    }

    private static func runInspectorIntegrationProbe() throws {
        var console = AgenticHostConsoleControl(
            snapshot: AgenticHostConsoleSnapshot(
                runs: [
                    AgenticHostConsoleRunPresentation(
                        id: "inspection-surface-run",
                        title: "Inspection surface fixture",
                        state: .completed,
                        steps: [
                            AgenticHostConsoleStepPresentation(
                                id: "inspection-surface-step",
                                title: "search_sources",
                                state: .completed,
                                fields: [
                                    AgenticHostConsoleField(
                                        "summary",
                                        "This deliberately long result summary must wrap inside the Enter inspector and preserve final-token."
                                    ),
                                ]
                            ),
                        ]
                    ),
                ]
            )
        )

        _ = console.handle(
            .tab
        )

        guard console.handle(
            .enter
        ) == .stepInspectionOpened(
            runID: "inspection-surface-run",
            stepID: "inspection-surface-step"
        ) else {
            throw Failure.unexpectedInspectorOpen
        }

        var frame = TerminalFrame(
            rows: 24,
            columns: 64
        )

        console.render(
            into: &frame,
            in: TerminalRegion(
                rows: 24,
                columns: 64
            )
        )

        let rendered = frame
            .resolved()
            .spans
            .map(\.content)
            .joined(
                separator: "\n"
            )

        guard rendered.contains(
            "final-token."
        ) else {
            throw Failure.unexpectedInspectorPresentation
        }
    }
}
