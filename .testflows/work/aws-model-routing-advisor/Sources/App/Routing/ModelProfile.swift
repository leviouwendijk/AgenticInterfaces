public struct ModelProfile: Sendable, Codable, Hashable {
    public var id: String
    public var model: String
    public var purposes: Set<RoutePurpose>
    public var cost: CostClass
    public var privacy: PrivacyClass
    public var supportsTools: Bool

    public init(
        id: String,
        model: String,
        purposes: Set<RoutePurpose>,
        cost: CostClass,
        privacy: PrivacyClass,
        supportsTools: Bool
    ) {
        self.id = id
        self.model = model
        self.purposes = purposes
        self.cost = cost
        self.privacy = privacy
        self.supportsTools = supportsTools
    }
}

public enum CostClass: String, Sendable, Codable, Hashable {
    case cheap
    case balanced
    case premium
}

public enum PrivacyClass: String, Sendable, Codable, Hashable {
    case local
    case private_cloud
    case external
}