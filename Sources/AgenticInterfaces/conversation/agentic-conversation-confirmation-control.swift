import Terminal

struct AgenticConversationConfirmationControl:
    Sendable
{
    enum Event:
        Sendable,
        Hashable
    {
        case confirmed
        case cancelled
    }

    var title: String
    var message: String
    var confirmTitle: String
    var cancelTitle: String
    var confirms: Bool

    init(
        title: String,
        message: String,
        confirmTitle: String = "Proceed",
        cancelTitle: String = "Cancel",
        confirms: Bool = false
    ) {
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        self.cancelTitle = cancelTitle
        self.confirms = confirms
    }

    mutating func handle(
        _ key: TerminalKey
    ) -> Event? {
        switch key {
        case .escape,
             .control("C"):
            return .cancelled

        case .left,
             .right,
             .up,
             .down,
             .tab,
             .char("h"),
             .char("j"),
             .char("k"),
             .char("l"):
            confirms.toggle()
            return nil

        case .char("y"):
            return .confirmed

        case .char("n"):
            return .cancelled

        case .enter:
            return confirms
                ? .confirmed
                : .cancelled

        default:
            return nil
        }
    }

    func render(
        into frame: inout TerminalFrame,
        in region: TerminalRegion
    ) {
        guard !region.isEmpty else {
            return
        }

        let width = max(
            1,
            region.columns
        )
        var lines: [String] = [
            TerminalStyle.bold.apply(
                title
            ),
        ]
        lines.append(
            contentsOf: TerminalTextWrap.lines(
                message,
                width: width
            )
        )
        lines.append("")
        lines.append(
            (confirms ? "› " : "  ")
                + confirmTitle
        )
        lines.append(
            (!confirms ? "› " : "  ")
                + cancelTitle
        )
        lines.append("")
        lines.append(
            TerminalStyle.dim.apply(
                "←/→ choose · Enter confirm · Esc cancel"
            )
        )

        frame.write(
            Array(
                lines.prefix(
                    region.rows
                )
            ),
            in: region
        )
    }
}
