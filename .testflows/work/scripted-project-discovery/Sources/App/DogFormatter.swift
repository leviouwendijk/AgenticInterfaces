public struct DogFormatter {
    public init() {
    }

    private func trimString(_ string: String) -> String {
        return string.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    public func displayDog(
        name: String,
        breed: String
    ) -> String {
        let trimmedName = trimString(name)
        let trimmedBreed = trimString(breed)

        return "\(trimmedName) is a \(trimmedBreed)"
    }
}
