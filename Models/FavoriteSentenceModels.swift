import Foundation

public struct FavoriteSentenceRecord: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let simplified: String
    public let pinyin: String
    public let english: String
    public let sourceSetID: String
    public let sourceItemID: String
    public let phraseHints: [String]
    public let characterHints: [String]
    public let favoritedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case simplified
        case pinyin
        case english
        case sourceSetID = "source_set_id"
        case sourceItemID = "source_item_id"
        case phraseHints = "phrase_hints"
        case characterHints = "character_hints"
        case favoritedAt = "favorited_at"
    }

    public init(
        id: String,
        simplified: String,
        pinyin: String,
        english: String,
        sourceSetID: String,
        sourceItemID: String,
        phraseHints: [String],
        characterHints: [String],
        favoritedAt: Date
    ) {
        self.id = id
        self.simplified = simplified
        self.pinyin = pinyin
        self.english = english
        self.sourceSetID = sourceSetID
        self.sourceItemID = sourceItemID
        self.phraseHints = phraseHints
        self.characterHints = characterHints
        self.favoritedAt = favoritedAt
    }

    init(item: ConversationPracticeItem, favoritedAt: Date = Date()) {
        self.init(
            id: Self.identifier(for: item),
            simplified: item.simplified,
            pinyin: item.pinyin,
            english: item.english,
            sourceSetID: item.setID,
            sourceItemID: item.id,
            phraseHints: item.phraseHints,
            characterHints: item.characterHints,
            favoritedAt: favoritedAt
        )
    }

    init(sentenceExample record: SentenceExampleRecord, favoritedAt: Date? = nil) {
        let source = record.sources.first
        self.init(
            id: "sentence:\(ConversationPracticeRules.phraseKey(for: record.chinese))",
            simplified: record.chinese,
            pinyin: record.pinyin ?? "",
            english: record.english ?? "",
            sourceSetID: source?.practicePackID ?? source?.sourceID ?? "sentence_examples",
            sourceItemID: source?.practiceItemID ?? record.id.uuidString,
            phraseHints: record.targetPhrases.isEmpty ? record.detectedPhrases : record.targetPhrases,
            characterHints: record.targetCharacters.isEmpty ? record.detectedCharacters : record.targetCharacters,
            favoritedAt: favoritedAt ?? record.createdAt
        )
    }

    public static func identifier(for item: ConversationPracticeItem) -> String {
        identifier(forChinese: item.simplified)
    }

    public static func identifier(forChinese chinese: String) -> String {
        "sentence:\(ConversationPracticeRules.phraseKey(for: chinese))"
    }

    public static func deduplicated(_ records: [FavoriteSentenceRecord]) -> [FavoriteSentenceRecord] {
        var byID: [String: FavoriteSentenceRecord] = [:]
        for record in records {
            if let existing = byID[record.id], existing.favoritedAt <= record.favoritedAt {
                continue
            }
            byID[record.id] = record
        }
        return byID.values.sorted {
            if $0.favoritedAt != $1.favoritedAt { return $0.favoritedAt > $1.favoritedAt }
            return $0.simplified < $1.simplified
        }
    }
}
