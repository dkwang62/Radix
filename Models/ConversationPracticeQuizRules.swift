import Foundation

public enum ConversationPracticeQuizRules {
    public struct CharacterQuestion: Equatable {
        public let character: String
        public let blankedSentence: String

        public init(character: String, blankedSentence: String) {
            self.character = character
            self.blankedSentence = blankedSentence
        }
    }

    public struct CharacterChoiceCandidate: Equatable {
        public let character: String
        public let components: [String]
        public let rank: Int?

        public init(character: String, components: [String] = [], rank: Int? = nil) {
            self.character = character
            self.components = components
            self.rank = rank
        }
    }

    public static func characterQuestion(for item: ConversationPracticeItem) -> CharacterQuestion {
        characterQuestion(for: item, candidates: [])
    }

    public static func characterQuestion(
        for item: ConversationPracticeItem,
        candidates: [CharacterChoiceCandidate]
    ) -> CharacterQuestion {
        characterQuestion(
            sentence: item.simplified,
            characterHints: item.characterHints,
            candidates: candidates
        )
    }

    public static func characterQuestion(
        sentence: String,
        characterHints: [String],
        candidates: [CharacterChoiceCandidate]
    ) -> CharacterQuestion {
        let character = questionCharacter(
            characterHints: characterHints,
            fallbackSentence: sentence,
            candidates: candidates
        )
        return CharacterQuestion(
            character: character,
            blankedSentence: sentenceByBlanking(character, in: sentence)
        )
    }

    public static func questionCharacter(for item: ConversationPracticeItem) -> String {
        questionCharacter(for: item, candidates: [])
    }

    public static func questionCharacter(
        for item: ConversationPracticeItem,
        candidates: [CharacterChoiceCandidate]
    ) -> String {
        questionCharacter(
            characterHints: item.characterHints,
            fallbackSentence: item.simplified,
            candidates: candidates
        )
    }

    public static func questionCharacter(
        characterHints: [String],
        fallbackSentence: String,
        candidates: [CharacterChoiceCandidate]
    ) -> String {
        let hintedCharacters = characterHints.filter { $0.count == 1 && isChineseCharacter($0) }
        let usableCandidates = uniqueCandidates(candidates)
        if let confusableCharacter = confusableQuestionCharacter(
            from: hintedCharacters,
            candidates: usableCandidates
        ) {
            return confusableCharacter
        }

        if let substantialCharacter = hintedCharacters.first(where: isSubstantialQuizCharacter) {
            return substantialCharacter
        }

        if let hinted = hintedCharacters.first { return hinted }

        return fallbackSentence
            .map(String.init)
            .first(where: { isChineseCharacter($0) && isSubstantialQuizCharacter($0) })
            ?? fallbackSentence
                .map(String.init)
                .first(where: { $0.count == 1 && isChineseCharacter($0) })
            ?? fallbackSentence
    }

    public static func characterChoices(
        for character: String,
        from candidates: [CharacterChoiceCandidate],
        count: Int = 4
    ) -> [String] {
        let uniqueCandidates = uniqueCandidates(candidates)

        guard let answer = uniqueCandidates.first(where: { $0.character == character }) else {
            return [character]
        }

        let answerComponents = Set(answer.components)
        let distractors = uniqueCandidates
            .filter { $0.character != character }
            .sorted {
                characterChoiceSort(
                    $0,
                    before: $1,
                    answerComponents: answerComponents,
                    answerCharacter: character
                )
            }
            .prefix(max(0, count - 1))

        return ([answer.character] + distractors.map(\.character)).sorted {
            stableOrderKey($0, itemID: character) < stableOrderKey($1, itemID: character)
        }
    }

    public static func choices(
        for item: ConversationPracticeItem,
        in items: [ConversationPracticeItem],
        count: Int = 4
    ) -> [ConversationPracticeItem] {
        guard let itemIndex = items.firstIndex(where: { $0.id == item.id }) else {
            return [item]
        }

        let distractors = (1..<items.count)
            .map { items[(itemIndex + ($0 * 7)) % items.count] }
            .filter { $0.id != item.id }
            .prefix(max(0, count - 1))

        let ordered = [item] + Array(distractors)
        return ordered.sorted {
            stableOrderKey($0.id, itemID: item.id) < stableOrderKey($1.id, itemID: item.id)
        }
    }

    private static func stableOrderKey(_ id: String, itemID: String) -> Int {
        let combined = "\(itemID)#\(id)"
        return combined.unicodeScalars.reduce(0) { partial, scalar in
            ((partial * 31) + Int(scalar.value)) % 997
        }
    }

    private static func characterChoiceSort(
        _ lhs: CharacterChoiceCandidate,
        before rhs: CharacterChoiceCandidate,
        answerComponents: Set<String>,
        answerCharacter: String
    ) -> Bool {
        let lhsShared = Set(lhs.components).intersection(answerComponents).count
        let rhsShared = Set(rhs.components).intersection(answerComponents).count
        if lhsShared != rhsShared { return lhsShared > rhsShared }

        let lhsRank = lhs.rank ?? Int.max
        let rhsRank = rhs.rank ?? Int.max
        if lhsRank != rhsRank { return lhsRank < rhsRank }

        return stableOrderKey(lhs.character, itemID: answerCharacter) < stableOrderKey(rhs.character, itemID: answerCharacter)
    }

    private static func isChineseCharacter(_ value: String) -> Bool {
        value.count == 1 && value.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(Int(scalar.value))
        }
    }

    private static func uniqueCandidates(_ candidates: [CharacterChoiceCandidate]) -> [CharacterChoiceCandidate] {
        var uniqueCandidates: [CharacterChoiceCandidate] = []
        var seen = Set<String>()
        for candidate in candidates where candidate.character.count == 1 && isChineseCharacter(candidate.character) {
            guard seen.insert(candidate.character).inserted else { continue }
            uniqueCandidates.append(candidate)
        }
        return uniqueCandidates
    }

    private static func confusableQuestionCharacter(
        from characters: [String],
        candidates: [CharacterChoiceCandidate]
    ) -> String? {
        let byCharacter = Dictionary(uniqueKeysWithValues: candidates.map { ($0.character, $0) })
        let scored = characters.compactMap { character -> (character: String, score: Int, lowValue: Bool)? in
            guard let candidate = byCharacter[character] else { return nil }
            let score = confusabilityScore(for: candidate, in: candidates)
            guard score > 0 else { return nil }
            return (character, score, !isSubstantialQuizCharacter(character))
        }

        return scored.sorted { lhs, rhs in
            if lhs.lowValue != rhs.lowValue { return !lhs.lowValue }
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return characters.firstIndex(of: lhs.character) ?? Int.max < characters.firstIndex(of: rhs.character) ?? Int.max
        }.first?.character
    }

    private static func confusabilityScore(
        for candidate: CharacterChoiceCandidate,
        in candidates: [CharacterChoiceCandidate]
    ) -> Int {
        let components = Set(candidate.components)
        guard !components.isEmpty else { return 0 }

        return candidates
            .filter { $0.character != candidate.character }
            .reduce(0) { score, peer in
                let sharedCount = Set(peer.components).intersection(components).count
                if sharedCount >= 2 { return score + 3 }
                if sharedCount == 1 { return score + 1 }
                return score
            }
    }

    private static func sentenceByBlanking(_ character: String, in sentence: String) -> String {
        guard !character.isEmpty else { return sentence }
        return sentence.replacingOccurrences(of: character, with: "＿", options: [], range: sentence.startIndex..<sentence.endIndex)
    }

    private static func isSubstantialQuizCharacter(_ character: String) -> Bool {
        !lowValueQuestionCharacters.contains(character)
    }

    private static let lowValueQuestionCharacters: Set<String> = [
        "我", "你", "他", "她", "它", "们", "这", "那", "哪", "个", "的", "了", "吗", "呢",
        "吧", "啊", "是", "在", "有", "不", "很", "太", "一", "二", "三"
    ]
}
