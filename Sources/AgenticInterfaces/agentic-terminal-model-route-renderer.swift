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
            "  adapter      \(profile.adapterIdentifier.rawValue)",
            "  model        \(profile.model)",
            "  cost         \(profile.cost.rawValue)",
            "  latency      \(profile.latency.rawValue)",
            "  privacy      \(profile.privacy.rawValue)",
        ]

        if !result.reasons.isEmpty {
            lines.append(
                "  reasons      \(result.reasons.joined(separator: ", "))"
            )
        }

        if !result.warnings.isEmpty {
            lines.append(
                "  warnings"
            )

            for warning in result.warnings {
                lines.append(
                    "    - \(warning)"
                )
            }
        }

        return lines.joined(
            separator: "\n"
        )
    }
}
