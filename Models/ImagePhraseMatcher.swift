import Foundation

// Browse page phrases are explicit user-visible tiles. Keep these as plain data
// models so page phrase selection does not grow hidden preview behaviour again.
struct ImagePhraseContext: Equatable {
    let collectionID: UUID
    let target: String
    let offset: Int
}

struct BrowseImagePhraseTileData {
    let phrase: PhraseItem
    let start: Int
    let end: Int

    var offsets: [Int] {
        Array(start..<end)
    }
}

struct BrowsePagePhraseCandidate: Identifiable, Hashable {
    let phrase: PhraseItem
    let firstStart: Int
    let occurrenceCount: Int

    var id: String { phrase.word }
}

enum BrowsePagePhraseRules {
    static func candidateWords(lookupCharacters: [String], maxPhraseLength: Int) -> Set<String> {
        var words = Set<String>()
        for offset in lookupCharacters.indices {
            let maxLength = min(maxPhraseLength, lookupCharacters.count - offset)
            guard maxLength >= 2 else { continue }
            for length in 2...maxLength {
                words.insert(lookupCharacters[offset..<(offset + length)].joined())
            }
        }
        return words
    }

    static func tileMatches(
        lookupCharacters: [String],
        phraseByLookupWord: [String: PhraseItem],
        hiddenWords: Set<String>,
        maxPhraseLength: Int,
        phraseWordKey: (String) -> String
    ) -> [BrowseImagePhraseTileData] {
        guard lookupCharacters.count > 1 else { return [] }

        var matches: [BrowseImagePhraseTileData] = []
        for offset in lookupCharacters.indices {
            let maxLength = min(maxPhraseLength, lookupCharacters.count - offset)
            guard maxLength >= 2 else { continue }

            for length in 2...maxLength {
                let end = offset + length
                let segment = lookupCharacters[offset..<end].joined()
                guard let phrase = phraseByLookupWord[segment],
                      !hiddenWords.contains(phraseWordKey(phrase.word))
                else { continue }

                matches.append(BrowseImagePhraseTileData(phrase: phrase, start: offset, end: end))
            }
        }

        return matches.sorted(by: tileMatchSortPredicate)
    }

    static func tiles(from matches: [BrowseImagePhraseTileData]) -> [Int: BrowseImagePhraseTileData] {
        var tiles: [Int: BrowseImagePhraseTileData] = [:]
        var claimedOffsets = Set<Int>()

        for match in matches {
            let offsets = Set(match.start..<match.end)
            guard claimedOffsets.isDisjoint(with: offsets) else { continue }
            tiles[match.start] = match
            claimedOffsets.formUnion(offsets)
        }

        return tiles
    }

    static func candidates(
        lookupCharacters: [String],
        phraseByLookupWord: [String: PhraseItem],
        maxPhraseLength: Int,
        phraseWordKey: (String) -> String
    ) -> [BrowsePagePhraseCandidate] {
        var firstStartByWord: [String: Int] = [:]
        var countByWord: [String: Int] = [:]
        var phraseByWord: [String: PhraseItem] = [:]

        for offset in lookupCharacters.indices {
            let maxLength = min(maxPhraseLength, lookupCharacters.count - offset)
            guard maxLength >= 2 else { continue }
            for length in 2...maxLength {
                let segment = lookupCharacters[offset..<(offset + length)].joined()
                guard let phrase = phraseByLookupWord[segment] else { continue }
                let word = phraseWordKey(phrase.word)
                phraseByWord[word] = phrase
                firstStartByWord[word] = min(firstStartByWord[word] ?? offset, offset)
                countByWord[word, default: 0] += 1
            }
        }

        return phraseByWord.values.map { phrase in
            let word = phraseWordKey(phrase.word)
            return BrowsePagePhraseCandidate(
                phrase: phrase,
                firstStart: firstStartByWord[word] ?? 0,
                occurrenceCount: countByWord[word] ?? 1
            )
        }
        .sorted(by: candidateSortPredicate)
    }

    private static func tileMatchSortPredicate(_ lhs: BrowseImagePhraseTileData, _ rhs: BrowseImagePhraseTileData) -> Bool {
        let leftLength = lhs.end - lhs.start
        let rightLength = rhs.end - rhs.start
        if leftLength != rightLength { return leftLength > rightLength }
        if lhs.start != rhs.start { return lhs.start < rhs.start }

        let pinyinOrder = sortKey(lhs.phrase).localizedStandardCompare(sortKey(rhs.phrase))
        if pinyinOrder != .orderedSame { return pinyinOrder == .orderedAscending }
        return lhs.phrase.word < rhs.phrase.word
    }

    private static func candidateSortPredicate(_ lhs: BrowsePagePhraseCandidate, _ rhs: BrowsePagePhraseCandidate) -> Bool {
        let pinyinOrder = sortKey(lhs.phrase).localizedStandardCompare(sortKey(rhs.phrase))
        if pinyinOrder != .orderedSame { return pinyinOrder == .orderedAscending }
        if lhs.phrase.word != rhs.phrase.word { return lhs.phrase.word < rhs.phrase.word }
        return lhs.firstStart < rhs.firstStart
    }

    private static func sortKey(_ phrase: PhraseItem) -> String {
        let value = phrase.pinyin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? phrase.word : phrase.pinyin
        return value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
