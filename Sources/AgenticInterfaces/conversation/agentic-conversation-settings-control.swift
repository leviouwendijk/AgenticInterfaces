import Agentic
import Terminal

enum AgenticConversationSettingsControlEvent: Sendable, Hashable {
    case closeRequested
    case conversation(AgenticConversationEvent)
}

struct AgenticConversationSettingsControl: Sendable {
    private enum Page: Sendable, Hashable {
        case root
        case model
        case response
        case autonomy
        case exposure
        case skills
    }

    private enum RowID: Sendable, Hashable {
        case model
        case response
        case autonomy
        case exposure
        case skills
        case modelProfile(AgentModelProfileIdentifier)
        case responseDelivery(AgentModelResponseDelivery)
        case autonomyMode(AutonomyMode)
        case discovery
        case allTools
        case skill_seeded
        case custom
        case skill(AgentSkillIdentifier)
    }

    private var page: Page
    private var rootSelection: RowID
    private var menu: TerminalSettingsMenuControl<RowID>

    init(snapshot: AgenticConversationSnapshot) {
        page = .root
        rootSelection = .model
        menu = Self.menu(
            snapshot: snapshot,
            page: .root,
            currentID: .model
        )
    }

    mutating func update(_ snapshot: AgenticConversationSnapshot) {
        menu = Self.menu(
            snapshot: snapshot,
            page: page,
            currentID: menu.currentID
        )
    }

    mutating func openRoot(_ snapshot: AgenticConversationSnapshot) {
        rootSelection = .model
        open(.root, snapshot: snapshot, currentID: rootSelection)
    }

    mutating func openModel(_ snapshot: AgenticConversationSnapshot) {
        open(
            .model,
            snapshot: snapshot,
            currentID: .modelProfile(snapshot.selectedModelProfileID)
        )
    }

    mutating func handle(
        _ key: TerminalKey,
        snapshot: inout AgenticConversationSnapshot
    ) -> AgenticConversationSettingsControlEvent? {
        guard let event = menu.handle(key) else {
            return nil
        }

        switch event {
        case .currentChanged:
            return nil

        case .cancelRequested:
            guard page != .root else {
                return .closeRequested
            }
            open(.root, snapshot: snapshot, currentID: rootSelection)
            return nil

        case .unavailable(let id):
            return .conversation(
                .feedbackRequested(unavailableMessage(id, snapshot: snapshot))
            )

        case .accepted(let id):
            return accept(id, snapshot: &snapshot)

        case .toggled(let id):
            guard case .skill(let identifier) = id else {
                return nil
            }
            return toggleSkill(identifier, snapshot: &snapshot)
        }
    }

    func render(
        into frame: inout TerminalFrame,
        in region: TerminalRegion
    ) {
        menu.render(
            into: &frame,
            in: region,
            theme: .agentic,
            columns: min(86, max(48, region.columns - 4)),
            rows: min(24, max(12, region.rows - 2))
        )
    }
}

private extension AgenticConversationSettingsControl {
    private mutating func accept(
        _ id: RowID,
        snapshot: inout AgenticConversationSnapshot
    ) -> AgenticConversationSettingsControlEvent? {
        switch id {
        case .model:
            rootSelection = .model
            open(
                .model,
                snapshot: snapshot,
                currentID: .modelProfile(snapshot.selectedModelProfileID)
            )
            return nil

        case .response:
            rootSelection = .response
            open(
                .response,
                snapshot: snapshot,
                currentID: .responseDelivery(
                    snapshot.selectedResponseDelivery
                )
            )
            return nil

        case .autonomy:
            rootSelection = .autonomy
            open(
                .autonomy,
                snapshot: snapshot,
                currentID: .autonomyMode(snapshot.selectedAutonomyMode)
            )
            return nil

        case .exposure:
            rootSelection = .exposure
            open(
                .exposure,
                snapshot: snapshot,
                currentID: Self.exposureRowID(snapshot.selectedToolExposure)
            )
            return nil

        case .skills:
            guard !snapshot.skills.isEmpty else {
                return .conversation(
                    .feedbackRequested("No skills are registered.")
                )
            }
            rootSelection = .skills
            open(
                .skills,
                snapshot: snapshot,
                currentID: snapshot.skills.first.map { .skill($0.id) }
            )
            return nil

        case .modelProfile(let identifier):
            guard let model = snapshot.models.first(where: {
                $0.id == identifier
            }),
                  model.isAvailable
            else {
                return .conversation(
                    .feedbackRequested("Selected model is unavailable.")
                )
            }

            snapshot.selectedModelProfileID = identifier

            if !model.supportsStreaming {
                snapshot.selectedResponseDelivery = .buffered
            }

            open(.root, snapshot: snapshot, currentID: rootSelection)
            return .conversation(.modelSelectionChanged(identifier))

        case .responseDelivery(let delivery):
            if delivery == .stream,
               !Self.selectedModelSupportsStreaming(snapshot)
            {
                return .conversation(
                    .feedbackRequested(
                        "Streaming is unavailable for the selected model."
                    )
                )
            }

            return selectResponseDelivery(
                delivery,
                snapshot: &snapshot
            )

        case .autonomyMode(let mode):
            return selectAutonomy(mode, snapshot: &snapshot)

        case .discovery:
            return selectExposure(.discovery, snapshot: &snapshot)

        case .allTools:
            return selectExposure(.all, snapshot: &snapshot)

        case .skill_seeded:
            guard !snapshot.selectedSkillIDs.isEmpty
                    || snapshot.selectedToolExposure == .skill_seeded
            else {
                return .conversation(
                    .feedbackRequested(
                        "Select at least one skill before using skill-seeded exposure."
                    )
                )
            }
            return selectExposure(.skill_seeded, snapshot: &snapshot)

        case .custom:
            return .conversation(
                .feedbackRequested(
                    "Custom tool exposure requires the tool picker."
                )
            )

        case .skill(let identifier):
            return toggleSkill(identifier, snapshot: &snapshot)
        }
    }

    mutating func toggleSkill(
        _ identifier: AgentSkillIdentifier,
        snapshot: inout AgenticConversationSnapshot
    ) -> AgenticConversationSettingsControlEvent {
        var selected = Set(snapshot.selectedSkillIDs)

        if selected.contains(identifier) {
            selected.remove(identifier)
        } else {
            selected.insert(identifier)
        }

        snapshot.selectedSkillIDs = snapshot.skills.compactMap {
            selected.contains($0.id) ? $0.id : nil
        }
        open(
            .skills,
            snapshot: snapshot,
            currentID: .skill(identifier)
        )

        return .conversation(
            .skillSelectionChanged(snapshot.selectedSkillIDs)
        )
    }

    mutating func selectResponseDelivery(
        _ delivery: AgentModelResponseDelivery,
        snapshot: inout AgenticConversationSnapshot
    ) -> AgenticConversationSettingsControlEvent {
        snapshot.selectedResponseDelivery = delivery
        open(.root, snapshot: snapshot, currentID: rootSelection)
        return .conversation(
            .responseDeliverySelectionChanged(delivery)
        )
    }

    mutating func selectAutonomy(
        _ mode: AutonomyMode,
        snapshot: inout AgenticConversationSnapshot
    ) -> AgenticConversationSettingsControlEvent {
        snapshot.selectedAutonomyMode = mode
        open(.root, snapshot: snapshot, currentID: rootSelection)
        return .conversation(.autonomySelectionChanged(mode))
    }

    mutating func selectExposure(
        _ exposure: AgenticConversationToolExposure,
        snapshot: inout AgenticConversationSnapshot
    ) -> AgenticConversationSettingsControlEvent {
        snapshot.selectedToolExposure = exposure
        open(.root, snapshot: snapshot, currentID: rootSelection)
        return .conversation(.toolExposureSelectionChanged(exposure))
    }

    private mutating func open(
        _ page: Page,
        snapshot: AgenticConversationSnapshot,
        currentID: RowID?
    ) {
        self.page = page
        menu = Self.menu(
            snapshot: snapshot,
            page: page,
            currentID: currentID
        )
    }

    private func unavailableMessage(
        _ id: RowID,
        snapshot: AgenticConversationSnapshot
    ) -> String {
        switch id {
        case .custom:
            return "Custom tool exposure requires the tool picker."
        case .skill_seeded:
            return "Select at least one skill before using skill-seeded exposure."
        case .skills:
            return "No skills are registered."
        case .modelProfile(let identifier):
            let title = snapshot.models.first {
                $0.id == identifier
            }?.title ?? identifier.rawValue
            return "Model '\(title)' is unavailable."
        case .responseDelivery(.stream):
            return "Streaming is unavailable for the selected model."
        default:
            return "Selection is unavailable."
        }
    }

    private static func menu(
        snapshot: AgenticConversationSnapshot,
        page: Page,
        currentID: RowID?
    ) -> TerminalSettingsMenuControl<RowID> {
        let path: [String]
        let rows: [TerminalSettingsRow<RowID>]
        let instructions: String

        switch page {
        case .root:
            path = []
            rows = rootRows(snapshot)
            instructions = "j/k move  enter open  q close"

        case .model:
            path = ["Model"]
            rows = snapshot.models.map { model in
                TerminalSettingsRow(
                    id: .modelProfile(model.id),
                    title: model.title,
                    value: model.isAvailable ? nil : "unavailable",
                    isEnabled: model.isAvailable,
                    accessory: .radio(
                        selected: model.id == snapshot.selectedModelProfileID
                    ),
                    detail: TerminalSettingsDetail(
                        title: model.title,
                        fields: [
                            TerminalField("profile", model.id.rawValue),
                        ],
                        body: model.detail
                    )
                )
            }
            instructions = "j/k move  enter select  q back"

        case .response:
            path = ["Response"]
            rows = responseDeliveryRows(snapshot)
            instructions = "j/k move  enter select  q back"

        case .autonomy:
            path = ["Autonomy"]
            rows = autonomyRows(snapshot)
            instructions = "j/k move  enter select  q back"

        case .exposure:
            path = ["Tool exposure"]
            rows = exposureRows(snapshot)
            instructions = "j/k move  enter select  q back"

        case .skills:
            path = ["Skills"]
            rows = snapshot.skills.map { skill in
                TerminalSettingsRow(
                    id: .skill(skill.id),
                    title: skill.title,
                    accessory: .checkbox(
                        selected: snapshot.selectedSkillIDs.contains(skill.id)
                    ),
                    detail: TerminalSettingsDetail(
                        title: skill.title,
                        fields: [
                            TerminalField(
                                "tools",
                                skill.toolNames.isEmpty
                                    ? "none"
                                    : skill.toolNames.joined(separator: ", ")
                            ),
                        ],
                        body: skill.summary
                    )
                )
            }
            instructions = "j/k move  space toggle  q back"
        }

        return TerminalSettingsMenuControl(
            title: "Conversation settings",
            path: path,
            rows: rows,
            currentID: currentID,
            instructions: instructions
        )
    }

    private static func rootRows(
        _ snapshot: AgenticConversationSnapshot
    ) -> [TerminalSettingsRow<RowID>] {
        let model = snapshot.models.first {
            $0.id == snapshot.selectedModelProfileID
        }

        return [
            TerminalSettingsRow(
                id: .model,
                title: "Model",
                value: model?.title ?? snapshot.selectedModelProfileID.rawValue,
                accessory: .disclosure,
                detail: TerminalSettingsDetail(
                    title: model?.title ?? snapshot.selectedModelProfileID.rawValue,
                    body: model?.detail
                )
            ),
            TerminalSettingsRow(
                id: .response,
                title: "Response",
                value: responseDeliveryTitle(
                    snapshot.selectedResponseDelivery
                ),
                accessory: .disclosure,
                detail: responseDeliveryDetail(
                    snapshot.selectedResponseDelivery,
                    snapshot: snapshot
                )
            ),
            TerminalSettingsRow(
                id: .autonomy,
                title: "Autonomy",
                value: autonomyTitle(snapshot.selectedAutonomyMode),
                accessory: .disclosure,
                detail: autonomyDetail(snapshot.selectedAutonomyMode)
            ),
            TerminalSettingsRow(
                id: .exposure,
                title: "Tool exposure",
                value: snapshot.selectedToolExposure.title,
                accessory: .disclosure,
                detail: exposureDetail(
                    snapshot.selectedToolExposure,
                    snapshot: snapshot
                )
            ),
            TerminalSettingsRow(
                id: .skills,
                title: "Skills",
                value: skillValue(snapshot),
                isEnabled: !snapshot.skills.isEmpty,
                accessory: .disclosure,
                detail: TerminalSettingsDetail(
                    title: "Skills",
                    fields: [
                        TerminalField("selected", skillValue(snapshot)),
                    ],
                    body: "Skills provide task context independently of tool exposure."
                )
            ),
        ]
    }

    private static func responseDeliveryRows(
        _ snapshot: AgenticConversationSnapshot
    ) -> [TerminalSettingsRow<RowID>] {
        let supportsStreaming = selectedModelSupportsStreaming(
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
        let supportsStreaming = selectedModelSupportsStreaming(
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

    private static func selectedModelSupportsStreaming(
        _ snapshot: AgenticConversationSnapshot
    ) -> Bool {
        snapshot.models.first {
            $0.id == snapshot.selectedModelProfileID
        }?.supportsStreaming ?? true
    }

    private static func exposureRows(
        _ snapshot: AgenticConversationSnapshot
    ) -> [TerminalSettingsRow<RowID>] {
        [
            exposureRow(
                id: .discovery,
                exposure: .discovery,
                snapshot: snapshot
            ),
            exposureRow(
                id: .allTools,
                exposure: .all,
                snapshot: snapshot
            ),
            TerminalSettingsRow(
                id: .skill_seeded,
                title: AgenticConversationToolExposure.skill_seeded.title,
                caption: snapshot.selectedSkillIDs.isEmpty
                    ? "Select a skill first."
                    : nil,
                isEnabled: !snapshot.selectedSkillIDs.isEmpty
                    || snapshot.selectedToolExposure == .skill_seeded,
                accessory: .radio(
                    selected: snapshot.selectedToolExposure == .skill_seeded
                ),
                detail: exposureDetail(.skill_seeded, snapshot: snapshot)
            ),
            TerminalSettingsRow(
                id: .custom,
                title: AgenticConversationToolExposure.custom.title,
                caption: "Tool picker wiring follows this state pass.",
                isEnabled: false,
                accessory: .radio(
                    selected: snapshot.selectedToolExposure == .custom
                ),
                detail: exposureDetail(.custom, snapshot: snapshot)
            ),
        ]
    }

    private static func exposureRow(
        id: RowID,
        exposure: AgenticConversationToolExposure,
        snapshot: AgenticConversationSnapshot
    ) -> TerminalSettingsRow<RowID> {
        TerminalSettingsRow(
            id: id,
            title: exposure.title,
            accessory: .radio(
                selected: snapshot.selectedToolExposure == exposure
            ),
            detail: exposureDetail(exposure, snapshot: snapshot)
        )
    }

    static func exposureDetail(
        _ exposure: AgenticConversationToolExposure,
        snapshot: AgenticConversationSnapshot
    ) -> TerminalSettingsDetail {
        switch exposure {
        case .discovery:
            return TerminalSettingsDetail(
                title: exposure.title,
                fields: [
                    TerminalField("initial tools", "find_tools"),
                    TerminalField("dynamic", "yes"),
                ],
                body: "Start small and activate registered capabilities as needed."
            )

        case .all:
            return TerminalSettingsDetail(
                title: exposure.title,
                fields: [
                    TerminalField("initial tools", "all model-facing"),
                    TerminalField("dynamic", "no"),
                ],
                body: "Advertise every registered model-facing tool immediately."
            )

        case .skill_seeded:
            let tools = selectedSkillTools(snapshot)
            return TerminalSettingsDetail(
                title: exposure.title,
                fields: [
                    TerminalField(
                        "initial tools",
                        (["find_tools"] + tools).joined(separator: ", ")
                    ),
                    TerminalField("dynamic", "yes"),
                ],
                body: tools.isEmpty
                    ? "No required tools from selected skills are currently seeded."
                    : "Seed required tools from selected skills and keep other capabilities discoverable."
            )

        case .custom:
            return TerminalSettingsDetail(
                title: exposure.title,
                fields: [
                    TerminalField(
                        "selected",
                        "\(snapshot.customToolSelection.identifiers.count) tools"
                    ),
                    TerminalField(
                        "dynamic",
                        snapshot.customToolSelection.dynamicDiscovery
                            ? "yes"
                            : "no"
                    ),
                ],
                body: "Expose an exact saved tool selection plus required tools from selected skills. Dynamic discovery may be disabled for a fixed explicit posture."
            )
        }
    }

    static func skillValue(
        _ snapshot: AgenticConversationSnapshot
    ) -> String {
        let selected = snapshot.skills.filter {
            snapshot.selectedSkillIDs.contains($0.id)
        }

        if selected.isEmpty {
            return "None"
        }
        if selected.count == 1 {
            return selected[0].title
        }
        return "\(selected.count) selected"
    }

    static func selectedSkillTools(
        _ snapshot: AgenticConversationSnapshot
    ) -> [String] {
        Array(
            Set(
                snapshot.skills
                    .filter {
                        snapshot.selectedSkillIDs.contains($0.id)
                    }
                    .flatMap(\.toolNames)
            )
        ).sorted()
    }

    private static func exposureRowID(
        _ exposure: AgenticConversationToolExposure
    ) -> RowID {
        switch exposure {
        case .discovery:
            return .discovery
        case .all:
            return .allTools
        case .skill_seeded:
            return .skill_seeded
        case .custom:
            return .custom
        }
    }
}
