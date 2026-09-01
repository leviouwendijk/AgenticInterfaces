import Terminal

package enum AgenticHostConsoleInspectionSurface {
    package static func overlay(
        in region: TerminalRegion
    ) -> TerminalOverlay {
        TerminalOverlay(
            placement: .centered(
                columns: region.columns,
                rows: region.rows
            ),
            outerInsets: TerminalInsets(
                vertical: 1,
                horizontal: 2
            ),
            contentInsets: TerminalInsets(
                vertical: 1,
                horizontal: 2
            )
        )
    }

    package static func fieldLines(
        _ fields: [AgenticHostConsoleField],
        columns: Int
    ) -> [String] {
        let columns = max(
            1,
            columns
        )
        let naturalLabelWidth = fields
            .map {
                TerminalDisplay.width(
                    of: $0.label
                )
            }
            .max() ?? 0
        let labelWidth = min(
            naturalLabelWidth,
            max(
                0,
                columns - 3
            )
        )
        let spacing = "  "
        let valueColumns = max(
            1,
            columns
                - labelWidth
                - TerminalDisplay.width(
                    of: spacing
                )
        )

        return fields.flatMap { field in
            let clippedLabel = TerminalDisplay.clipped(
                field.label,
                columns: labelWidth
            )
            let paddedLabel =
                clippedLabel
                + String(
                    repeating: " ",
                    count: max(
                        0,
                        labelWidth
                            - TerminalDisplay.width(
                                of: clippedLabel
                            )
                    )
                )
            let visiblePrefix = paddedLabel + spacing
            let styledPrefix =
                TerminalStyle.dim.apply(
                    paddedLabel
                )
                + spacing
            let continuationPrefix = String(
                repeating: " ",
                count: TerminalDisplay.width(
                    of: visiblePrefix
                )
            )
            let wrapped = TerminalTextWrap.lines(
                field.value,
                width: valueColumns
            )
            let first = wrapped.first ?? ""

            return [
                styledPrefix + first
            ] + wrapped.dropFirst().map { line in
                continuationPrefix + line
            }
        }
    }
}
