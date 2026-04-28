import Testing

struct ModelRouterTests {
    @Test
    func fallsBackToExecutorWhenNoPurposeMatch() throws {
        let router = ModelRouter(
            profiles: [
                .init(
                    id: "cheap-executor",
                    model: "nova-micro",
                    purposes: [
                        .executor,
                        .classifier,
                    ],
                    cost: .cheap,
                    privacy: .private_cloud,
                    supportsTools: true
                ),
            ],
            defaultExecutorProfileID: "cheap-executor"
        )

        let decision = try router.route(
            purpose: .advisor,
            requiresPrivate: false,
            deterministic: false
        )

        #expect(decision.profileID == "cheap-executor")
    }

    @Test
    func advisorPolicyCurrentlyInheritsTools() {
        let policy = AdvisorPolicy(
            inheritCallerTools: true
        )

        #expect(
            policy.toolNamesForAdvisor(
                callerTools: [
                    "read_file",
                    "mutate_files",
                ]
            ) == [
                "read_file",
                "mutate_files",
            ]
        )
    }
}