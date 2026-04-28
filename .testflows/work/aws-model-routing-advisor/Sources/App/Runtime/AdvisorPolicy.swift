public struct AdvisorPolicy: Sendable, Codable, Hashable {
    public var maxOutputTokens: Int
    public var temperature: Double
    public var inheritCallerTools: Bool

    public init(
        maxOutputTokens: Int = 900,
        temperature: Double = 0.0,
        inheritCallerTools: Bool = true
    ) {
        self.maxOutputTokens = maxOutputTokens
        self.temperature = temperature
        self.inheritCallerTools = inheritCallerTools
    }

    public func toolNamesForAdvisor(
        callerTools: [String]
    ) -> [String] {
        if inheritCallerTools {
            return callerTools
        }

        return []
    }
}