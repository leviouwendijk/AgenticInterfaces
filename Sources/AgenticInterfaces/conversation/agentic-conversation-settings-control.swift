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
        case exposure
        case skills
    }

    private enum RowID: Sendable, Hashable {
        case model
        case exposure
        case skills
        case modelProfile(AgentModelProfileIdentifier)
        case discovery
        case allTools
        case skillSeeded
        case explicit
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
            open(.root, snapshot: snapshot, currentID: rootSelection)
            return .conversation(.modelSelectionChanged(identifier))

        case .discovery:
            return selectExposure(.discovery, snapshot: &snapshot)

        case .allTools:
            return selectExposure(.all, snapshot: &snapshot)

        case .skillSeeded:
            guard !snapshot.selectedSkillIDs.isEmpty
                    || snapshot.selectedToolExposure == .skillSeeded
            else {
                return .conversation(
                    .feedbackRequested(
                        "Select at least one skill before using skill-seeded exposure."
                    )
                )
            }
            return selectExposure(.skillSeeded, snapshot: &snapshot)

        case .explicit:
            return .conversation(
                .feedbackRequested(
                    "Explicit tool exposure requires a fixed tool picker."
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
        case .explicit:
            return "Explicit tool exposure requires a fixed tool picker."
        case .skillSeeded:
            return "Select at least one skill before using skill-seeded exposure."
        case .skills:
            return "No skills are registered."
        case .modelProfile(let identifier):
            let title = snapshot.models.first {
                $0.id == identifier
            }?.title ?? identifier.rawValue
            return "Model '\(title)' is unavailable."
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
                id: .skillSeeded,
                title: AgenticConversationToolExposure.skillSeeded.title,
                caption: snapshot.selectedSkillIDs.isEmpty
                    ? "Select a skill first."
                    : nil,
                isEnabled: !snapshot.selectedSkillIDs.isEmpty
                    || snapshot.selectedToolExposure == .skillSeeded,
                accessory: .radio(
                    selected: snapshot.selectedToolExposure == .skillSeeded
                ),
                detail: exposureDetail(.skillSeeded, snapshot: snapshot)
            ),
            TerminalSettingsRow(
                id: .explicit,
                title: "Explicit",
                caption: "Fixed tool picker not installed yet.",
                isEnabled: false,
                accessory: .radio(selected: false),
                detail: TerminalSettingsDetail(
                    title: "Explicit",
                    body: "Expose a fixed set of tools once an explicit tool picker is installed."
                )
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

        case .skillSeeded:
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
                    ? "No selected skill tools are currently seeded."
                    : "Seed selected skill tools and keep other capabilities discoverable."
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
        case .skillSeeded:
            return .skillSeeded
        }
    }
}
