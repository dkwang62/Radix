import Foundation

enum PhraseContextRanker {
    static func surroundingCharacters(fullText: String, index: String.Index) -> (prev: Character?, next: Character?) {
        guard fullText.indices.contains(index) else { return (nil, nil) }

        let prev = index > fullText.startIndex ? fullText[fullText.index(before: index)] : nil
        let after = fullText.index(after: index)
        let next = after < fullText.endIndex ? fullText[after] : nil
        return (prev, next)
    }

    static func rankPhrases(phrases: [String], target: String, prev: Character?, next: Character?) -> [String] {
        phrases.enumerated()
            .map { offset, phrase in
                (phrase: phrase, score: score(phrase: phrase, target: target, prev: prev, next: next), offset: offset)
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                let lhsLength = lhs.phrase.count
                let rhsLength = rhs.phrase.count
                if lhsLength != rhsLength { return lhsLength < rhsLength }
                return lhs.offset < rhs.offset
            }
            .map(\.phrase)
    }

    static func rankPhraseItems(_ phrases: [PhraseItem], target: String, prev: Character?, next: Character?) -> [PhraseItem] {
        let rankedWords = rankPhrases(phrases: phrases.map(\.word), target: target, prev: prev, next: next)
        var rankByWord: [String: Int] = [:]
        for (offset, word) in rankedWords.enumerated() where rankByWord[word] == nil {
            rankByWord[word] = offset
        }
        return phrases.sorted { lhs, rhs in
            (rankByWord[lhs.word] ?? Int.max) < (rankByWord[rhs.word] ?? Int.max)
        }
    }

    private static func score(phrase: String, target: String, prev: Character?, next: Character?) -> Int {
        var value = 0

        if let prev, let next, phrase.contains("\(prev)\(target)\(next)") {
            value += 100
        }
        if let next, phrase.contains("\(target)\(next)") {
            value += 50
        }
        if let prev, phrase.contains("\(prev)\(target)") {
            value += 40
        }
        if phrase.contains(target) {
            value += 10
        }

        return value - phrase.count
    }
}
