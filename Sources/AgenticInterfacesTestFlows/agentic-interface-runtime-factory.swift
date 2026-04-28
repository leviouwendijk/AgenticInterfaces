import AgenticAWS
import AgenticInterfaces

enum AgenticInterfaceRuntimeFactory {
    static func presenter() -> TerminalAgenticRunPresenter {
        TerminalAgenticRunPresenter(
            showsVerboseEvents: AgenticInterfaceTestEnvironment.options.verbose
        )
    }

    static func bedrockAdapter(
        defaultModelIdentifier: String,
        metadata: [String: String]
    ) throws -> BedrockModelAdapter {
        try BedrockModelAdapter.resolve(
            defaultModelIdentifier: defaultModelIdentifier,
            metadata: metadata,
            diagnostics: .init(
                raw: AgenticInterfaceTestEnvironment.options.raw
            )
        )
    }
}
