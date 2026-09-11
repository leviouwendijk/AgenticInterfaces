import Agentic
import Terminal

public struct TerminalModelRouteRenderer: Sendable {
    public var theme: TerminalTheme

    public init(
        theme: TerminalTheme = .agentic
    ) {
        self.theme = theme
    }

    public func render(
        _ result: AgentModelRouteResult
    ) -> String {
        let profile = result.route.profile

        var lines: [String] = [
            "model route",
            "  purpose      \(result.route.purpose.rawValue)",
            "  profile      \(profile.identifier.rawValue)",
            "  gateway      \(profile.gatewayIdentifier.rawValue)",
            "  model        \(profile.model)",
            "  cost         \(profile.cost.rawValue)",
            "  latency      \(profile.latency.rawValue)",
            "  privacy      \(profile.privacy.rawValue)",
        ]

        if !result.diagnostics.isEmpty {
            lines.append(
                "  diagnostics"
            )

            for diagnostic in result.diagnostics {
                let message = diagnostic.message.map {
                    " · \($0)"
                } ?? ""

                lines.append(
                    "    - \(diagnostic.severity.rawValue) \(diagnostic.code.rawValue)\(message)"
                )
            }
        }

        return lines.joined(
            separator: "\n"
        )
    }
}
