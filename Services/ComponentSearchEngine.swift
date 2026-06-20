import Foundation

/// Immutable, platform-neutral search data built alongside the component repository.
///
/// Normalizing pinyin and assembling searchable text is proportional to the whole
/// dictionary, so doing it here avoids repeating that work for every keystroke.
struct ComponentSearchIndex {
    fileprivate struct Row {
        let item: ComponentItem
        let exactPinyinTokens: [String]
        let exactPinyinCompact: String
        let fuzzyPinyinTokens: [String]
        let fuzzyPinyinCompact: String
        let searchableText: String
        let normalizedDefinition: String
    }

    fileprivate let rows: [Row]
    private let byCharacter: [String: ComponentItem]

    init(allCharacters: [String] = [], byCharacter: [String: ComponentItem] = [:]) {
        self.byCharacter = byCharacter
        rows = allCharacters.compactMap { character in
            guard let item = byCharacter[character] else { return nil }
            let exactTokens = item.pinyin
                .map { PinyinSearchNormalizer.normalize($0, fuzzyInitials: false) }
                .filter { !$0.isEmpty }
            let fuzzyTokens = item.pinyin
                .map { PinyinSearchNormalizer.normalize($0) }
                .filter { !$0.isEmpty }
            return Row(
                item: item,
                exactPinyinTokens: exactTokens,
                exactPinyinCompact: exactTokens.joined(),
                fuzzyPinyinTokens: fuzzyTokens,
                fuzzyPinyinCompact: fuzzyTokens.joined(),
                searchableText: item.searchableText,
                normalizedDefinition: item.definition.lowercased()
            )
        }
    }

    fileprivate func item(for character: String) -> ComponentItem? {
        byCharacter[character]
    }
}

enum ComponentSearchEngine {
    static func search(
        query: String,
        index: ComponentSearchIndex,
        limit: Int,
        matchesScriptFilter: (ComponentItem) -> Bool
    ) -> [ComponentItem] {
        if query.isEmpty {
            var matches: [ComponentItem] = []
            matches.reserveCapacity(min(limit, index.rows.count))
            for row in index.rows where matchesScriptFilter(row.item) {
                matches.append(row.item)
                if matches.count == limit { break }
            }
            return matches
        }

        let normalized = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let exactPinyinQuery = normalizePinyin(query, fuzzyInitials: false)
        let normalizedPinyinQuery = normalizePinyin(query)

        if normalized.count == 1, let exact = index.item(for: normalized), matchesScriptFilter(exact) {
            return [exact]
        }

        let directCharMatch = index.item(for: query).map { item in
            matchesScriptFilter(item) ? [item] : []
        } ?? []

        let ranked = index.rows.compactMap { row -> (item: ComponentItem, rank: Int, tokenLen: Int, token: String)? in
            let item = row.item
            guard matchesScriptFilter(item) else { return nil }

            if !exactPinyinQuery.isEmpty, let exactToken = row.exactPinyinTokens.first(where: { $0 == exactPinyinQuery }) {
                return (item, 0, exactToken.count, exactToken)
            }
            if !exactPinyinQuery.isEmpty, let prefixToken = row.exactPinyinTokens.first(where: { $0.hasPrefix(exactPinyinQuery) }) {
                return (item, 1, prefixToken.count, prefixToken)
            }
            if !exactPinyinQuery.isEmpty, let containsToken = row.exactPinyinTokens.first(where: { $0.contains(exactPinyinQuery) }) {
                return (item, 2, containsToken.count, containsToken)
            }
            if !exactPinyinQuery.isEmpty, row.exactPinyinCompact.contains(exactPinyinQuery) {
                return (item, 3, row.exactPinyinCompact.count, row.exactPinyinCompact)
            }
            if !normalizedPinyinQuery.isEmpty, let exactToken = row.fuzzyPinyinTokens.first(where: { $0 == normalizedPinyinQuery }) {
                return (item, 4, exactToken.count, exactToken)
            }
            if !normalizedPinyinQuery.isEmpty, let prefixToken = row.fuzzyPinyinTokens.first(where: { $0.hasPrefix(normalizedPinyinQuery) }) {
                return (item, 5, prefixToken.count, prefixToken)
            }
            if !normalizedPinyinQuery.isEmpty, let containsToken = row.fuzzyPinyinTokens.first(where: { $0.contains(normalizedPinyinQuery) }) {
                return (item, 6, containsToken.count, containsToken)
            }
            if !normalizedPinyinQuery.isEmpty, row.fuzzyPinyinCompact.contains(normalizedPinyinQuery) {
                return (item, 7, row.fuzzyPinyinCompact.count, row.fuzzyPinyinCompact)
            }
            if row.searchableText.contains(normalized) {
                return (item, 8, 999, "")
            }
            return nil
        }
        .sorted { lhs, rhs in
            if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
            if lhs.tokenLen != rhs.tokenLen { return lhs.tokenLen < rhs.tokenLen }

            let lhsRank = lhs.item.rank ?? 999999
            let rhsRank = rhs.item.rank ?? 999999
            if lhsRank != rhsRank { return lhsRank < rhsRank }

            if lhs.item.usageCount != rhs.item.usageCount { return lhs.item.usageCount > rhs.item.usageCount }
            return lhs.item.character < rhs.item.character
        }
        .map(\.item)

        return Array((directCharMatch + ranked).orderedUnique().prefix(limit))
    }

    static func searchDefinitions(
        query: String,
        index: ComponentSearchIndex,
        limit: Int,
        isStrict: Bool,
        matchesScriptFilter: (ComponentItem) -> Bool
    ) -> [ComponentItem] {
        let normalized = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count >= 2 else { return [] }

        let strictPattern = isStrict
            ? "\\b\(NSRegularExpression.escapedPattern(for: normalized))\\b"
            : nil

        var matches: [ComponentItem] = []
        matches.reserveCapacity(min(limit, index.rows.count))
        for row in index.rows {
            let item = row.item
            guard matchesScriptFilter(item) else { continue }

            if let strictPattern {
                guard row.normalizedDefinition.range(of: strictPattern, options: .regularExpression) != nil else {
                    continue
                }
            } else if !row.normalizedDefinition.contains(normalized) {
                continue
            }

            matches.append(item)
            if matches.count == limit { break }
        }
        return matches
    }

    private static func normalizePinyin(_ value: String, fuzzyInitials: Bool = true) -> String {
        PinyinSearchNormalizer.normalize(value, fuzzyInitials: fuzzyInitials)
    }
}

private extension Array where Element: Hashable {
    func orderedUnique() -> [Element] {
        var seen = Set<Element>()
        var out: [Element] = []
        for item in self where !seen.contains(item) {
            seen.insert(item)
            out.append(item)
        }
        return out
    }
}
