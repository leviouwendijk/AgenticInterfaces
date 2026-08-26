import Agentic


enum AgenticGuidelinePresentation {
    static func summary(
        _ relations: [AgentGuidelineRelation]
    ) -> String? {
        guard !relations.isEmpty else {
            return nil
        }

        return relations.map { relation in
            "\(relation.relationship.rawValue)  \(relation.reference.rawValue)"
        }.joined(
            separator: "\n"
        )
    }

    static func details(
        _ relations: [AgentGuidelineRelation]
    ) -> String? {
        guard !relations.isEmpty else {
            return nil
        }

        return relations.map { relation in
            var lines = [
                "\(relation.relationship.rawValue)  \(relation.reference.rawValue)"
            ]

            if let reasoning = relation.reasoning,
               !reasoning.isEmpty
            {
                lines.append(
                    "    \(reasoning)"
                )
            }

            return lines.joined(
                separator: "\n"
            )
        }.joined(
            separator: "\n\n"
        )
    }
}
