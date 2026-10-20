import Agentic
import Terminal

/// The browser is only a projection of the Host's installed catalog.
/// Selection is expressed as Core AgentCapabilitySet values, not UI policies.
enum AgenticConversationSettingsControlEvent: Sendable, Hashable {
    case closeRequested
    case conversation(AgenticConversationEvent)
}

struct AgenticConversationSettingsControl: Sendable {
    fileprivate enum Page: Sendable, Hashable {
        case root, model, response, invocationoptions, requesttimeout, autonomy, usage
        case capabilities, domains, types
        case domain(String)
        case type(AgenticConversationCapabilityEntry.Kind)
        case items(domain: String, type: AgenticConversationCapabilityEntry.Kind)
        case search
    }
    fileprivate enum Filter: String, Sendable, Hashable, CaseIterable {
        case all, available, visible, unavailable

        var next: Self {
            let values = Self.allCases
            let index = values.firstIndex(of: self) ?? 0
            return values[(index + 1) % values.count]
        }
    }

    fileprivate enum RowID: Sendable, Hashable {
        case model, response, invocationoptions, requesttimeout, autonomy, capabilities, usage
        case usageTokens, usageCost, usageProvenance
        case modelProfile(AgentModelProfileIdentifier)
        case responseDelivery(AgentModelResponseDelivery)
        case timeoutseconds(Int?)
        case autonomyMode(AutonomyMode)
        case domains, types, search
        case domain(String)
        case type(AgenticConversationCapabilityEntry.Kind)
        case capability(String)
    }

    private var page: Page = .root
    private var rootSelection: RowID = .model
    private var selections: [Page: RowID] = [:]
    private var filter: Filter = .all
    private var menu: TerminalSettingsMenuControl<RowID>
    private var searchQuery = ""
    private var isEditingSearch = false
    private var returnFromSearch: Page = .capabilities
    private var itemParentIsDomain = true

    init(snapshot: AgenticConversationSnapshot) {
        menu = Self.menu(snapshot: snapshot, page: .root, currentID: .model, query: "", filter: .all, editingSearch: false)
    }

    mutating func update(_ snapshot: AgenticConversationSnapshot) {
        refresh(snapshot, currentID: menu.currentID)
    }
    mutating func openRoot(_ snapshot: AgenticConversationSnapshot) {
        page = .root
        refresh(snapshot, currentID: rootSelection)
    }
    mutating func openModel(_ snapshot: AgenticConversationSnapshot) {
        page = .model
        refresh(snapshot, currentID: .modelProfile(snapshot.preferredModelProfileID))
    }

    mutating func handle(_ key: TerminalKey, snapshot: inout AgenticConversationSnapshot)
        -> AgenticConversationSettingsControlEvent?
    {
        if page.isBrowser {
            if isEditingSearch {
                switch key {
                case .enter:
                    isEditingSearch = false
                case .escape:
                    isEditingSearch = false
                case .backspace:
                    if !searchQuery.isEmpty { searchQuery.removeLast() }
                case .space:
                    searchQuery.append(" ")
                case .char(let character):
                    searchQuery.append(contentsOf: String(character))
                default:
                    break
                }
                refresh(snapshot, currentID: nil)
                return nil
            }
            if key == .char("/") {
                if page != .search { returnFromSearch = page }
                page = .search
                isEditingSearch = true
                refresh(snapshot, currentID: nil)
                return nil
            }
            if key == .char("f") {
                filter = filter.next
                refresh(snapshot, currentID: menu.currentID)
                return nil
            }
        }
        guard let event = menu.handle(key) else { return nil }
        switch event {
        case .currentChanged(let id):
            selections[page] = id
            if page == .root { rootSelection = id }
            return nil
        case .cancelRequested:
            switch page {
            case .root: return .closeRequested
            case .requesttimeout: page = .invocationoptions
            case .model, .response, .invocationoptions, .autonomy, .capabilities, .usage:
                page = .root
            case .domains, .types:
                page = .capabilities
            case .domain: page = .domains
            case .type: page = .types
            case .items(let domain, let type):
                // Path shape determines which parent should receive focus.
                page = itemParentIsDomain ? .domain(domain) : .type(type)
            case .search:
                page = returnFromSearch
            }
            refresh(snapshot, currentID: page == .root ? rootSelection : nil)
            return nil
        case .unavailable(let id):
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
        case .accepted(let id):
            return accept(id, snapshot: &snapshot)
        case .toggled(let id):
            if case .capability(let id) = id {
                return toggle(id, availability: true, snapshot: &snapshot)
            }
            return nil
        }
    }

    func render(into frame: inout TerminalFrame, in region: TerminalRegion) {
        menu.render(
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
        var selectedRow: RowID?
        switch id {
        case .model:
            rootSelection = .model
            page = .model
            selectedRow = .modelProfile(snapshot.preferredModelProfileID)
        case .response:
            rootSelection = .response
            page = .response
            selectedRow = .responseDelivery(snapshot.selectedResponseDelivery)
        case .invocationoptions:
            rootSelection = .invocationoptions
            page = .invocationoptions
            selectedRow = .requesttimeout
        case .requesttimeout:
            page = .requesttimeout
            selectedRow = .timeoutseconds(snapshot.selectedInvocationOptions.timeoutseconds)
        case .autonomy:
            rootSelection = .autonomy
            page = .autonomy
            selectedRow = .autonomyMode(snapshot.selectedAutonomyMode)
        case .capabilities:
            rootSelection = .capabilities
            page = .capabilities
        case .usage:
            rootSelection = .usage
            page = .usage
        case .usageTokens, .usageCost, .usageProvenance:
            return nil
        case .domains:
            page = .domains
            returnFromSearch = .domain("")
        case .types:
            page = .types
            returnFromSearch = .type(.tool)
        case .domain(let domain):
            if case .type(let type) = page {
                itemParentIsDomain = false
                page = .items(domain: domain, type: type)
            } else {
                page = .domain(domain)
            }
        case .type(let type):
            if case .domain(let domain) = page {
                itemParentIsDomain = true
                page = .items(domain: domain, type: type)
            } else {
                page = .type(type)
            }
        case .search:
            returnFromSearch = page
            page = .search
            searchQuery = ""
            isEditingSearch = true
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
            page = .root
            refresh(snapshot, currentID: rootSelection)
            return .conversation(.modelPreferenceChanged(identifier))
        case .responseDelivery(let delivery):
            if delivery == .stream && !Self.preferredModelSupportsStreaming(snapshot) {
                return .conversation(.feedbackRequested("Streaming is unavailable for the selected model."))
            }
            snapshot.selectedResponseDelivery = delivery
            page = .root
            refresh(snapshot, currentID: rootSelection)
            return .conversation(.responseDeliverySelectionChanged(delivery))
        case .timeoutseconds(let seconds):
            var options = snapshot.selectedInvocationOptions
            options.timeoutseconds = seconds
            snapshot.selectedInvocationOptions = options
            page = .invocationoptions
            refresh(snapshot, currentID: .requesttimeout)
            return .conversation(.invocationOptionsSelectionChanged(options))
        case .autonomyMode(let mode):
            snapshot.selectedAutonomyMode = mode
            page = .root
            refresh(snapshot, currentID: rootSelection)
            return .conversation(.autonomySelectionChanged(mode))
        }
        refresh(snapshot, currentID: selectedRow)
        return nil
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
            refresh(snapshot, currentID: .capability(identifier))
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
        refresh(snapshot, currentID: .capability(identifier))
        return .conversation(.capabilitySelectionChanged(
            available: snapshot.availableCapabilities,
            visible: snapshot.visibleCapabilities
        ))
    }

    private mutating func refresh(_ snapshot: AgenticConversationSnapshot, currentID: RowID?) {
        menu = Self.menu(
            snapshot: snapshot,
            page: page,
            currentID: currentID ?? selections[page],
            query: searchQuery,
            filter: filter,
            editingSearch: isEditingSearch
        )
        if let currentID = menu.currentID { selections[page] = currentID }
    }
}

private extension AgenticConversationSettingsControl.Page {
    var isBrowser: Bool {
        switch self {
        case .capabilities, .domains, .types, .domain, .type, .items, .search: return true
        default: return false
        }
    }
}

private extension AgenticConversationSettingsControl {
    static func menu(snapshot: AgenticConversationSnapshot, page: Page,
                     currentID: RowID?, query: String, filter: Filter, editingSearch: Bool) -> TerminalSettingsMenuControl<RowID>
    {
        var path: [String] = []
        let rows: [TerminalSettingsRow<RowID>]
        var hint = "j/k move  enter select  / search  f filter  J/K detail  q back"
        let entries = filtered(snapshot.capabilityEntries, snapshot: snapshot, filter: filter)
        switch page {
        case .root:
            rows = rootRows(snapshot)
        case .model:
            path = ["Model"]
            rows = snapshot.models.map { model in
                TerminalSettingsRow(id: .modelProfile(model.id), title: model.title,
                    value: model.isAvailable ? nil : "unavailable",
                    isEnabled: model.isAvailable,
                    accessory: .radio(selected: model.id == snapshot.preferredModelProfileID),
                    detail: .init(title: model.title, body: model.detail))
            }
        case .response:
            path = ["Response"]
            rows = responseDeliveryRows(snapshot)
        case .invocationoptions:
            path = ["Invocation options"]
            rows = invocationOptionsRows(snapshot)
        case .requesttimeout:
            path = ["Invocation options", "Request timeout"]
            rows = requestTimeoutRows(snapshot)
        case .autonomy:
            path = ["Autonomy"]
            rows = autonomyRows(snapshot)
        case .usage:
            path = ["Usage"]
            rows = usageRows(snapshot.usage)
            hint = "Read-only · consumption and cost provenance · J/K detail · q back"
        case .capabilities:
            path = ["Capabilities"]
            rows = [
                .init(id: .search, title: "Search", value: "Press / to search", accessory: .disclosure),
                .init(id: .domains, title: "Domain first", accessory: .disclosure),
                .init(id: .types, title: "Type first", accessory: .disclosure),
            ]
        case .domains:
            path = ["Capabilities", "Domain first"]
            rows = domains(entries).map { domain in
                .init(id: .domain(domain), title: domain, accessory: .disclosure)
            }
        case .types:
            path = ["Capabilities", "Type first"]
            rows = AgenticConversationCapabilityEntry.Kind.allCases.map { kind in
                .init(id: .type(kind), title: kind.title, accessory: .disclosure)
            }
        case .domain(let domain):
            path = ["Capabilities", "Domain first", domain]
            rows = AgenticConversationCapabilityEntry.Kind.allCases.filter { kind in
                entries.contains { $0.domain == domain && $0.kind == kind }
            }.map { kind in
                .init(id: .type(kind), title: kind.title, accessory: .disclosure)
            }
        case .type(let kind):
            path = ["Capabilities", "Type first", kind.title]
            rows = domains(entries).filter { domain in
                entries.contains { $0.domain == domain && $0.kind == kind }
            }.map { domain in
                .init(id: .domain(domain), title: domain, accessory: .disclosure)
            }
        case .items(let domain, let kind):
            path = ["Capabilities", domain, kind.title]
            rows = entries.filter {
                $0.domain == domain && $0.kind == kind
            }.map { capabilityRow($0, snapshot: snapshot) }
            hint = "\(rows.count) matches · \(filter.rawValue) · enter visible  space available  / search  f filter  J/K detail"
        case .search:
            path = ["Capabilities", "Search"]
            rows = AgenticConversationCapabilityEntry.search(
                query,
                in: entries
            ).map { capabilityRow($0, snapshot: snapshot) }
            hint = "\(rows.count) matches · \(filter.rawValue) · /\(query)\(editingSearch ? "▏" : "") · "
                + (editingSearch ? "type query  enter done  esc stop" : "/ edit  f filter  enter visible  space available")
        }
        return TerminalSettingsMenuControl(
            title: "Conversation settings",
            path: path, rows: rows,
            currentID: currentID, instructions: hint
        )
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
                value: isSelected ? "Selected" : "Not selected",
                accessory: .checkbox(selected: isSelected),
                detail: .init(title: entry.title,
                    fields: [.init("identifier", entry.identifier), .init("domain", entry.domain)],
                    body: entry.summary))
        }
        let enabled = entry.capability.intersecting(snapshot.availableCapabilities) != .none
        let visible = entry.capability.intersecting(snapshot.visibleCapabilities) != .none
        return .init(id: .capability(entry.id), title: entry.title,
            value: visible ? "Visible" : (enabled ? "Available" : "Unavailable"),
            caption: "Enter: visibility · Space: availability",
            accessory: .checkbox(selected: enabled),
            detail: .init(title: entry.title,
                fields: [.init("identifier", entry.identifier),
                         .init("domain", entry.domain),
                         .init("type", entry.kind.rawValue)],
                body: entry.summary))
    }
    static func rootRows(_ snapshot: AgenticConversationSnapshot) -> [TerminalSettingsRow<RowID>] {
        let model = snapshot.models.first { $0.id == snapshot.preferredModelProfileID }
        let visibleCount = snapshot.visibleCapabilities.tools.count
            + snapshot.visibleCapabilities.programs.count
            + snapshot.visibleCapabilities.inferences.count
            + snapshot.visibleCapabilities.agents.count
        return [
            .init(id: .model, title: "Model", value: model?.title,
                  accessory: .disclosure),
            .init(id: .response, title: "Response",
                  value: responseDeliveryTitle(snapshot.selectedResponseDelivery),
                  accessory: .disclosure),
            .init(id: .invocationoptions, title: "Invocation options",
                  value: requestTimeoutTitle(snapshot.selectedInvocationOptions.timeoutseconds),
                  accessory: .disclosure),
            .init(id: .autonomy, title: "Autonomy",
                  value: autonomyTitle(snapshot.selectedAutonomyMode),
                  accessory: .disclosure),
            .init(id: .capabilities, title: "Capabilities",
                  value: "\(visibleCount) visible · \(snapshot.selectedInstructionIDs.count) instructions",
                  accessory: .disclosure),
            .init(id: .usage, title: "Usage", value: snapshot.usage.shortSummary,
                  accessory: .disclosure),
        ]
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
