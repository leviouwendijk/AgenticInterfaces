public struct DogFormatter {
    public init() {
    }

    public func displayDog(
        name: String,
        breed: String
    ) -> String {
        let trimmedName = name
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        let trimmedBreed = breed
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        return "\(trimmedName) is a \(trimmedBreed)"
    }
}
