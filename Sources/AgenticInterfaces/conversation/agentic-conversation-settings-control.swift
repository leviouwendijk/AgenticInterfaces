import Agentic
import Primitives
import Terminal

/// The browser is only a projection of the Host's installed catalog.
/// Selection is expressed as Core AgentCapabilitySet values, not UI policies.
enum AgenticConversationSettingsControlEvent: Sendable, Hashable {
    case closeRequested
    case conversation(AgenticConversationEvent)
}

/// Conversation settings as one netrw-like tree: each section folds open in
/// place, capabilities group by domain then type, and `/` filters them all.
struct AgenticConversationSettingsControl: Sendable {
    fileprivate enum Filter: String, Sendable, Hashable, CaseIterable {
        case all, available, visible, unavailable

        var next: Self {
            let all = Self.allCases
            return all[(all.firstIndex(of: self)! + 1) % all.count]
        }
    }

    fileprivate enum RowID: Sendable, Hashable {
        case model, response, invocationoptions, requesttimeout, autonomy, capabilities, usage
        case usageTokens, usageCost, usageProvenance
        case modelProfile(AgentModelProfileIdentifier)
        case responseDelivery(AgentModelResponseDelivery)
        case timeoutseconds(Int?)
        case autonomyMode(AutonomyMode)
        case domain(String)
        case type(domain: String, AgenticConversationCapabilityEntry.Kind)
        case capability(String)
    }

    private var tree: TerminalSettingsTreeControl<RowID>
    private var filter: Filter = .all

    init(snapshot: AgenticConversationSnapshot) {
        let built = Self.tree(snapshot, filter: .all)
        tree = TerminalSettingsTreeControl(
            title: "Conversation settings",
            tree: built,
            collapsed: Set(built.roots.flatMap { [$0.value.id] + $0.children.map(\.value.id) }),
            legends: [.capabilities: "   A V   ● enabled · ○ disabled"],
            matcher: { AgenticTreeListMatcher.ranked($0, $1) }
        )
        tree.select(.model)
    }

    mutating func update(_ snapshot: AgenticConversationSnapshot) {
        refresh(snapshot)
    }

    mutating func openRoot(_ snapshot: AgenticConversationSnapshot) {
        refresh(snapshot)
    }

    mutating func openModel(_ snapshot: AgenticConversationSnapshot) {
        refresh(snapshot)
        tree.select(.modelProfile(snapshot.preferredModelProfileID))
    }

    mutating func handle(_ key: TerminalKey, snapshot: inout AgenticConversationSnapshot)
        -> AgenticConversationSettingsControlEvent?
    {
        if key == .char("f"), !tree.list.capturesInput {
            filter = filter.next
            refresh(snapshot)
            return .conversation(.feedbackRequested("Capabilities: \(filter.rawValue)"))
        }
        switch tree.handle(key) {
        case .closeRequested?:
            return .closeRequested
        case .unavailable(let id)?:
            let message: String
            switch id {
            case .responseDelivery(.stream):
                message = "Streaming is unavailable for the selected model."
            case .modelProfile(let identifier):
                let title = snapshot.models.first(where: { $0.id == identifier })?.title
                    ?? identifier.rawValue
                message = "Model '\(title)' is unavailable."
            default:
                message = "Selection is unavailable."
            }
            return .conversation(.feedbackRequested(message))
        case .accepted(let id)?:
            return accept(id, snapshot: &snapshot)
        case .toggled(.capability(let id))?:
            return toggle(id, availability: true, snapshot: &snapshot)
        case .toggled?, nil:
            return nil
        }
    }

    mutating func render(into frame: inout TerminalFrame, in region: TerminalRegion) {
        tree.instructions = "j/k move  h/l fold  enter select  space available  / filter  f \(filter.rawValue)  J/K detail  q back"
        tree.render(
            into: &frame,
            in: region,
            theme: .agentic,
            columns: min(100, max(1, region.columns - 4)),
            rows: min(30, max(1, region.rows - 2))
        )
    }

    private mutating func accept(_ id: RowID, snapshot: inout AgenticConversationSnapshot)
        -> AgenticConversationSettingsControlEvent?
    {
        switch id {
        case .model, .response, .invocationoptions, .requesttimeout, .autonomy, .capabilities, .usage,
             .usageTokens, .usageCost, .usageProvenance, .domain, .type:
            return nil
        case .capability(let identifier):
            return toggle(identifier, availability: false, snapshot: &snapshot)
        case .modelProfile(let identifier):
            guard snapshot.models.first(where: { $0.id == identifier })?.isAvailable == true else {
                return .conversation(.feedbackRequested("Preferred model is unavailable."))
            }
            snapshot.preferredModelProfileID = identifier
            if Self.preferredModelSupportsStreaming(snapshot) == false {
                snapshot.selectedResponseDelivery = .buffered
            }
            refresh(snapshot)
            return .conversation(.modelPreferenceChanged(identifier))
        case .responseDelivery(let delivery):
            if delivery == .stream && !Self.preferredModelSupportsStreaming(snapshot) {
                return .conversation(.feedbackRequested("Streaming is unavailable for the selected model."))
            }
            snapshot.selectedResponseDelivery = delivery
            refresh(snapshot)
            return .conversation(.responseDeliverySelectionChanged(delivery))
        case .timeoutseconds(let seconds):
            var options = snapshot.selectedInvocationOptions
            options.timeoutseconds = seconds
            snapshot.selectedInvocationOptions = options
            refresh(snapshot)
            return .conversation(.invocationOptionsSelectionChanged(options))
        case .autonomyMode(let mode):
            snapshot.selectedAutonomyMode = mode
            refresh(snapshot)
            return .conversation(.autonomySelectionChanged(mode))
        }
    }

    private mutating func toggle(_ identifier: String, availability: Bool,
                                  snapshot: inout AgenticConversationSnapshot)
        -> AgenticConversationSettingsControlEvent
    {
        guard let entry = snapshot.capabilityEntries.first(where: { $0.id == identifier }) else {
            return .conversation(.feedbackRequested("Capability is no longer installed."))
        }
        if entry.kind == .instruction {
            let id = InstructionIdentifier(rawValue: entry.identifier)
            var selected = Set(snapshot.selectedInstructionIDs)
            if !selected.insert(id).inserted { selected.remove(id) }
            snapshot.selectedInstructionIDs = snapshot.capabilityEntries.compactMap { item in
                guard item.kind == .instruction else { return nil }
                let id = InstructionIdentifier(rawValue: item.identifier)
                return selected.contains(id) ? id : nil
            }
            refresh(snapshot)
            return .conversation(.instructionSelectionChanged(snapshot.selectedInstructionIDs))
        }
        let member = entry.capability
        var available = snapshot.availableCapabilities
        var visible = snapshot.visibleCapabilities
        if availability {
            if member.intersecting(available) != .none {
                available = available.subtracting(member)
                visible = visible.subtracting(member)
            } else {
                available = available.union(member)
            }
        } else {
            guard member.intersecting(available) != .none else {
                return .conversation(.feedbackRequested("Enable availability before exposing this capability."))
            }
            if member.intersecting(visible) != .none {
                visible = visible.subtracting(member)
            } else {
                visible = visible.union(member)
            }
        }
        snapshot.availableCapabilities = available
        snapshot.visibleCapabilities = visible.intersecting(available)
        refresh(snapshot)
        return .conversation(.capabilitySelectionChanged(
            available: snapshot.availableCapabilities,
            visible: snapshot.visibleCapabilities
        ))
    }

    /// Rebuilds values in place; folds, cursor and filter stay.
    private mutating func refresh(_ snapshot: AgenticConversationSnapshot) {
        tree.update(Self.tree(snapshot, filter: filter))
    }
}

private extension AgenticConversationSettingsControl {
    typealias Node = Tree<TerminalSettingsTreeEntry<RowID>>.Node

    static func tree(
        _ snapshot: AgenticConversationSnapshot,
        filter: Filter
    ) -> Tree<TerminalSettingsTreeEntry<RowID>> {
        let entries = filtered(snapshot.capabilityEntries, snapshot: snapshot, filter: filter)
        let model = snapshot.models.first { $0.id == snapshot.preferredModelProfileID }
        let visibleCount = snapshot.visibleCapabilities.tools.count
            + snapshot.visibleCapabilities.programs.count
            + snapshot.visibleCapabilities.inferences.count
            + snapshot.visibleCapabilities.agents.count
        let timeout = requestTimeoutTitle(snapshot.selectedInvocationOptions.timeoutseconds)

        let models = snapshot.models.map { model in
            TerminalSettingsRow<RowID>(id: .modelProfile(model.id), title: model.title,
                value: model.isAvailable ? nil : "unavailable",
                isEnabled: model.isAvailable,
                accessory: .radio(selected: model.id == snapshot.preferredModelProfileID),
                detail: .init(title: model.title, body: model.detail))
        }
        let capabilities = domains(entries).map { domain in
            Node(
                .init(id: .domain(domain), title: domain),
                children: AgenticConversationCapabilityEntry.Kind.allCases.compactMap { kind in
                    let items = entries.filter { $0.domain == domain && $0.kind == kind }
                    guard !items.isEmpty else { return nil }
                    return Node(
                        .init(id: .type(domain: domain, kind), title: kind.title, value: "\(items.count)"),
                        children: items.map { leaf(capabilityRow($0, snapshot: snapshot), keywords: keywords($0)) }
                    )
                }
            )
        }
        return Tree(roots: [
            section(.model, "Model", value: model?.title, models),
            section(.response, "Response", value: responseDeliveryTitle(snapshot.selectedResponseDelivery),
                    responseDeliveryRows(snapshot)),
            Node(
                .init(id: .invocationoptions, title: "Invocation options", value: timeout),
                children: [
                    section(.requesttimeout, "Request timeout", value: timeout, requestTimeoutRows(snapshot),
                            detail: .init(title: "Request timeout", fields: [.init("selected", timeout)],
                                          body: "Set the provider request timeout used for model invocations.")),
                ]
            ),
            section(.autonomy, "Autonomy", value: autonomyTitle(snapshot.selectedAutonomyMode), autonomyRows(snapshot)),
            Node(
                .init(
                    id: .capabilities,
                    title: "Capabilities",
                    value: "\(visibleCount) visible · \(snapshot.selectedInstructionIDs.count) instructions · \(filter.rawValue)",
                    detail: .init(title: "Capabilities", body:
                        "Grouped by domain, then type. Enter shows a capability to the model; Space makes it available. "
                        + "/ filters every setting; f cycles all, available, visible and unavailable.")
                ),
                children: capabilities
            ),
            section(.usage, "Usage", value: snapshot.usage.shortSummary, usageRows(snapshot.usage)),
        ])
    }

    static func section(
        _ id: RowID,
        _ title: String,
        value: String?,
        _ rows: [TerminalSettingsRow<RowID>],
        detail: TerminalSettingsDetail? = nil
    ) -> Node {
        Node(.init(id: id, title: title, value: value, detail: detail), children: rows.map { leaf($0) })
    }

    static func leaf(
        _ row: TerminalSettingsRow<RowID>,
        keywords: String = ""
    ) -> Node {
        Node(.init(
            id: row.id,
            title: row.title,
            value: row.value ?? row.caption,
            accessory: row.accessory,
            isEnabled: row.isEnabled,
            detail: row.detail,
            keywords: keywords
        ))
    }

    /// Domain, type and identifier are searchable, not only the title.
    static func keywords(
        _ entry: AgenticConversationCapabilityEntry
    ) -> String {
        [entry.identifier, entry.domain, entry.kind.rawValue, entry.summary].joined(separator: " ")
    }

    static func domains(_ entries: [AgenticConversationCapabilityEntry]) -> [String] {
        Array(Set(entries.map(\.domain))).sorted()
    }

    static func filtered(
        _ entries: [AgenticConversationCapabilityEntry],
        snapshot: AgenticConversationSnapshot,
        filter: Filter
    ) -> [AgenticConversationCapabilityEntry] {
        entries.filter { entry in
            if filter == .all { return true }
            if entry.kind == .instruction {
                let selected = snapshot.selectedInstructionIDs.contains(
                    .init(rawValue: entry.identifier)
                )
                switch filter {
                case .all: return true
                case .available: return true
                case .visible: return selected
                case .unavailable: return false
                }
            }
            let available = entry.capability.intersecting(snapshot.availableCapabilities) != .none
            let visible = entry.capability.intersecting(snapshot.visibleCapabilities) != .none
            switch filter {
            case .all: return true
            case .available: return available
            case .visible: return visible
            case .unavailable: return !available
            }
        }
    }

    static func capabilityRow(_ entry: AgenticConversationCapabilityEntry,
                              snapshot: AgenticConversationSnapshot) -> TerminalSettingsRow<RowID>
    {
        if entry.kind == .instruction {
            let isSelected = snapshot.selectedInstructionIDs.contains(.init(rawValue: entry.identifier))
            return .init(id: .capability(entry.id), title: entry.title,
                accessory: .checkbox(selected: isSelected),
                detail: .init(title: entry.title,
                    fields: [.init("identifier", entry.identifier), .init("domain", entry.domain)],
                    body: entry.summary))
        }
        let enabled = entry.capability.intersecting(snapshot.availableCapabilities) != .none
        let visible = entry.capability.intersecting(snapshot.visibleCapabilities) != .none
        return .init(id: .capability(entry.id), title: entry.title,
            accessory: .indicators(first: enabled, second: visible),
            detail: .init(title: entry.title,
                fields: [.init("identifier", entry.identifier),
                         .init("domain", entry.domain),
                         .init("type", entry.kind.rawValue),
                         .init("availability", enabled ? "enabled" : "disabled"),
                         .init("visibility", visible ? "shown" : "hidden")],
                body: entry.summary + "\n\nSpace toggles availability; Enter toggles visibility."))
    }

    static func usageRows(
        _ usage: AgenticConversationUsagePresentation
    ) -> [TerminalSettingsRow<RowID>] {
        [
            .init(
                id: .usageTokens,
                title: "Token consumption",
                value: usage.shortSummary,
                detail: .init(
                    title: "Token consumption (observed and projected)",
                    fields: [
                        .init("input", String(usage.inputTokens)),
                        .init("output", String(usage.outputTokens)),
                        .init("cached reads", String(usage.cachedInputReadTokens)),
                        .init("cached writes", String(usage.cachedInputWriteTokens)),
                        .init("reasoning output", String(usage.reasoningOutputTokens)),
                    ],
                    body: "Token categories may overlap. These counts describe usage; they do not measure remaining context capacity."
                )
            ),
            .init(
                id: .usageCost,
                title: "Cost",
                value: usage.costDescription,
                detail: .init(title: "Cost by currency", body:
                    "\(usage.costDescription). Only priced projections are included. Missing pricing is unknown, not zero.")
            ),
            .init(
                id: .usageProvenance,
                title: "Provenance",
                value: usage.scopeDescription,
                detail: .init(title: "Usage provenance", body:
                    "\(usage.scopeDescription). Each turn uses its actual provider projection when available, otherwise the projected estimate; runs are keyed by ID to prevent double counting on refresh.")
            ),
        ]
    }

    private static func invocationOptionsRows(
        _ snapshot: AgenticConversationSnapshot
    ) -> [TerminalSettingsRow<RowID>] {
        [
            TerminalSettingsRow(
                id: .requesttimeout,
                title: "Request timeout",
                value: requestTimeoutTitle(
                    snapshot.selectedInvocationOptions.timeoutseconds
                ),
                accessory: .disclosure,
                detail: TerminalSettingsDetail(
                    title: "Request timeout",
                    fields: [
                        TerminalField(
                            "selected",
                            requestTimeoutTitle(
                                snapshot.selectedInvocationOptions.timeoutseconds
                            )
                        ),
                    ],
                    body: "Set the provider request timeout used for model invocations."
                )
            ),
        ]
    }

    private static func requestTimeoutRows(
        _ snapshot: AgenticConversationSnapshot
    ) -> [TerminalSettingsRow<RowID>] {
        requestTimeoutPresets().map { preset in
            TerminalSettingsRow(
                id: .timeoutseconds(preset.seconds),
                title: preset.title,
                accessory: .radio(
                    selected:
                        snapshot.selectedInvocationOptions.timeoutseconds
                        == preset.seconds
                ),
                detail: TerminalSettingsDetail(
                    title: preset.title,
                    fields: [
                        TerminalField(
                            "seconds",
                            preset.seconds.map { String($0) }
                                ?? "provider default"
                        ),
                    ],
                    body: preset.seconds == nil
                        ? "Use the timeout policy supplied by the selected provider."
                        : "Override the provider request timeout for model invocations."
                )
            )
        }
    }

    private static func requestTimeoutPresets()
        -> [(seconds: Int?, title: String)]
    {
        [
            (nil, "Provider default"),
            (60, "1 minute"),
            (300, "5 minutes"),
            (600, "10 minutes"),
            (1_800, "30 minutes"),
            (3_600, "60 minutes"),
        ]
    }

    private static func requestTimeoutTitle(
        _ timeoutseconds: Int?
    ) -> String {
        guard let timeoutseconds else {
            return "Provider default"
        }

        return requestTimeoutPresets().first {
            $0.seconds == timeoutseconds
        }?.title ?? "\(timeoutseconds) seconds"
    }

    private static func responseDeliveryRows(
        _ snapshot: AgenticConversationSnapshot
    ) -> [TerminalSettingsRow<RowID>] {
        let supportsStreaming = preferredModelSupportsStreaming(
            snapshot
        )

        return [
            TerminalSettingsRow(
                id: .responseDelivery(.stream),
                title: "Streaming",
                caption: supportsStreaming
                    ? nil
                    : "Unsupported by selected model.",
                isEnabled: supportsStreaming,
                accessory: .radio(
                    selected: snapshot.selectedResponseDelivery == .stream
                ),
                detail: responseDeliveryDetail(
                    .stream,
                    snapshot: snapshot
                )
            ),
            TerminalSettingsRow(
                id: .responseDelivery(.buffered),
                title: "Buffered",
                accessory: .radio(
                    selected: snapshot.selectedResponseDelivery == .buffered
                ),
                detail: responseDeliveryDetail(
                    .buffered,
                    snapshot: snapshot
                )
            ),
        ]
    }

    private static func responseDeliveryTitle(
        _ delivery: AgentModelResponseDelivery
    ) -> String {
        switch delivery {
        case .stream:
            return "Streaming"
        case .buffered:
            return "Buffered"
        }
    }

    private static func responseDeliveryDetail(
        _ delivery: AgentModelResponseDelivery,
        snapshot: AgenticConversationSnapshot
    ) -> TerminalSettingsDetail {
        let supportsStreaming = preferredModelSupportsStreaming(
            snapshot
        )

        switch delivery {
        case .stream:
            return TerminalSettingsDetail(
                title: "Streaming",
                fields: [
                    TerminalField(
                        "model support",
                        supportsStreaming ? "yes" : "no"
                    ),
                ],
                body: "Deliver model output incrementally while the response is generated."
            )

        case .buffered:
            return TerminalSettingsDetail(
                title: "Buffered",
                fields: [
                    TerminalField("model support", "yes"),
                ],
                body: "Wait for the complete provider response before delivering it to the runtime."
            )
        }
    }

    private static func autonomyRows(
        _ snapshot: AgenticConversationSnapshot
    ) -> [TerminalSettingsRow<RowID>] {
        AutonomyMode.allCases.map { mode in
            TerminalSettingsRow(
                id: .autonomyMode(mode),
                title: autonomyTitle(mode),
                accessory: .radio(
                    selected: snapshot.selectedAutonomyMode == mode
                ),
                detail: autonomyDetail(mode)
            )
        }
    }

    private static func autonomyTitle(
        _ mode: AutonomyMode
    ) -> String {
        switch mode {
        case .suggest_only:
            return "Suggest only"
        case .auto_observe:
            return "Auto observe"
        case .auto_bounded_mutate:
            return "Auto bounded mutate"
        case .review_privileged:
            return "Review privileged"
        }
    }

    private static func autonomyDetail(
        _ mode: AutonomyMode
    ) -> TerminalSettingsDetail {
        switch mode {
        case .suggest_only:
            return TerminalSettingsDetail(
                title: autonomyTitle(mode),
                fields: [
                    TerminalField("observe", "review"),
                    TerminalField("bounded mutation", "review"),
                    TerminalField("privileged", "review"),
                ],
                body: "Require human review for every non-forbidden tool action. Forbidden actions remain denied."
            )

        case .auto_observe:
            return TerminalSettingsDetail(
                title: autonomyTitle(mode),
                fields: [
                    TerminalField("observe", "automatic"),
                    TerminalField("bounded mutation", "review"),
                    TerminalField("privileged", "review"),
                ],
                body: "Run observational actions automatically while bounded mutations and privileged actions remain review-gated."
            )

        case .auto_bounded_mutate:
            return TerminalSettingsDetail(
                title: autonomyTitle(mode),
                fields: [
                    TerminalField("observe", "automatic"),
                    TerminalField("bounded mutation", "automatic"),
                    TerminalField("privileged", "denied"),
                ],
                body: "Run observational and bounded mutation actions automatically. Privileged and forbidden actions are denied."
            )

        case .review_privileged:
            return TerminalSettingsDetail(
                title: autonomyTitle(mode),
                fields: [
                    TerminalField("observe", "automatic"),
                    TerminalField("bounded mutation", "automatic"),
                    TerminalField("privileged", "review"),
                ],
                body: "Run observational and bounded mutation actions automatically while privileged actions require human review. Forbidden actions remain denied."
            )
        }
    }

    private static func preferredModelSupportsStreaming(
        _ snapshot: AgenticConversationSnapshot
    ) -> Bool {
        snapshot.models.first {
            $0.id == snapshot.preferredModelProfileID
        }?.supportsStreaming ?? true
    }


}
