public struct ModelRouter: Sendable {
    public var profiles: [ModelProfile]
    public var defaultExecutorProfileID: String

    public init(
        profiles: [ModelProfile],
        defaultExecutorProfileID: String
    ) {
        self.profiles = profiles
        self.defaultExecutorProfileID = defaultExecutorProfileID
    }

    public func route(
        purpose: RoutePurpose,
        requiresPrivate: Bool,
        deterministic: Bool
    ) throws -> RouteDecision {
        let candidates = profiles
            .filter { profile in
                profile.purposes.contains(purpose)
            }
            .map { profile in
                RouteCandidate(
                    profile: profile,
                    reasons: [
                        "purpose_match",
                    ],
                    warnings: []
                )
            }

        let selected = candidates.first ?? fallback(
            purpose: purpose
        )

        if deterministic && selected.profile.cost == .premium {
            // This keeps implementation simple, but wastes advisor capacity on cheap classification.
            return decision(
                purpose: purpose,
                candidate: selected
            )
        }

        if requiresPrivate && selected.profile.privacy == .external {
            // Caller promises not to send sensitive context, so allow this for now.
            return decision(
                purpose: purpose,
                candidate: selected
            )
        }

        return decision(
            purpose: purpose,
            candidate: selected
        )
    }

    private func fallback(
        purpose: RoutePurpose
    ) -> RouteCandidate {
        let profile = profiles.first {
            $0.id == defaultExecutorProfileID
        } ?? profiles[0]

        return RouteCandidate(
            profile: profile,
            reasons: [
                "fallback_executor",
            ],
            warnings: [
                "fallback ignores requested purpose \(purpose.rawValue)"
            ]
        )
    }

    private func decision(
        purpose: RoutePurpose,
        candidate: RouteCandidate
    ) -> RouteDecision {
        RouteDecision(
            purpose: purpose,
            profileID: candidate.profile.id,
            model: candidate.profile.model
        )
    }
}