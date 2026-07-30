import Foundation

public struct ConversationPracticeSet: Equatable, Identifiable {
    public let id: String
    public let title: String
    public let description: String
    public let language: String
    public let itemCount: Int
}

public struct ConversationPracticeItem: Equatable, Hashable, Identifiable {
    public let id: String
    public let setID: String
    public let phraseKey: String
    public let sentenceExampleID: UUID?
    public let sentenceKey: String
    public let rank: Int
    public let simplified: String
    public let pinyin: String
    public let english: String
    public let category: String
    public let difficulty: ConversationPracticeDifficulty
    public let tags: [String]
    public let characterHints: [String]
    public let phraseHints: [String]
    public let notes: String

    init(
        entry: ConversationPracticeEntry,
        setID: String,
        sentenceReference: ConversationPracticeSentenceReference? = nil
    ) {
        id = entry.id
        self.setID = setID
        phraseKey = ConversationPracticeRules.phraseKey(for: entry.sentence.zh)
        sentenceExampleID = sentenceReference?.sentenceExampleID
        sentenceKey = sentenceReference?.sentenceKey ?? SentenceExampleRecord.normalizedChineseKey(entry.sentence.zh)
        rank = entry.sequence
        simplified = entry.sentence.zh
        pinyin = entry.sentence.pinyin
        english = entry.sentence.en
        category = entry.category
        difficulty = ConversationPracticeDifficulty(
            level: entry.level,
            numericDifficulty: entry.metadata.difficulty
        )
        tags = entry.metadata.tags
        characterHints = entry.analysis.characters
        phraseHints = entry.analysis.phrases
        notes = entry.notes
    }

    init(favoriteSentence record: FavoriteSentenceRecord, rank: Int) {
        id = record.id
        setID = ConversationPracticeTopic.favoriteSentencesID
        phraseKey = ConversationPracticeRules.phraseKey(for: record.simplified)
        sentenceExampleID = nil
        sentenceKey = SentenceExampleRecord.normalizedChineseKey(record.simplified)
        self.rank = rank
        simplified = record.simplified
        pinyin = record.pinyin
        english = record.english
        category = ConversationPracticeTopic.favoriteSentencesID
        difficulty = .easy
        tags = ["favorite"]
        characterHints = record.characterHints
        phraseHints = record.phraseHints
        notes = "Saved from \(record.sourceSetID)"
    }

    init(sentenceExample record: SentenceExampleRecord, rank: Int) {
        id = record.id.uuidString
        setID = "sentence_examples"
        phraseKey = ConversationPracticeRules.phraseKey(for: record.chinese)
        sentenceExampleID = record.id
        sentenceKey = record.normalizedChineseKey
        self.rank = rank
        simplified = record.chinese
        pinyin = record.pinyin ?? ""
        english = record.english ?? ""
        category = record.sources.first?.sourceType.rawValue ?? "sentence_examples"
        difficulty = ConversationPracticeDifficulty(record.difficulty)
        tags = record.tags
        characterHints = record.targetCharacters.isEmpty ? record.detectedCharacters : record.targetCharacters
        phraseHints = record.targetPhrases.isEmpty ? record.detectedPhrases : record.targetPhrases
        notes = record.notes
    }
}

public struct ConversationPracticePhraseSeed: Equatable, Identifiable {
    public let id: String
    public let phraseKey: String
    public let simplified: String
    public let pinyin: String
    public let english: String
    public let notes: String
    public let sourceItemID: String

    init(item: ConversationPracticeItem) {
        id = item.phraseKey
        phraseKey = item.phraseKey
        simplified = item.simplified
        pinyin = item.pinyin
        english = item.english
        notes = item.notes
        sourceItemID = item.id
    }
}

public struct ConversationPracticeMembership: Equatable, Identifiable {
    public let id: String
    public let setID: String
    public let itemID: String
    public let phraseKey: String
    public let rank: Int
    public let category: String
    public let difficulty: ConversationPracticeDifficulty
    public let tags: [String]

    init(item: ConversationPracticeItem) {
        id = "\(item.setID)#\(item.id)"
        setID = item.setID
        itemID = item.id
        phraseKey = item.phraseKey
        rank = item.rank
        category = item.category
        difficulty = item.difficulty
        tags = item.tags
    }
}

public struct ConversationPracticeLibrary: Equatable {
    public let set: ConversationPracticeSet
    public let items: [ConversationPracticeItem]
    public let phraseSeeds: [ConversationPracticePhraseSeed]
    public let memberships: [ConversationPracticeMembership]

    public var phraseKeys: [String] {
        memberships.map(\.phraseKey)
    }

    static func sentenceExamplesLibrary(
        from records: [SentenceExampleRecord],
        title: String = "Sentence Practice"
    ) -> ConversationPracticeLibrary? {
        let records = SentenceExampleRecord.ranked(records)
        guard !records.isEmpty else { return nil }
        let items = records.enumerated().map { index, record in
            ConversationPracticeItem(sentenceExample: record, rank: index + 1)
        }
        return ConversationPracticeLibrary(
            set: ConversationPracticeSet(
                id: "sentence_examples_review",
                title: title,
                description: "\(items.count) sentences",
                language: "zh",
                itemCount: items.count
            ),
            items: items,
            phraseSeeds: items.map(ConversationPracticePhraseSeed.init),
            memberships: items.map(ConversationPracticeMembership.init)
        )
    }

    static func favoriteSentencesLibrary(from records: [FavoriteSentenceRecord]) -> ConversationPracticeLibrary? {
        let records = FavoriteSentenceRecord.deduplicated(records)
        guard !records.isEmpty else { return nil }
        let items = records.enumerated().map { index, record in
            ConversationPracticeItem(favoriteSentence: record, rank: index + 1)
        }
        return ConversationPracticeLibrary(
            set: ConversationPracticeSet(
                id: ConversationPracticeTopic.favoriteSentencesID,
                title: "Favorite Sentences",
                description: "\(items.count) saved sentences",
                language: "zh",
                itemCount: items.count
            ),
            items: items,
            phraseSeeds: items.map(ConversationPracticePhraseSeed.init),
            memberships: items.map(ConversationPracticeMembership.init)
        )
    }

    static func favoriteSentencesLibrary(from sentenceExamples: [SentenceExampleRecord]) -> ConversationPracticeLibrary? {
        let records = SentenceExampleRecord.ranked(sentenceExamples)
            .filter(\.isFavorited)
            .map { FavoriteSentenceRecord(sentenceExample: $0) }
        return favoriteSentencesLibrary(from: records)
    }
}
