public struct UserFormatter {
    public init() {
    }

    public func displayName(
        name: String,
        city: String
    ) -> String {
        let trimmedName = name
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        let trimmedCity = city
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        return "\(trimmedName) from \(trimmedCity)"
    }
}
