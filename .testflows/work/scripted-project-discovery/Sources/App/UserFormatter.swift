public struct UserFormatter {
    public init() {
    }

    private func trimString(_ string: String) -> String {
        return string.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    public func displayName(
        name: String,
        city: String
    ) -> String {
        let trimmedName = trimString(name)
        let trimmedCity = trimString(city)

        return "\(trimmedName) from \(trimmedCity)"
    }
}
