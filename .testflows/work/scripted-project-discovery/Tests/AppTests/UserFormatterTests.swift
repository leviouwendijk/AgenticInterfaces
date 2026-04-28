import FixtureApp

struct UserFormatterTests {
    func testDisplayName() {
        _ = UserFormatter().displayName(
            name: " Levi ",
            city: " Alkmaar "
        )
    }
}
