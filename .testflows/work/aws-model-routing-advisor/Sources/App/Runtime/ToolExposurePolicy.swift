public struct ToolExposurePolicy: Sendable, Codable, Hashable {
    public init() {
    }

    public func allowedTools(
        purpose: RoutePurpose,
        callerTools: [String]
    ) -> [String] {
        switch purpose {
        case .advisor,
             .reviewer:
            return callerTools

        case .executor,
             .coder,
             .summarizer,
             .classifier,
             .extractor:
            return callerTools
        }
    }
}