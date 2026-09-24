import Foundation

enum PhraseStorageRules {
    static func canonicalWord(_ word: String, simplify: (String) -> String) -> String {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        let simplified = simplify(trimmed).trimmingCharacters(in: .whitespacesAndNewlines)
        return simplified.isEmpty ? trimmed : simplified
    }

    static func canonicalized(
        _ phrases: [PhraseItem],
        simplify: (String) -> String
    ) -> [PhraseItem] {
        var merged: [String: PhraseItem] = [:]
        for phrase in phrases {
            let normalized = phrase.simplifiedChinese(using: simplify)
            guard !normalized.word.isEmpty else { continue }
            guard let existing = merged[normalized.word] else {
                merged[normalized.word] = normalized
                continue
            }

            let preferred = preferredPhrase(existing, normalized)
            let other = preferred == existing ? normalized : existing
            merged[normalized.word] = PhraseItem(
                word: normalized.word,
                pinyin: preferred.pinyin,
                meanings: preferred.meanings,
                notes: PhraseNoteOverlayRules.mergeNotes(preferred.notes, other.notes),
                addedAt: [existing.addedAt, normalized.addedAt].compactMap { $0 }.min(),
                reviewStatus: preferred.reviewStatus,
                lastReviewedAt: preferred.lastReviewedAt
            )
        }
        return merged.values.sorted {
            ($0.addedAt ?? .distantPast) > ($1.addedAt ?? .distantPast)
        }
    }

    private static func preferredPhrase(_ lhs: PhraseItem, _ rhs: PhraseItem) -> PhraseItem {
        let lhsActivity = lhs.lastReviewedAt ?? lhs.addedAt ?? .distantPast
        let rhsActivity = rhs.lastReviewedAt ?? rhs.addedAt ?? .distantPast
        if lhsActivity != rhsActivity { return lhsActivity > rhsActivity ? lhs : rhs }
        if lhs.pinyin.isEmpty != rhs.pinyin.isEmpty { return lhs.pinyin.isEmpty ? rhs : lhs }
        if lhs.meanings.isEmpty != rhs.meanings.isEmpty { return lhs.meanings.isEmpty ? rhs : lhs }
        return lhs.word <= rhs.word ? lhs : rhs
    }
}
