import Agentic
import Terminal

enum AgenticTerminalInspectionRenderer {
    static func render(
        _ document: ToolInspectionDocument,
        stream: TerminalStream,
        theme: TerminalTheme,
        layout: TerminalBlockLayout = .agentic
    ) -> String {
        TerminalDetailDocument(
            title: document.title,
            sections: document.sections.map(
                terminalSection
            ),
            theme: theme,
            layout: layout
        ).render(
            stream: stream
        )
    }

    private static func terminalSection(
        _ section: ToolInspectionSection
    ) -> TerminalDetailSection {
        .init(
            title: section.title,
            items: section.items.map(
                terminalItem
            )
        )
    }

    private static func terminalItem(
        _ item: ToolInspectionItem
    ) -> TerminalDetailItem {
        switch item {
        case .field(let label, let value):
            return .field(
                label: label,
                value: value
            )

        case .list(let label, let values):
            return .list(
                label: label,
                values: values
            )

        case .body(let body):
            return .body(
                body
            )
        }
    }
}
