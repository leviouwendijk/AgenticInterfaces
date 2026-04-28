import Foundation

public struct AWSFormatter {
    public init() {}

    public func renderUser(
        name: String,
        city: String,
        score: Int
    ) -> String {
        let trimmedName = name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let trimmedCity = city.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return "user=\(trimmedName); city=\(trimmedCity); score=\(score)"
    }

    public func renderDog(
        name: String,
        breed: String,
        age: Int
    ) -> String {
        let trimmedName = name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let trimmedBreed = breed.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return "dog=\(trimmedName); breed=\(trimmedBreed); age=\(age)"
    }

    public func renderAppointment(
        client: String,
        topic: String,
        hour: Int
    ) -> String {
        let trimmedClient = client.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let trimmedTopic = topic.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return "client=\(trimmedClient); topic=\(trimmedTopic); hour=\(hour)"
    }
}
