import Foundation

struct PhrasePinyinSearchIndex {
    private var rows: [(item: PhraseItem, exact: String, exactCompact: String, normalized: String, compact: String)] = []
    private(set) var isBuilt = false

    mutating func rebuild(with phrases: [PhraseItem]) {
        isBuilt = true
        var built: [(item: PhraseItem, exact: String, exactCompact: String, normalized: String, compact: String)] = []
        built.reserveCapacity(phrases.count)
        for item in phrases {
            let exact = normalizeLoose(item.pinyin, fuzzyInitials: false)
            let exactCompact = normalize(item.pinyin, fuzzyInitials: false)
            let normalized = normalizeLoose(item.pinyin)
            let compact = normalize(item.pinyin)
            if !exactCompact.isEmpty || !compact.isEmpty {
                built.append((item, exact, exactCompact, normalized, compact))
            }
        }
        built.sort { lhs, rhs in
            if lhs.item.word.count != rhs.item.word.count {
                return lhs.item.word.count < rhs.item.word.count
            }
            return lhs.item.word < rhs.item.word
        }
        rows = built
    }

    mutating func reset() {
        rows = []
        isBuilt = false
    }

    func search(term: String, limit: Int) -> [PhraseItem] {
        let exactQuery = normalizeLoose(term, fuzzyInitials: false)
        let exactCompactQuery = exactQuery.replacingOccurrences(of: " ", with: "")
        let normalizedQuery = normalizeLoose(term)
        let compactQuery = normalizedQuery.replacingOccurrences(of: " ", with: "")
        guard compactQuery.count >= 2, !rows.isEmpty else { return [] }

        var exactMatches: [PhraseItem] = []
        var normalizedMatches: [PhraseItem] = []
        exactMatches.reserveCapacity(min(limit, 200))
        normalizedMatches.reserveCapacity(min(limit, 200))
        for row in rows {
            if row.exact.contains(exactQuery) || row.exactCompact.contains(exactCompactQuery) {
                exactMatches.append(row.item)
            } else if row.normalized.contains(normalizedQuery) || row.compact.contains(compactQuery) {
                normalizedMatches.append(row.item)
            }
            if exactMatches.count + normalizedMatches.count >= limit {
                break
            }
        }
        return Array((exactMatches + normalizedMatches).prefix(limit))
    }

    private func normalize(_ value: String, fuzzyInitials: Bool = true) -> String {
        PinyinSearchNormalizer.normalize(value, fuzzyInitials: fuzzyInitials)
    }

    private func normalizeLoose(_ value: String, fuzzyInitials: Bool = true) -> String {
        PinyinSearchNormalizer.normalize(value, preservingSpaces: true, fuzzyInitials: fuzzyInitials)
    }
}
