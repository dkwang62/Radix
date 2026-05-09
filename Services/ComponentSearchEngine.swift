import Foundation

enum ComponentSearchEngine {
    static func search(
        query: String,
        allCharacters: [String],
        byCharacter: [String: ComponentItem],
        limit: Int,
        matchesScriptFilter: (ComponentItem) -> Bool
    ) -> [ComponentItem] {
        if query.isEmpty {
            return allCharacters
                .compactMap { byCharacter[$0] }
                .filter(matchesScriptFilter)
                .prefix(limit)
                .map { $0 }
        }

        let normalized = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let exactPinyinQuery = normalizePinyin(query, fuzzyInitials: false)
        let normalizedPinyinQuery = normalizePinyin(query)

        if normalized.count == 1, let exact = byCharacter[normalized], matchesScriptFilter(exact) {
            return [exact]
        }

        let directCharMatch = byCharacter[query].map { item in
            matchesScriptFilter(item) ? [item] : []
        } ?? []

        let ranked = allCharacters.compactMap { key -> (item: ComponentItem, rank: Int, tokenLen: Int, token: String)? in
            guard let item = byCharacter[key] else { return nil }
            guard matchesScriptFilter(item) else { return nil }

            let exactTokens = item.pinyin.map { normalizePinyin($0, fuzzyInitials: false) }.filter { !$0.isEmpty }
            let exactCompact = exactTokens.joined()
            let normalizedTokens = item.pinyin.map { normalizePinyin($0) }.filter { !$0.isEmpty }
            let normalizedCompact = normalizedTokens.joined()

            if !exactPinyinQuery.isEmpty, let exactToken = exactTokens.first(where: { $0 == exactPinyinQuery }) {
                return (item, 0, exactToken.count, exactToken)
            }
            if !exactPinyinQuery.isEmpty, let prefixToken = exactTokens.first(where: { $0.hasPrefix(exactPinyinQuery) }) {
                return (item, 1, prefixToken.count, prefixToken)
            }
            if !exactPinyinQuery.isEmpty, let containsToken = exactTokens.first(where: { $0.contains(exactPinyinQuery) }) {
                return (item, 2, containsToken.count, containsToken)
            }
            if !exactPinyinQuery.isEmpty, exactCompact.contains(exactPinyinQuery) {
                return (item, 3, exactCompact.count, exactCompact)
            }
            if !normalizedPinyinQuery.isEmpty, let exactToken = normalizedTokens.first(where: { $0 == normalizedPinyinQuery }) {
                return (item, 4, exactToken.count, exactToken)
            }
            if !normalizedPinyinQuery.isEmpty, let prefixToken = normalizedTokens.first(where: { $0.hasPrefix(normalizedPinyinQuery) }) {
                return (item, 5, prefixToken.count, prefixToken)
            }
            if !normalizedPinyinQuery.isEmpty, let containsToken = normalizedTokens.first(where: { $0.contains(normalizedPinyinQuery) }) {
                return (item, 6, containsToken.count, containsToken)
            }
            if !normalizedPinyinQuery.isEmpty, normalizedCompact.contains(normalizedPinyinQuery) {
                return (item, 7, normalizedCompact.count, normalizedCompact)
            }
            if item.searchableText.contains(normalized) {
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
        allCharacters: [String],
        byCharacter: [String: ComponentItem],
        limit: Int,
        isStrict: Bool,
        matchesScriptFilter: (ComponentItem) -> Bool
    ) -> [ComponentItem] {
        let normalized = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count >= 2 else { return [] }

        return allCharacters.compactMap { key in
            guard let item = byCharacter[key] else { return nil }
            guard matchesScriptFilter(item) else { return nil }

            let definition = item.definition.lowercased()
            if isStrict {
                let pattern = "\\b\(NSRegularExpression.escapedPattern(for: normalized))\\b"
                return definition.range(of: pattern, options: .regularExpression) != nil ? item : nil
            }
            return definition.contains(normalized) ? item : nil
        }
        .prefix(limit)
        .map { $0 }
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
