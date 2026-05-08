import Foundation

struct ImagePhraseContext: Equatable {
    let collectionID: UUID
    let target: String
    let offset: Int
    let prev: Character?
    let next: Character?
}

struct ImagePhraseHighlightState {
    let context: ImagePhraseContext
    let offsets: Set<Int>
}

struct ImagePhraseMatch {
    let phrase: PhraseItem
    let start: Int
    let end: Int
    let rankedIndex: Int
}

enum ImagePhraseMatcher {
    static func context(for character: String, offset: Int, collection: CharacterCollection) -> ImagePhraseContext? {
        guard collection.characters.indices.contains(offset),
              collection.characters[offset] == character
        else { return nil }

        let fullText = collection.characters.joined()
        var index = fullText.startIndex
        for priorCharacter in collection.characters.prefix(offset) {
            index = fullText.index(index, offsetBy: priorCharacter.count)
        }
        let context = PhraseContextRanker.surroundingCharacters(fullText: fullText, index: index)
        return ImagePhraseContext(
            collectionID: collection.id,
            target: character,
            offset: offset,
            prev: context.prev,
            next: context.next
        )
    }

    static func cacheKey(character: String, length: Int, context: ImagePhraseContext?) -> String {
        guard let context else { return "\(character)|\(length)" }
        return "\(character)|\(length)|image|\(context.collectionID.uuidString)|\(context.offset)|\(context.prev.map(String.init) ?? "")|\(context.next.map(String.init) ?? "")"
    }

    static func rankedPhraseResults(
        _ phrases: [PhraseItem],
        target: String,
        context: ImagePhraseContext?,
        lookupTarget: (String) -> String,
        pinyinSort: (PhraseItem, PhraseItem) -> Bool
    ) -> [PhraseItem] {
        guard let context else {
            return phrases.sorted(by: pinyinSort)
        }

        return PhraseContextRanker.rankPhraseItems(
            phrases,
            target: lookupTarget(target),
            prev: simplifiedCharacter(context.prev, lookupTarget: lookupTarget),
            next: simplifiedCharacter(context.next, lookupTarget: lookupTarget)
        )
    }

    static func matches(
        context: ImagePhraseContext,
        collection: CharacterCollection,
        candidates: [PhraseItem],
        phraseStorageWord: (String) -> String,
        lookupTarget: (String) -> String,
        pinyinSort: (PhraseItem, PhraseItem) -> Bool
    ) -> [ImagePhraseMatch] {
        guard collection.id == context.collectionID,
              collection.characters.indices.contains(context.offset)
        else { return [] }

        let target = lookupTarget(context.target)
        let ranked = rankedPhraseResults(
            candidates,
            target: context.target,
            context: context,
            lookupTarget: lookupTarget,
            pinyinSort: pinyinSort
        )
        let simplifiedCharacters = collection.characters.map(lookupTarget)
        var matches: [ImagePhraseMatch] = []
        var seen = Set<String>()

        for (rankedIndex, phrase) in ranked.enumerated() {
            let phraseCharacters = phraseStorageWord(phrase.word).map(String.init)
            guard !phraseCharacters.isEmpty else { continue }

            for phraseIndex in phraseCharacters.indices where phraseCharacters[phraseIndex] == target {
                let start = context.offset - phraseIndex
                let end = start + phraseCharacters.count
                guard start >= 0, end <= simplifiedCharacters.count else { continue }

                let isMatch = phraseCharacters.indices.allSatisfy {
                    simplifiedCharacters[start + $0] == phraseCharacters[$0]
                }
                guard isMatch else { continue }

                let key = "\(phrase.id)|\(start)|\(end)"
                if seen.insert(key).inserted {
                    matches.append(ImagePhraseMatch(phrase: phrase, start: start, end: end, rankedIndex: rankedIndex))
                }
            }
        }

        return matches
    }

    static func preferredMatch(from matches: [ImagePhraseMatch], targetOffset: Int) -> ImagePhraseMatch {
        matches.sorted { lhs, rhs in
            let lhsStartsAtTarget = lhs.start == targetOffset
            let rhsStartsAtTarget = rhs.start == targetOffset
            if lhsStartsAtTarget != rhsStartsAtTarget {
                return lhsStartsAtTarget
            }

            let lhsLength = lhs.end - lhs.start
            let rhsLength = rhs.end - rhs.start
            if lhsLength != rhsLength {
                return lhsLength > rhsLength
            }

            return lhs.rankedIndex < rhs.rankedIndex
        }.first ?? matches[0]
    }

    private static func simplifiedCharacter(_ character: Character?, lookupTarget: (String) -> String) -> Character? {
        guard let character else { return nil }
        return lookupTarget(String(character)).first
    }
}
