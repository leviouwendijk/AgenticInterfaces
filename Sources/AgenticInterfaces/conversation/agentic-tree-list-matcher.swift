import Search
import Terminal

/// Fuzzy, ranked matching for `TerminalTreeList`, the same search the
/// capability menu uses: every query term is required, scores rank.
public enum AgenticTreeListMatcher {
    public static func ranked<ID: Hashable & Sendable>(
        _ query: String,
        _ candidates: [(id: ID, text: String)]
    ) -> [ID: Int] {
        let terms = query.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !terms.isEmpty else {
            return [:]
        }
        let keys = candidates.indices.map { String($0) }
        let result = TextSearch.search(
            probes: terms.map { SearchProbe($0, role: .required, strategy: .fuzzy) },
            in: SearchCorpus(
                documents: candidates.indices.map { index in
                    SearchDocument(id: keys[index], text: candidates[index].text)
                }
            ),
            options: SearchOptions(
                mode: .ranked,
                strategy: .fuzzy,
                caseSensitive: false,
                minimumScore: 1,
                maximumResults: nil
            )
        )
        var scores: [ID: Int] = [:]
        for hit in result.hits {
            guard let index = Int(hit.documentID), candidates.indices.contains(index) else { continue }
            scores[candidates[index].id] = hit.score.value
        }
        return scores
    }
}
