import Agentic
import Guidelines


enum AgenticGuidelinePresentation {
    static func summary(
        _ relations: [AgentGuidelineRelation]
    ) -> String? {
        guard !relations.isEmpty else {
            return nil
        }

        return relations.map { relation in
            guard let guideline = Guideline(
                reference: relation.reference
            ) else {
                return "\(relation.relationship.rawValue)  \(relation.reference.rawValue) [unresolved]"
            }

            return "\(relation.relationship.rawValue)  \(guideline.title)"
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
            var lines: [String]

            if let guideline = Guideline(
                reference: relation.reference
            ) {
                lines = [
                    "\(relation.relationship.rawValue)  \(guideline.title)",
                    "    reference  \(guideline.reference)",
                    "    summary    \(guideline.summary)",
                ]
            } else {
                lines = [
                    "\(relation.relationship.rawValue)  \(relation.reference.rawValue)",
                    "    status     unresolved current Guideline reference",
                ]
            }

            if let reasoning = relation.reasoning,
               !reasoning.isEmpty
            {
                lines.append(
                    "    rationale  \(reasoning)"
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
