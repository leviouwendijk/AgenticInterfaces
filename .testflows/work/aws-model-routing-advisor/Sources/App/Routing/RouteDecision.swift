public struct RouteDecision: Sendable, Codable, Hashable {
    public var purpose: RoutePurpose
    public var profileID: String
    public var model: String

    public init(
        purpose: RoutePurpose,
        profileID: String,
        model: String
    ) {
        self.purpose = purpose
        self.profileID = profileID
        self.model = model
    }
}

public struct RouteCandidate: Sendable, Codable, Hashable {
    public var profile: ModelProfile
    public var reasons: [String]
    public var warnings: [String]

    public init(
        profile: ModelProfile,
        reasons: [String] = [],
        warnings: [String] = []
    ) {
        self.profile = profile
        self.reasons = reasons
        self.warnings = warnings
    }
}