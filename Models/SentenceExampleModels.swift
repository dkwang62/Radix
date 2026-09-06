import Foundation

public enum SentenceExampleScript: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case simplified
    case traditional
    case mixed
    case unknown
}

public enum SentenceExampleSourceType: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case aiCleanedPage = "ai_cleaned_page"
    case aiGenerated = "ai_generated"
    case conversationPractice = "conversation_practice"
    case favoriteSentence = "favorite_sentence"
    case sentencePractice = "sentence_practice"
    case quiz
    case ocrSource = "ocr_source"
    case userAdded = "user_added"
    case imported
}

public enum SentenceExampleDifficulty: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case easy
    case medium
    case hard
    case unknown

    init(_ difficulty: ConversationPracticeDifficulty) {
        switch difficulty {
        case .easy: self = .easy
        case .medium: self = .medium
        case .hard: self = .hard
        }
    }
}

public struct SentenceExampleSourceReference: Codable, Equatable, Hashable, Sendable {
    public let sourceType: SentenceExampleSourceType
    public let sourceID: String?
    public let sourceTitle: String?
    public let sourcePageID: UUID?
    public let practicePackID: String?
    public let practiceItemID: String?

    public init(
        sourceType: SentenceExampleSourceType,
        sourceID: String?,
        sourceTitle: String?,
        sourcePageID: UUID?,
        practicePackID: String?,
        practiceItemID: String?
    ) {
        self.sourceType = sourceType
        self.sourceID = sourceID
        self.sourceTitle = sourceTitle
        self.sourcePageID = sourcePageID
        self.practicePackID = practicePackID
        self.practiceItemID = practiceItemID
    }

    public func matches(pageID: UUID) -> Bool {
        sourcePageID == pageID
    }

    public func matches(sourceType: SentenceExampleSourceType) -> Bool {
        self.sourceType == sourceType
    }

    public func matches(pageID: UUID, sourceType: SentenceExampleSourceType?) -> Bool {
        guard sourcePageID == pageID else { return false }
        return sourceType == nil || self.sourceType == sourceType
    }
}

public struct SentenceExampleRecord: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var chinese: String
    public var script: SentenceExampleScript
    public var pinyin: String?
    public var english: String?
    public var sources: [SentenceExampleSourceReference]
    public var targetCharacters: [String]
    public var targetPhrases: [String]
    public var detectedCharacters: [String]
    public var detectedPhrases: [String]
    public var grammarPoints: [String]
    public var hskLevel: Int?
    public var difficulty: SentenceExampleDifficulty
    public var naturalness: String?
    public var createdAt: Date
    public var lastUsedAt: Date?
    public var usageCount: Int
    public var viewedCount: Int
    public var practicedCount: Int
    public var skippedCount: Int
    public var isFavorited: Bool
    public var isHidden: Bool
    public var qualityScore: Double
    public var notes: String
    public var tags: [String]

    public init(
        id: UUID = UUID(),
        chinese: String,
        script: SentenceExampleScript = .unknown,
        pinyin: String? = nil,
        english: String? = nil,
        sources: [SentenceExampleSourceReference] = [],
        targetCharacters: [String] = [],
        targetPhrases: [String] = [],
        detectedCharacters: [String] = [],
        detectedPhrases: [String] = [],
        grammarPoints: [String] = [],
        hskLevel: Int? = nil,
        difficulty: SentenceExampleDifficulty = .unknown,
        naturalness: String? = nil,
        createdAt: Date = Date(),
        lastUsedAt: Date? = nil,
        usageCount: Int = 0,
        viewedCount: Int = 0,
        practicedCount: Int = 0,
        skippedCount: Int = 0,
        isFavorited: Bool = false,
        isHidden: Bool = false,
        qualityScore: Double = 0,
        notes: String = "",
        tags: [String] = []
    ) {
        self.id = id
        self.chinese = chinese.trimmingCharacters(in: .whitespacesAndNewlines)
        self.script = script
        self.pinyin = Self.cleanOptional(pinyin)
        self.english = Self.cleanOptional(english)
        self.sources = Self.deduplicatedSources(sources)
        self.targetCharacters = Self.deduplicated(targetCharacters)
        self.targetPhrases = Self.deduplicated(targetPhrases)
        self.detectedCharacters = Self.deduplicated(detectedCharacters)
        self.detectedPhrases = Self.deduplicated(detectedPhrases)
        self.grammarPoints = Self.deduplicated(grammarPoints)
        self.hskLevel = hskLevel
        self.difficulty = difficulty
        self.naturalness = Self.cleanOptional(naturalness)
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.usageCount = usageCount
        self.viewedCount = viewedCount
        self.practicedCount = practicedCount
        self.skippedCount = skippedCount
        self.isFavorited = isFavorited
        self.isHidden = isHidden
        self.qualityScore = qualityScore
        self.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        self.tags = Self.deduplicated(tags)
    }

    public var normalizedChineseKey: String {
        Self.normalizedChineseKey(chinese)
    }

    public func containsCharacter(_ character: String) -> Bool {
        let key = character.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return false }
        return detectedCharacters.contains(key) ||
            targetCharacters.contains(key) ||
            chinese.contains(key)
    }

    public func containsPhrase(_ phrase: String) -> Bool {
        let key = Self.normalizedChineseKey(phrase)
        guard !key.isEmpty else { return false }
        return detectedPhrases.contains { Self.normalizedChineseKey($0) == key } ||
            targetPhrases.contains { Self.normalizedChineseKey($0) == key } ||
            normalizedChineseKey.contains(key)
    }

    public func isLinked(toPageID pageID: UUID) -> Bool {
        sources.contains { $0.matches(pageID: pageID) }
    }

    public func hasSourceType(_ sourceType: SentenceExampleSourceType) -> Bool {
        sources.contains { $0.matches(sourceType: sourceType) }
    }

    mutating func removeSources(sourceType: SentenceExampleSourceType, pageID: UUID) {
        sources.removeAll {
            $0.sourceType == sourceType && $0.sourcePageID == pageID
        }
    }

    mutating func removeSources(sourceType: SentenceExampleSourceType) {
        sources.removeAll { $0.sourceType == sourceType }
    }

    mutating func removeSources(linkedToPageIDs pageIDs: Set<UUID>) {
        sources.removeAll { source in
            source.sourcePageID.map(pageIDs.contains) == true
        }
    }

    func firstAvailableSourcePageID(in availablePageIDs: Set<UUID>) -> UUID? {
        sources.compactMap(\.sourcePageID).first(where: availablePageIDs.contains)
    }

    public mutating func merge(_ incoming: SentenceExampleRecord) {
        if pinyin == nil { pinyin = incoming.pinyin }
        if english == nil { english = incoming.english }
        sources = Self.deduplicatedSources(sources + incoming.sources)
        targetCharacters = Self.deduplicated(targetCharacters + incoming.targetCharacters)
        targetPhrases = Self.deduplicated(targetPhrases + incoming.targetPhrases)
        detectedCharacters = Self.deduplicated(detectedCharacters + incoming.detectedCharacters)
        detectedPhrases = Self.deduplicated(detectedPhrases + incoming.detectedPhrases)
        grammarPoints = Self.deduplicated(grammarPoints + incoming.grammarPoints)
        if hskLevel == nil { hskLevel = incoming.hskLevel }
        if difficulty == .unknown { difficulty = incoming.difficulty }
        if naturalness == nil { naturalness = incoming.naturalness }
        lastUsedAt = Self.newerDate(lastUsedAt, incoming.lastUsedAt)
        usageCount += incoming.usageCount
        viewedCount += incoming.viewedCount
        practicedCount += incoming.practicedCount
        skippedCount += incoming.skippedCount
        isFavorited = isFavorited || incoming.isFavorited
        isHidden = isHidden && incoming.isHidden
        qualityScore = max(qualityScore, incoming.qualityScore)
        if notes.isEmpty { notes = incoming.notes }
        tags = Self.deduplicated(tags + incoming.tags)
    }

    public static func fromPracticeItem(
        _ item: ConversationPracticeItem,
        pack: ConversationPracticePack?,
        isFavorited: Bool = false,
        createdAt: Date = Date()
    ) -> SentenceExampleRecord {
        let sourceLink = pack?.sourceLink
        let source = SentenceExampleSourceReference(
            sourceType: pack?.sourceLink == nil ? .conversationPractice : .sentencePractice,
            sourceID: sourceLink?.sourceID ?? item.setID,
            sourceTitle: sourceLink?.sourceTitle ?? pack?.title,
            sourcePageID: sourceLink?.sourcePageID,
            practicePackID: item.setID,
            practiceItemID: item.id
        )

        return SentenceExampleRecord(
            chinese: item.simplified,
            script: .simplified,
            pinyin: item.pinyin,
            english: item.english,
            sources: [source],
            targetCharacters: item.characterHints,
            targetPhrases: item.phraseHints,
            detectedCharacters: Self.detectChineseCharacters(in: item.simplified),
            detectedPhrases: item.phraseHints,
            difficulty: SentenceExampleDifficulty(item.difficulty),
            createdAt: createdAt,
            usageCount: 1,
            isFavorited: isFavorited,
            qualityScore: isFavorited ? 2 : 0,
            notes: item.notes,
            tags: item.tags
        )
    }

    public static func fromFavoriteSentence(_ record: FavoriteSentenceRecord) -> SentenceExampleRecord {
        let source = SentenceExampleSourceReference(
            sourceType: .favoriteSentence,
            sourceID: record.sourceSetID,
            sourceTitle: nil,
            sourcePageID: nil,
            practicePackID: record.sourceSetID,
            practiceItemID: record.sourceItemID
        )

        return SentenceExampleRecord(
            chinese: record.simplified,
            script: .simplified,
            pinyin: record.pinyin,
            english: record.english,
            sources: [source],
            targetCharacters: record.characterHints,
            targetPhrases: record.phraseHints,
            detectedCharacters: Self.detectChineseCharacters(in: record.simplified),
            detectedPhrases: record.phraseHints,
            createdAt: record.favoritedAt,
            usageCount: 1,
            isFavorited: true,
            qualityScore: 2,
            tags: ["favorite"]
        )
    }

    public static func fromOCRText(
        _ text: String,
        sourcePageID: UUID,
        sourceTitle: String,
        createdAt: Date = Date()
    ) -> [SentenceExampleRecord] {
        let source = SentenceExampleSourceReference(
            sourceType: .ocrSource,
            sourceID: sourcePageID.uuidString,
            sourceTitle: sourceTitle,
            sourcePageID: sourcePageID,
            practicePackID: nil,
            practiceItemID: nil
        )
        return sentenceFragments(in: text).map { sentence in
            SentenceExampleRecord(
                chinese: sentence,
                script: .unknown,
                sources: [source],
                detectedCharacters: detectChineseCharacters(in: sentence),
                createdAt: createdAt,
                tags: ["ocr"]
            )
        }
    }

    static func fromAICleanedPage(_ record: AICleanedPageRecord) -> [SentenceExampleRecord] {
        let source = SentenceExampleSourceReference(
            sourceType: .aiCleanedPage,
            sourceID: record.sourcePageID.uuidString,
            sourceTitle: record.cleanedTitle.isEmpty ? record.sourceTitle : record.cleanedTitle,
            sourcePageID: record.sourcePageID,
            practicePackID: nil,
            practiceItemID: nil
        )
        let sentences = record.sentences.isEmpty
            ? sentenceFragments(in: record.cleanedChineseText).enumerated().map { index, sentence in
                AICleanedPageSentence(
                    id: "ai_cleaned_page_sentence_\(index + 1)",
                    chinese: sentence
                )
            }
            : record.sentences

        return sentences.compactMap { sentence in
            let chinese = sentence.chinese.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !chinese.isEmpty else { return nil }
            return SentenceExampleRecord(
                chinese: chinese,
                script: .unknown,
                pinyin: sentence.pinyin,
                english: sentence.english,
                sources: [source],
                targetCharacters: detectChineseCharacters(in: chinese),
                targetPhrases: sentence.phraseHints,
                detectedCharacters: detectChineseCharacters(in: chinese),
                detectedPhrases: sentence.phraseHints,
                createdAt: record.createdAt,
                qualityScore: 1,
                tags: ["ai-cleaned-page"]
            )
        }
    }

    public static func ranked(_ records: [SentenceExampleRecord]) -> [SentenceExampleRecord] {
        records
            .filter { !$0.isHidden }
            .sorted {
                if $0.isFavorited != $1.isFavorited { return $0.isFavorited && !$1.isFavorited }
                if $0.qualityScore != $1.qualityScore { return $0.qualityScore > $1.qualityScore }
                if $0.practicedCount != $1.practicedCount { return $0.practicedCount > $1.practicedCount }
                if $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
                return $0.chinese < $1.chinese
            }
    }

    public static func upserting(
        _ incomingRecords: [SentenceExampleRecord],
        into existingRecords: [SentenceExampleRecord]
    ) -> [SentenceExampleRecord] {
        var order: [String] = []
        var recordsByKey: [String: SentenceExampleRecord] = [:]

        for record in existingRecords + incomingRecords {
            let key = record.normalizedChineseKey
            guard !key.isEmpty else { continue }
            if var existing = recordsByKey[key] {
                existing.merge(record)
                recordsByKey[key] = existing
            } else {
                order.append(key)
                recordsByKey[key] = record
            }
        }

        return order.compactMap { recordsByKey[$0] }
            .sorted {
                if $0.isFavorited != $1.isFavorited { return $0.isFavorited && !$1.isFavorited }
                if $0.qualityScore != $1.qualityScore { return $0.qualityScore > $1.qualityScore }
                if $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
                return $0.chinese < $1.chinese
            }
    }

    public static func normalizedChineseKey(_ value: String) -> String {
        let punctuation = CharacterSet.punctuationCharacters
            .union(CharacterSet(charactersIn: "，。！？；：「」『』（）【】《》、·…—"))
        return value.unicodeScalars
            .filter { !$0.properties.isWhitespace && !punctuation.contains($0) }
            .map(String.init)
            .joined()
    }

    public static func detectChineseCharacters(in value: String) -> [String] {
        var seen: Set<String> = []
        var characters: [String] = []
        for character in value where ConversationPracticeRules.isChineseCharacter(character) {
            let text = String(character)
            guard seen.insert(text).inserted else { continue }
            characters.append(text)
        }
        return characters
    }

    public static func sentenceFragments(in value: String) -> [String] {
        let separators = CharacterSet.newlines
            .union(CharacterSet(charactersIn: "。！？!?；;"))
        let fragments = value
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        var seen: Set<String> = []
        return fragments.compactMap { fragment in
            let chineseCount = fragment.filter(ConversationPracticeRules.isChineseCharacter).count
            guard chineseCount >= 2 else { return nil }
            let key = normalizedChineseKey(fragment)
            guard !key.isEmpty, seen.insert(key).inserted else { return nil }
            return fragment
        }
    }

    private static func deduplicated(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.compactMap { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { return nil }
            return trimmed
        }
    }

    private static func cleanOptional(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else { return nil }
        return trimmed
    }

    private static func newerDate(_ lhs: Date?, _ rhs: Date?) -> Date? {
        switch (lhs, rhs) {
        case let (.some(lhs), .some(rhs)): return max(lhs, rhs)
        case let (.some(lhs), .none): return lhs
        case let (.none, .some(rhs)): return rhs
        case (.none, .none): return nil
        }
    }

    private static func deduplicatedSources(_ values: [SentenceExampleSourceReference]) -> [SentenceExampleSourceReference] {
        var seen: Set<String> = []
        return values.filter { source in
            let key = [
                source.sourceType.rawValue,
                source.sourceID ?? "",
                source.practicePackID ?? "",
                source.practiceItemID ?? ""
            ].joined(separator: "|")
            return seen.insert(key).inserted
        }
    }
}
