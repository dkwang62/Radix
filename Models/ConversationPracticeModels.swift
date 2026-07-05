import Foundation

public enum ConversationPracticeDifficulty: String, Codable, CaseIterable, Hashable {
    case easy
    case medium
    case hard

    init(level: String, numericDifficulty: Int) {
        let normalizedLevel = level.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalizedLevel {
        case "advanced", "hard":
            self = .hard
        case "intermediate", "medium":
            self = .medium
        default:
            if numericDifficulty >= 4 {
                self = .hard
            } else if numericDifficulty >= 3 {
                self = .medium
            } else {
                self = .easy
            }
        }
    }

    init(_ difficulty: SentenceExampleDifficulty) {
        switch difficulty {
        case .easy: self = .easy
        case .medium: self = .medium
        case .hard: self = .hard
        case .unknown: self = .easy
        }
    }
}

public struct ConversationPracticePack: Codable, Equatable {
    private static let defaultSourceType = "conversation_pack"
    private static let defaultCreatedFor = "Radix Conversation Practice"

    public let packID: String
    public let version: String
    public let title: String
    public let description: String
    public let language: String
    public let sourceType: String
    public let createdFor: String
    public let sourceLink: ConversationPracticeSourceLink?
    public let sentenceReferences: [ConversationPracticeSentenceReference]
    public let entries: [ConversationPracticeEntry]

    enum CodingKeys: String, CodingKey {
        case packID = "pack_id"
        case version
        case title
        case description
        case language
        case sourceType = "source_type"
        case createdFor = "created_for"
        case sourceLink = "source_link"
        case sentenceReferences = "sentence_references"
        case entries
    }

    enum ImportedCodingKeys: String, CodingKey {
        case theme
        case sourceLink = "source_link"
        case entries
    }

    public init(
        packID: String,
        version: String,
        title: String,
        description: String,
        language: String,
        sourceType: String,
        createdFor: String,
        sourceLink: ConversationPracticeSourceLink?,
        sentenceReferences: [ConversationPracticeSentenceReference] = [],
        entries: [ConversationPracticeEntry]
    ) {
        self.packID = packID
        self.version = version
        self.title = title
        self.description = description
        self.language = language
        self.sourceType = sourceType
        self.createdFor = createdFor
        self.sourceLink = sourceLink
        self.sentenceReferences = sentenceReferences
        self.entries = entries
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let decodedPackID = try container.decodeIfPresent(String.self, forKey: .packID) {
            packID = decodedPackID
            version = try container.decode(String.self, forKey: .version)
            title = try container.decode(String.self, forKey: .title)
            description = try container.decode(String.self, forKey: .description)
            language = try container.decode(String.self, forKey: .language)
            sourceType = try container.decodeIfPresent(String.self, forKey: .sourceType) ?? Self.defaultSourceType
            createdFor = try container.decodeIfPresent(String.self, forKey: .createdFor) ?? Self.defaultCreatedFor
            sourceLink = try container.decodeIfPresent(ConversationPracticeSourceLink.self, forKey: .sourceLink)
            sentenceReferences = try container.decodeIfPresent(
                [ConversationPracticeSentenceReference].self,
                forKey: .sentenceReferences
            ) ?? []
            let drafts = try container.decode([ConversationPracticeEntryDraft].self, forKey: .entries)
            let defaultCategory = ConversationPracticeRules.stableIdentifier(for: title)
            entries = drafts.enumerated().map { index, draft in
                ConversationPracticeEntry(
                    draft: draft,
                    fallbackSequence: index + 1,
                    defaultCategory: defaultCategory
                )
            }
        } else {
            let importedContainer = try decoder.container(keyedBy: ImportedCodingKeys.self)
            let theme = try importedContainer.decode(String.self, forKey: .theme)
            title = theme
            packID = ConversationPracticeRules.stableIdentifier(for: theme)
            version = "1.0"
            description = "Imported practice pack: \(theme)"
            language = "zh-Hans"
            sourceType = "user_imported_practice"
            createdFor = Self.defaultCreatedFor
            sourceLink = try importedContainer.decodeIfPresent(ConversationPracticeSourceLink.self, forKey: .sourceLink)
            sentenceReferences = []
            let defaultCategory = ConversationPracticeRules.stableIdentifier(for: theme)
            let drafts = try importedContainer.decode([ConversationPracticeEntryDraft].self, forKey: .entries)
            entries = drafts.enumerated().map { index, draft in
                ConversationPracticeEntry(
                    draft: draft,
                    fallbackSequence: index + 1,
                    defaultCategory: defaultCategory
                )
            }
        }
    }

    public var practiceSet: ConversationPracticeSet {
        ConversationPracticeSet(
            id: packID,
            title: title,
            description: description,
            language: language,
            itemCount: entries.count
        )
    }

    public var practiceItems: [ConversationPracticeItem] {
        var referencesByItemID: [String: ConversationPracticeSentenceReference] = [:]
        for reference in sentenceReferences {
            referencesByItemID[reference.practiceItemID] = reference
        }
        return entries.sorted { $0.sequence < $1.sequence }.map {
            ConversationPracticeItem(
                entry: $0,
                setID: packID,
                sentenceReference: referencesByItemID[$0.id]
            )
        }
    }

    public var needsCanonicalSentenceReferences: Bool {
        let items = practiceItems
        guard sentenceReferences.count == items.count else { return true }
        var referencesByItemID: [String: ConversationPracticeSentenceReference] = [:]
        for reference in sentenceReferences {
            referencesByItemID[reference.practiceItemID] = reference
        }
        return items.contains { item in
            guard let reference = referencesByItemID[item.id] else { return true }
            return reference.sentenceExampleID == nil ||
                reference.rank != item.rank ||
                reference.sentenceKey != SentenceExampleRecord.normalizedChineseKey(item.simplified)
        }
    }

    public var practiceLibrary: ConversationPracticeLibrary {
        let items = practiceItems
        return ConversationPracticeLibrary(
            set: practiceSet,
            items: items,
            phraseSeeds: items.map(ConversationPracticePhraseSeed.init),
            memberships: items.map(ConversationPracticeMembership.init)
        )
    }

    public func withSourceLink(_ sourceLink: ConversationPracticeSourceLink?) -> ConversationPracticePack {
        ConversationPracticePack(
            packID: packID,
            version: version,
            title: title,
            description: description,
            language: language,
            sourceType: sourceType,
            createdFor: createdFor,
            sourceLink: sourceLink,
            sentenceReferences: sentenceReferences,
            entries: entries
        )
    }

    public func withSentenceReferences(_ references: [ConversationPracticeSentenceReference]) -> ConversationPracticePack {
        ConversationPracticePack(
            packID: packID,
            version: version,
            title: title,
            description: description,
            language: language,
            sourceType: sourceType,
            createdFor: createdFor,
            sourceLink: sourceLink,
            sentenceReferences: references,
            entries: entries
        )
    }

    public func withCanonicalSentenceReferences(
        from sentenceExamples: [SentenceExampleRecord]
    ) -> ConversationPracticePack {
        var recordsByKey: [String: SentenceExampleRecord] = [:]
        for record in sentenceExamples {
            recordsByKey[record.normalizedChineseKey] = record
        }
        let references = practiceItems.map { item in
            let key = SentenceExampleRecord.normalizedChineseKey(item.simplified)
            return ConversationPracticeSentenceReference(
                practiceItemID: item.id,
                rank: item.rank,
                sentenceExampleID: recordsByKey[key]?.id,
                sentenceKey: key
            )
        }
        return withSentenceReferences(references)
    }
}

public enum ConversationPracticeSourceKind: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case savedPage = "saved_page"
}

public struct ConversationPracticeSourceLink: Codable, Equatable, Hashable, Sendable {
    public let kind: ConversationPracticeSourceKind
    public let sourceID: String?
    public let sourceTitle: String
    public let sourceCreatedAt: Date?
    public let contentFingerprint: String?

    enum CodingKeys: String, CodingKey {
        case kind
        case sourceID = "source_id"
        case sourceTitle = "source_title"
        case sourceCreatedAt = "source_created_at"
        case contentFingerprint = "content_fingerprint"
    }

    public static func savedPage(
        id: UUID,
        title: String,
        createdAt: Date?,
        contentFingerprint: String? = nil
    ) -> ConversationPracticeSourceLink {
        ConversationPracticeSourceLink(
            kind: .savedPage,
            sourceID: id.uuidString,
            sourceTitle: title,
            sourceCreatedAt: createdAt,
            contentFingerprint: contentFingerprint
        )
    }

    public var sourcePageID: UUID? {
        guard kind == .savedPage, let sourceID else { return nil }
        return UUID(uuidString: sourceID)
    }
}

public struct ConversationPracticeSentenceReference: Codable, Equatable, Hashable, Identifiable, Sendable {
    public let practiceItemID: String
    public let rank: Int
    public let sentenceExampleID: UUID?
    public let sentenceKey: String

    enum CodingKeys: String, CodingKey {
        case practiceItemID = "practice_item_id"
        case rank
        case sentenceExampleID = "sentence_example_id"
        case sentenceKey = "sentence_key"
    }

    public var id: String {
        "\(rank)#\(practiceItemID)"
    }

    public init(
        practiceItemID: String,
        rank: Int,
        sentenceExampleID: UUID?,
        sentenceKey: String
    ) {
        self.practiceItemID = practiceItemID
        self.rank = rank
        self.sentenceExampleID = sentenceExampleID
        self.sentenceKey = sentenceKey
    }
}

public enum SentenceExampleScript: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case simplified
    case traditional
    case mixed
    case unknown
}

public enum SentenceExampleSourceType: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
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

public struct RadixCapturePayload: Decodable, Equatable, Sendable {
    public let source: RadixCaptureSourceDraft?
    public let sentenceExamples: [RadixCaptureSentenceDraft]

    enum CodingKeys: String, CodingKey {
        case source
        case sentences
        case sentenceExamples = "sentence_examples"
    }

    public init(
        source: RadixCaptureSourceDraft? = nil,
        sentenceExamples: [RadixCaptureSentenceDraft]
    ) {
        self.source = source
        self.sentenceExamples = sentenceExamples
    }

    public init(from decoder: Decoder) throws {
        if var unkeyedContainer = try? decoder.unkeyedContainer() {
            var drafts: [RadixCaptureSentenceDraft] = []
            while !unkeyedContainer.isAtEnd {
                drafts.append(try unkeyedContainer.decode(RadixCaptureSentenceDraft.self))
            }
            source = nil
            sentenceExamples = drafts
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        source = try container.decodeIfPresent(RadixCaptureSourceDraft.self, forKey: .source)
        sentenceExamples = try container.decodeIfPresent([RadixCaptureSentenceDraft].self, forKey: .sentenceExamples)
            ?? container.decodeIfPresent([RadixCaptureSentenceDraft].self, forKey: .sentences)
            ?? []
    }

    public func sentenceRecords(createdAt: Date = Date()) -> [SentenceExampleRecord] {
        sentenceExamples.compactMap {
            $0.sentenceRecord(defaultSource: source, createdAt: createdAt)
        }
    }
}

public struct RadixCaptureSourceDraft: Codable, Equatable, Sendable {
    public let sourceType: SentenceExampleSourceType?
    public let sourceID: String?
    public let sourceTitle: String?
    public let sourcePageID: UUID?
    public let practicePackID: String?
    public let practiceItemID: String?

    enum CodingKeys: String, CodingKey {
        case sourceType = "source_type"
        case sourceID = "source_id"
        case sourceTitle = "source_title"
        case sourcePageID = "source_page_id"
        case practicePackID = "practice_pack_id"
        case practiceItemID = "practice_item_id"
    }

    public init(
        sourceType: SentenceExampleSourceType? = nil,
        sourceID: String? = nil,
        sourceTitle: String? = nil,
        sourcePageID: UUID? = nil,
        practicePackID: String? = nil,
        practiceItemID: String? = nil
    ) {
        self.sourceType = sourceType
        self.sourceID = sourceID
        self.sourceTitle = sourceTitle
        self.sourcePageID = sourcePageID
        self.practicePackID = practicePackID
        self.practiceItemID = practiceItemID
    }

    func sourceReference(fallbackType: SentenceExampleSourceType = .aiGenerated) -> SentenceExampleSourceReference {
        SentenceExampleSourceReference(
            sourceType: sourceType ?? fallbackType,
            sourceID: sourceID,
            sourceTitle: sourceTitle,
            sourcePageID: sourcePageID,
            practicePackID: practicePackID,
            practiceItemID: practiceItemID
        )
    }
}

public struct RadixCaptureSentenceDraft: Decodable, Equatable, Sendable {
    public let chinese: String
    public let script: SentenceExampleScript?
    public let pinyin: String?
    public let english: String?
    public let source: RadixCaptureSourceDraft?
    public let characters: [String]
    public let phrases: [String]
    public let grammarPoints: [String]
    public let hskLevel: Int?
    public let difficulty: SentenceExampleDifficulty?
    public let naturalness: String?
    public let isFavorited: Bool
    public let isHidden: Bool
    public let qualityScore: Double?
    public let notes: String
    public let tags: [String]

    enum CodingKeys: String, CodingKey {
        case zh
        case chinese
        case script
        case pinyin
        case en
        case english
        case source
        case characters
        case targetCharacters = "target_characters"
        case phrases
        case targetPhrases = "target_phrases"
        case grammarPoints = "grammar_points"
        case hskLevel = "hsk_level"
        case difficulty
        case naturalness
        case isFavorited = "is_favorited"
        case isHidden = "is_hidden"
        case qualityScore = "quality_score"
        case notes
        case tags
    }

    public init(
        chinese: String,
        script: SentenceExampleScript? = nil,
        pinyin: String? = nil,
        english: String? = nil,
        source: RadixCaptureSourceDraft? = nil,
        characters: [String] = [],
        phrases: [String] = [],
        grammarPoints: [String] = [],
        hskLevel: Int? = nil,
        difficulty: SentenceExampleDifficulty? = nil,
        naturalness: String? = nil,
        isFavorited: Bool = false,
        isHidden: Bool = false,
        qualityScore: Double? = nil,
        notes: String = "",
        tags: [String] = []
    ) {
        self.chinese = chinese
        self.script = script
        self.pinyin = pinyin
        self.english = english
        self.source = source
        self.characters = characters
        self.phrases = phrases
        self.grammarPoints = grammarPoints
        self.hskLevel = hskLevel
        self.difficulty = difficulty
        self.naturalness = naturalness
        self.isFavorited = isFavorited
        self.isHidden = isHidden
        self.qualityScore = qualityScore
        self.notes = notes
        self.tags = tags
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        chinese = try container.decodeIfPresent(String.self, forKey: .chinese)
            ?? container.decodeIfPresent(String.self, forKey: .zh)
            ?? ""
        script = try container.decodeIfPresent(SentenceExampleScript.self, forKey: .script)
        pinyin = try container.decodeIfPresent(String.self, forKey: .pinyin)
        english = try container.decodeIfPresent(String.self, forKey: .english)
            ?? container.decodeIfPresent(String.self, forKey: .en)
        source = try container.decodeIfPresent(RadixCaptureSourceDraft.self, forKey: .source)
        characters = try container.decodeIfPresent([String].self, forKey: .characters)
            ?? container.decodeIfPresent([String].self, forKey: .targetCharacters)
            ?? []
        phrases = try container.decodeIfPresent([String].self, forKey: .phrases)
            ?? container.decodeIfPresent([String].self, forKey: .targetPhrases)
            ?? []
        grammarPoints = try container.decodeIfPresent([String].self, forKey: .grammarPoints) ?? []
        hskLevel = try container.decodeIfPresent(Int.self, forKey: .hskLevel)
        difficulty = try container.decodeIfPresent(SentenceExampleDifficulty.self, forKey: .difficulty)
        naturalness = try container.decodeIfPresent(String.self, forKey: .naturalness)
        isFavorited = try container.decodeIfPresent(Bool.self, forKey: .isFavorited) ?? false
        isHidden = try container.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false
        qualityScore = try container.decodeIfPresent(Double.self, forKey: .qualityScore)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
    }

    public func sentenceRecord(
        defaultSource: RadixCaptureSourceDraft?,
        createdAt: Date = Date()
    ) -> SentenceExampleRecord? {
        let trimmedChinese = chinese.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedChinese.isEmpty else { return nil }
        let sourceReference = (source ?? defaultSource)?.sourceReference(fallbackType: .aiGenerated)
        return SentenceExampleRecord(
            chinese: trimmedChinese,
            script: script ?? .unknown,
            pinyin: pinyin,
            english: english,
            sources: sourceReference.map { [$0] } ?? [],
            targetCharacters: characters,
            targetPhrases: phrases,
            detectedCharacters: SentenceExampleRecord.detectChineseCharacters(in: trimmedChinese),
            detectedPhrases: phrases,
            grammarPoints: grammarPoints,
            hskLevel: hskLevel,
            difficulty: difficulty ?? .unknown,
            naturalness: naturalness,
            createdAt: createdAt,
            isFavorited: isFavorited,
            isHidden: isHidden,
            qualityScore: qualityScore ?? (isFavorited ? 2 : 0),
            notes: notes,
            tags: tags
        )
    }
}

public enum RadixCaptureJSONParser {
    private static let startMarker = "[Radix Capture JSON]"
    private static let endMarker = "[/Radix Capture JSON]"

    public static func captureJSONCandidates(from text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var candidates: [String] = []
        var searchRange = trimmed.startIndex..<trimmed.endIndex
        while let startRange = trimmed.range(
            of: startMarker,
            options: [.caseInsensitive],
            range: searchRange
        ) {
            let bodyStart = startRange.upperBound
            let endRange = trimmed.range(
                of: endMarker,
                options: [.caseInsensitive],
                range: bodyStart..<trimmed.endIndex
            )
            let bodyEnd = endRange?.lowerBound ?? trimmed.endIndex
            appendJSONCandidates(from: String(trimmed[bodyStart..<bodyEnd]), to: &candidates)
            guard let endRange else { break }
            searchRange = endRange.upperBound..<trimmed.endIndex
        }

        if candidates.isEmpty {
            appendJSONCandidates(from: trimmed, to: &candidates)
        }

        var seen = Set<String>()
        return candidates.filter { candidate in
            guard !seen.contains(candidate) else { return false }
            seen.insert(candidate)
            return true
        }
    }

    public static func payloads(from text: String) -> [RadixCapturePayload] {
        let decoder = JSONDecoder()
        return captureJSONCandidates(from: text).compactMap { candidate in
            try? decoder.decode(RadixCapturePayload.self, from: Data(candidate.utf8))
        }
    }

    public static func sentenceExamples(from text: String, createdAt: Date = Date()) -> [SentenceExampleRecord] {
        let records = payloads(from: text).flatMap {
            $0.sentenceRecords(createdAt: createdAt)
        }
        return SentenceExampleRecord.upserting(records, into: [])
    }

    private static func appendJSONCandidates(from text: String, to candidates: inout [String]) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        candidates.append(trimmed)

        let lines = trimmed.components(separatedBy: .newlines)
        if let firstLine = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines),
           firstLine.hasPrefix("```") {
            var bodyLines = Array(lines.dropFirst())
            if bodyLines.last?.trimmingCharacters(in: .whitespacesAndNewlines) == "```" {
                bodyLines.removeLast()
            }
            let fencedBody = bodyLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !fencedBody.isEmpty {
                candidates.append(fencedBody)
            }
        }

        if let object = jsonSubstring(in: trimmed, opening: "{", closing: "}") {
            candidates.append(object)
        }
        if let array = jsonSubstring(in: trimmed, opening: "[", closing: "]") {
            candidates.append(array)
        }
    }

    private static func jsonSubstring(in text: String, opening: Character, closing: Character) -> String? {
        guard let first = text.firstIndex(of: opening),
              let last = text.lastIndex(of: closing),
              first < last
        else {
            return nil
        }
        return String(text[first...last]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct ConversationPracticeEntry: Codable, Equatable, Identifiable {
    public let id: String
    public let sequence: Int
    public let category: String
    public let level: String
    public let sentence: ConversationPracticeSentence
    public let analysis: ConversationPracticeAnalysis
    public let metadata: ConversationPracticeMetadata
    public let notes: String

    fileprivate init(
        draft: ConversationPracticeEntryDraft,
        fallbackSequence: Int,
        defaultCategory: String
    ) {
        id = draft.id
        sequence = draft.sequence ?? fallbackSequence
        category = draft.category ?? defaultCategory
        level = draft.level ?? "easy"
        sentence = draft.sentence
        analysis = draft.analysis ?? ConversationPracticeAnalysis(sentence: draft.sentence.zh)
        metadata = draft.metadata ?? ConversationPracticeMetadata(category: category)
        notes = draft.notes ?? ""
    }
}

public struct ConversationPracticeSentence: Codable, Equatable {
    public let zh: String
    public let pinyin: String
    public let en: String
}

public struct ConversationPracticeAnalysis: Codable, Equatable {
    public let characters: [String]
    public let phrases: [String]

    init(characters: [String], phrases: [String]) {
        self.characters = characters
        self.phrases = phrases
    }

    init(sentence: String) {
        var seen: Set<String> = []
        var orderedCharacters: [String] = []
        for character in sentence where ConversationPracticeRules.isChineseCharacter(character) {
            let value = String(character)
            if seen.insert(value).inserted {
                orderedCharacters.append(value)
            }
        }
        characters = orderedCharacters
        phrases = [ConversationPracticeRules.phraseKey(for: sentence)]
    }
}

public struct ConversationPracticeMetadata: Codable, Equatable {
    public let difficulty: Int
    public let frequency: Int
    public let tags: [String]

    init(difficulty: Int, frequency: Int, tags: [String]) {
        self.difficulty = difficulty
        self.frequency = frequency
        self.tags = tags
    }

    init(category: String) {
        difficulty = 1
        frequency = 1
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        tags = trimmedCategory.isEmpty ? [] : [trimmedCategory]
    }
}

private struct ConversationPracticeEntryDraft: Decodable {
    let id: String
    let sequence: Int?
    let category: String?
    let level: String?
    let sentence: ConversationPracticeSentence
    let analysis: ConversationPracticeAnalysis?
    let metadata: ConversationPracticeMetadata?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id
        case sequence
        case category
        case level
        case sentence
        case analysis
        case metadata
        case notes
        case zh
        case pinyin
        case en
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        sequence = try container.decodeIfPresent(Int.self, forKey: .sequence)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        level = try container.decodeIfPresent(String.self, forKey: .level)
        if let decodedSentence = try container.decodeIfPresent(ConversationPracticeSentence.self, forKey: .sentence) {
            sentence = decodedSentence
        } else {
            sentence = ConversationPracticeSentence(
                zh: try container.decode(String.self, forKey: .zh),
                pinyin: try container.decode(String.self, forKey: .pinyin),
                en: try container.decode(String.self, forKey: .en)
            )
        }
        analysis = try container.decodeIfPresent(ConversationPracticeAnalysis.self, forKey: .analysis)
        metadata = try container.decodeIfPresent(ConversationPracticeMetadata.self, forKey: .metadata)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }
}

public struct ConversationPracticeSet: Equatable, Identifiable {
    public let id: String
    public let title: String
    public let description: String
    public let language: String
    public let itemCount: Int
}

public struct ConversationPracticeTopic: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let summary: String
    public let difficultyLabel: String
    public let bundledResourceName: String?
    public let generationBrief: String
    public let situations: [String]
    public let targetSentenceCount: Int

    public var hasBundledContent: Bool {
        bundledResourceName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    public static let generalGreetings = ConversationPracticeTopic(
        id: "general_greetings",
        title: "General Greetings",
        summary: "Common beginner greetings and social basics.",
        difficultyLabel: "Easy starter set",
        bundledResourceName: "conversation100",
        generationBrief: "General greetings and everyday social openings for beginner Mandarin learners.",
        situations: [
            "saying hello and goodbye",
            "morning and evening greetings",
            "asking how someone is",
            "polite thanks and apologies",
            "simple social responses"
        ],
        targetSentenceCount: 100
    )

    public static let foodEating = ConversationPracticeTopic(
        id: "food_eating",
        title: "Food / Eating Conversation",
        summary: "Ordering, sharing dishes, taste, price, portions, and polite mealtime talk.",
        difficultyLabel: "Easy situational set",
        bundledResourceName: "Food Dining",
        generationBrief: "Restaurant, hawker centre or casual eatery, and home dinner-table Mandarin conversation about eating, ordering food, sharing dishes, preferences, prices, portions, taste, and polite offers or responses.",
        situations: [
            "ordering food in a restaurant",
            "eating at a hawker centre or casual eatery",
            "dinner table conversation at home",
            "asking about taste, price, portions, and preferences",
            "offering food and responding politely"
        ],
        targetSentenceCount: 100
    )

    public static let tripToFourCities = ConversationPracticeTopic(
        id: "china_taiwan_travel",
        title: "Trip to 4 Cities",
        summary: "Transport, hotels, sightseeing, and polite travel help in Beijing, Shanghai, Guangzhou, and Taipei.",
        difficultyLabel: "Easy travel set",
        bundledResourceName: "Trip to 4 cities",
        generationBrief: "Travel Mandarin for Beijing, Shanghai, Guangzhou, and Taipei, covering taxis, metro, airport, hotels, sightseeing, shopping, directions, prices, help, and polite local interactions.",
        situations: [
            "taking taxis, metro, trains, and airport transport",
            "checking in and asking hotel questions",
            "asking directions around the city",
            "buying tickets, shopping, and asking prices",
            "sightseeing and polite travel help"
        ],
        targetSentenceCount: 100
    )

    public static let stayInShanghai = ConversationPracticeTopic(
        id: "shanghai_relocation_study",
        title: "Stay in Shanghai",
        summary: "Longer-stay Shanghai Mandarin for study, housing, transport, utilities, and local admin.",
        difficultyLabel: "Practical city-living set",
        bundledResourceName: "Stay in Shanghai",
        generationBrief: "Longer-stay Shanghai Mandarin for Mandarin courses, student life, housing, utilities, transport, healthcare, shopping, local services, and administrative tasks.",
        situations: [
            "asking about Mandarin courses and study schedules",
            "finding housing and handling rent or utilities",
            "using transport and local city services",
            "shopping, errands, healthcare, and daily needs",
            "handling registration and administrative tasks"
        ],
        targetSentenceCount: 100
    )

    public static let everydayConversation = generationTopic(
        id: "everyday_conversation",
        title: "Everyday Conversation",
        summary: "Greetings, small talk, plans, time, weather, and daily routines.",
        generationBrief: "Everyday Mandarin conversation for greetings, introductions, polite expressions, small talk, time, dates, weather, daily routines, making plans, clarifying meaning, apologizing, thanking, and simple social responses.",
        situations: [
            "greetings, introductions, and polite expressions",
            "small talk about weather, time, and daily routines",
            "making plans and confirming details",
            "asking for clarification or repetition",
            "apologizing, thanking, and simple social responses"
        ]
    )

    public static let foodShopping = generationTopic(
        id: "food_shopping",
        title: "Food & Shopping",
        summary: "Restaurants, groceries, cooking, payments, bargaining, clothes, and online shopping.",
        generationBrief: "Practical Mandarin for restaurants, cafes, street food, groceries, cooking, dietary needs, paying bills, bargaining, clothes shopping, online shopping, returns, and exchanges.",
        situations: [
            "ordering food and drinks",
            "buying groceries and talking about cooking",
            "explaining taste, price, portions, and dietary needs",
            "shopping for clothes or everyday goods",
            "paying, bargaining, returning, or exchanging items"
        ]
    )

    public static let travelTransportation = generationTopic(
        id: "travel_transportation",
        title: "Travel & Transportation",
        summary: "Airports, trains, taxis, directions, hotels, sightseeing, and travel problems.",
        generationBrief: "Travel Mandarin for airports, trains, taxis, ride-hailing, buses, metro, asking directions, hotel check-in, sightseeing, immigration, customs, luggage, delays, and travel problems.",
        situations: [
            "using airports, trains, buses, metro, taxis, and ride-hailing",
            "asking for directions and route details",
            "checking in at hotels and asking for help",
            "buying tickets and visiting attractions",
            "handling luggage, delays, and travel problems"
        ]
    )

    public static let homePersonalLife = generationTopic(
        id: "home_personal_life",
        title: "Home & Personal Life",
        summary: "Family, friends, relationships, housing, chores, neighbors, hobbies, and weekends.",
        generationBrief: "Mandarin conversation about family, friends, relationships, home life, household chores, rooms, furniture, renting, neighbors, personal habits, hobbies, and weekend activities.",
        situations: [
            "talking about family, friends, and relationships",
            "describing home life, rooms, and furniture",
            "renting housing and talking with neighbors",
            "handling chores and daily household tasks",
            "sharing hobbies, habits, and weekend activities"
        ]
    )

    public static let workSchool = generationTopic(
        id: "work_school",
        title: "Work & School",
        summary: "Office talk, meetings, interviews, school life, homework, exams, and presentations.",
        generationBrief: "Mandarin for work and school, including job interviews, office conversation, meetings, email and messaging, asking for help, project updates, customer service, classroom questions, homework, exams, university life, and presentations.",
        situations: [
            "job interviews and workplace introductions",
            "meetings, project updates, and office requests",
            "customer service and professional messaging",
            "classroom questions, homework, and exams",
            "university life and presentations"
        ]
    )

    public static let healthEmergencies = generationTopic(
        id: "health_emergencies",
        title: "Health & Emergencies",
        summary: "Pharmacy, doctor, dentist, symptoms, medicine, allergies, safety, and urgent help.",
        generationBrief: "Health and safety Mandarin for pharmacies, doctor visits, dentists, hospitals, symptoms, pain, medicine instructions, allergies, mental-health check-ins, exercise, fitness, emergency help, and urgent safety situations.",
        situations: [
            "explaining symptoms, pain, and allergies",
            "visiting a pharmacy, doctor, dentist, or hospital",
            "understanding medicine and care instructions",
            "asking for urgent or emergency help",
            "talking about exercise, fitness, and wellbeing"
        ]
    )

    public static let cityLifeServices = generationTopic(
        id: "city_life_services",
        title: "City Life & Services",
        summary: "Bank, post office, phone shop, salon, repairs, police, lost and found, and local offices.",
        generationBrief: "Mandarin for city services and errands, including banks, post offices, phone shops, hair salons, laundry, repairs, police stations, lost and found, community services, government offices, and appointments.",
        situations: [
            "using banks, post offices, and phone shops",
            "booking salons, laundry, repair, or other services",
            "reporting lost items or asking police for help",
            "handling community or government office tasks",
            "making, changing, and confirming appointments"
        ]
    )

    public static let socialCulture = generationTopic(
        id: "social_culture",
        title: "Social & Culture",
        summary: "Festivals, birthdays, visits, gifts, invitations, parties, dating, media, sports, and culture.",
        generationBrief: "Social and cultural Mandarin for festivals, birthdays, visiting someone's home, giving gifts, dating, making friends, invitations, parties, movies, music, sports, news, current events, and cultural differences.",
        situations: [
            "festivals, birthdays, and visiting someone's home",
            "giving gifts and responding politely",
            "making friends, dating, and invitations",
            "talking about parties, movies, music, and sports",
            "discussing news, culture, and cultural differences"
        ]
    )

    public static let technologyModernLife = generationTopic(
        id: "technology_modern_life",
        title: "Technology & Modern Life",
        summary: "Phones, apps, passwords, payments, delivery, navigation, social media, and tech support.",
        generationBrief: "Modern-life Mandarin for phones, apps, passwords, social media, online payments, delivery apps, navigation apps, tech support, AI, internet topics, privacy, and security.",
        situations: [
            "setting up phones, apps, passwords, and accounts",
            "using online payments and delivery apps",
            "asking for navigation or tech support",
            "talking about social media, AI, and internet topics",
            "handling privacy, security, and account problems"
        ]
    )

    public static let opinionsDeeperTalk = generationTopic(
        id: "opinions_deeper_talk",
        title: "Opinions & Deeper Talk",
        summary: "Preferences, comparisons, advice, disagreement, reasons, emotions, goals, values, and learning Chinese.",
        generationBrief: "Mandarin for opinions and deeper conversation, including preferences, comparisons, advice, agreeing and disagreeing, explaining reasons, describing experiences, emotions, goals, plans, personal values, learning Chinese, and cross-cultural conversation.",
        situations: [
            "expressing preferences and comparing options",
            "giving advice and agreeing or disagreeing politely",
            "explaining reasons and describing experiences",
            "talking about emotions, goals, plans, and values",
            "discussing learning Chinese and cross-cultural topics"
        ]
    )

    public static let defaults: [ConversationPracticeTopic] = [
        .generalGreetings,
        .foodEating,
        .tripToFourCities,
        .stayInShanghai,
        .everydayConversation,
        .foodShopping,
        .travelTransportation,
        .homePersonalLife,
        .workSchool,
        .healthEmergencies,
        .cityLifeServices,
        .socialCulture,
        .technologyModernLife,
        .opinionsDeeperTalk
    ]

    public static let favoriteSentencesID = "favorite_sentences"

    public static func favoriteSentences(count: Int) -> ConversationPracticeTopic {
        ConversationPracticeTopic(
            id: favoriteSentencesID,
            title: "Favorite Sentences",
            summary: "\(count) saved sentences",
            difficultyLabel: "Saved from Study",
            bundledResourceName: nil,
            generationBrief: "Learner-saved Chinese sentences for review and practice.",
            situations: [],
            targetSentenceCount: count
        )
    }

    public static func topic(for id: String) -> ConversationPracticeTopic {
        defaults.first { $0.id == id } ?? .generalGreetings
    }

    private static func generationTopic(
        id: String,
        title: String,
        summary: String,
        generationBrief: String,
        situations: [String],
        targetSentenceCount: Int = 100
    ) -> ConversationPracticeTopic {
        ConversationPracticeTopic(
            id: id,
            title: title,
            summary: summary,
            difficultyLabel: "Generation-ready theme",
            bundledResourceName: nil,
            generationBrief: generationBrief,
            situations: situations,
            targetSentenceCount: targetSentenceCount
        )
    }
}

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

public enum ConversationPracticeProgressOutcome: String, Codable, Equatable, Sendable {
    case again
    case good
    case easy
    case correct
    case incorrect

    public var countsAsCompletion: Bool {
        switch self {
        case .good, .easy, .correct:
            return true
        case .again, .incorrect:
            return false
        }
    }
}

public struct ConversationPracticeItemProgress: Codable, Equatable, Identifiable, Sendable {
    public let packID: String
    public let itemID: String
    public private(set) var sentenceExampleID: UUID?
    public private(set) var sentenceKey: String?
    public private(set) var attempts: Int
    public private(set) var completedAttempts: Int
    public private(set) var lastOutcome: ConversationPracticeProgressOutcome
    public private(set) var lastPracticedAt: Date
    public private(set) var completedAt: Date?

    enum CodingKeys: String, CodingKey {
        case packID = "pack_id"
        case itemID = "item_id"
        case sentenceExampleID = "sentence_example_id"
        case sentenceKey = "sentence_key"
        case attempts
        case completedAttempts = "completed_attempts"
        case lastOutcome = "last_outcome"
        case lastPracticedAt = "last_practiced_at"
        case completedAt = "completed_at"
    }

    public var id: String {
        Self.identifier(packID: packID, itemID: itemID)
    }

    public var isCompleted: Bool {
        completedAt != nil
    }

    public var progressID: String {
        if let sentenceExampleID {
            return "sentence_id:\(sentenceExampleID.uuidString)"
        }
        if let sentenceKey, !sentenceKey.isEmpty {
            return "sentence_key:\(sentenceKey)"
        }
        return id
    }

    public init(
        packID: String,
        itemID: String,
        sentenceExampleID: UUID? = nil,
        sentenceKey: String? = nil,
        attempts: Int,
        completedAttempts: Int,
        lastOutcome: ConversationPracticeProgressOutcome,
        lastPracticedAt: Date,
        completedAt: Date?
    ) {
        self.packID = packID
        self.itemID = itemID
        self.sentenceExampleID = sentenceExampleID
        self.sentenceKey = Self.cleanSentenceKey(sentenceKey)
        self.attempts = max(0, attempts)
        self.completedAttempts = max(0, completedAttempts)
        self.lastOutcome = lastOutcome
        self.lastPracticedAt = lastPracticedAt
        self.completedAt = completedAt
    }

    public static func identifier(packID: String, itemID: String) -> String {
        "\(packID)#\(itemID)"
    }

    public func matches(_ item: ConversationPracticeItem) -> Bool {
        if let sentenceExampleID, sentenceExampleID == item.sentenceExampleID {
            return true
        }
        if let sentenceKey, !sentenceKey.isEmpty, sentenceKey == item.sentenceKey {
            return true
        }
        return packID == item.setID && itemID == item.id
    }

    public mutating func record(
        _ outcome: ConversationPracticeProgressOutcome,
        practicedAt: Date = Date()
    ) {
        attempts += 1
        lastOutcome = outcome
        lastPracticedAt = practicedAt

        if outcome.countsAsCompletion {
            completedAttempts += 1
            if completedAt == nil {
                completedAt = practicedAt
            }
        }
    }

    public mutating func attachSentenceIdentity(from item: ConversationPracticeItem) {
        if sentenceExampleID == nil {
            sentenceExampleID = item.sentenceExampleID
        }
        if sentenceKey == nil || sentenceKey?.isEmpty == true {
            sentenceKey = Self.cleanSentenceKey(item.sentenceKey)
        }
    }

    private static func cleanSentenceKey(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else { return nil }
        return trimmed
    }
}

public struct ConversationPracticeProgressSnapshot: Codable, Equatable, Sendable {
    public private(set) var records: [ConversationPracticeItemProgress]

    enum CodingKeys: String, CodingKey {
        case records
    }

    public init(records: [ConversationPracticeItemProgress] = []) {
        self.records = Self.uniqueNewest(records)
    }

    public func record(for packID: String, itemID: String) -> ConversationPracticeItemProgress? {
        let id = ConversationPracticeItemProgress.identifier(packID: packID, itemID: itemID)
        return records.first { $0.id == id }
    }

    public func record(for item: ConversationPracticeItem) -> ConversationPracticeItemProgress? {
        records.first { $0.matches(item) }
    }

    public mutating func record(
        packID: String,
        itemID: String,
        outcome: ConversationPracticeProgressOutcome,
        practicedAt: Date = Date()
    ) {
        let id = ConversationPracticeItemProgress.identifier(packID: packID, itemID: itemID)
        if let index = records.firstIndex(where: { $0.id == id }) {
            records[index].record(outcome, practicedAt: practicedAt)
        } else {
            var progress = ConversationPracticeItemProgress(
                packID: packID,
                itemID: itemID,
                attempts: 0,
                completedAttempts: 0,
                lastOutcome: outcome,
                lastPracticedAt: practicedAt,
                completedAt: nil
            )
            progress.record(outcome, practicedAt: practicedAt)
            records.append(progress)
            records.sort { $0.id < $1.id }
        }
    }

    public mutating func record(
        item: ConversationPracticeItem,
        outcome: ConversationPracticeProgressOutcome,
        practicedAt: Date = Date()
    ) {
        if let index = records.firstIndex(where: { $0.matches(item) }) {
            records[index].attachSentenceIdentity(from: item)
            records[index].record(outcome, practicedAt: practicedAt)
        } else {
            var progress = ConversationPracticeItemProgress(
                packID: item.setID,
                itemID: item.id,
                sentenceExampleID: item.sentenceExampleID,
                sentenceKey: item.sentenceKey,
                attempts: 0,
                completedAttempts: 0,
                lastOutcome: outcome,
                lastPracticedAt: practicedAt,
                completedAt: nil
            )
            progress.record(outcome, practicedAt: practicedAt)
            records.append(progress)
        }
        records = Self.uniqueNewest(records)
    }

    public func summary(for library: ConversationPracticeLibrary) -> ConversationPracticeProgressSummary {
        let matchingRecords = library.items.compactMap { item in
            record(for: item)
        }
        let completed = matchingRecords.filter(\.isCompleted).count
        let lastPracticedAt = matchingRecords.map(\.lastPracticedAt).max()
        return ConversationPracticeProgressSummary(
            packID: library.set.id,
            totalItems: library.items.count,
            completedItems: completed,
            lastPracticedAt: lastPracticedAt
        )
    }

    public func merging(_ imported: ConversationPracticeProgressSnapshot?) -> ConversationPracticeProgressSnapshot {
        guard let imported else { return self }
        return ConversationPracticeProgressSnapshot(records: records + imported.records)
    }

    private static func uniqueNewest(
        _ records: [ConversationPracticeItemProgress]
    ) -> [ConversationPracticeItemProgress] {
        let byID = Dictionary(grouping: records, by: \.progressID)
        return byID.values.compactMap { grouped in
            grouped.max { lhs, rhs in
                lhs.lastPracticedAt < rhs.lastPracticedAt
            }
        }
        .sorted { $0.id < $1.id }
    }
}

public struct ConversationPracticeProgressSummary: Equatable, Sendable {
    public let packID: String
    public let totalItems: Int
    public let completedItems: Int
    public let lastPracticedAt: Date?

    public var completionFraction: Double {
        guard totalItems > 0 else { return 0 }
        return Double(completedItems) / Double(totalItems)
    }
}

public struct ConversationPracticeValidationIssue: Equatable, Sendable, CustomStringConvertible {
    public enum Severity: String, Equatable, Sendable {
        case error
        case warning
    }

    public let severity: Severity
    public let entryID: String?
    public let message: String

    public var description: String {
        if let entryID {
            return "[\(severity.rawValue)] \(entryID): \(message)"
        }
        return "[\(severity.rawValue)] \(message)"
    }
}

public struct ConversationPracticeValidationResult: Equatable {
    public let issues: [ConversationPracticeValidationIssue]

    public var errors: [ConversationPracticeValidationIssue] {
        issues.filter { $0.severity == .error }
    }

    public var warnings: [ConversationPracticeValidationIssue] {
        issues.filter { $0.severity == .warning }
    }

    public var isValid: Bool {
        errors.isEmpty
    }
}

public enum ConversationPracticeRules {
    public static let supportedLanguages: Set<String> = ["zh-Hans"]

    static func importJSONCandidates(from text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var candidates = [trimmed]
        let lines = trimmed.components(separatedBy: .newlines)
        if let firstLine = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines),
           firstLine.hasPrefix("```") {
            var bodyLines = Array(lines.dropFirst())
            if bodyLines.last?.trimmingCharacters(in: .whitespacesAndNewlines) == "```" {
                bodyLines.removeLast()
            }
            let fencedBody = bodyLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !fencedBody.isEmpty {
                candidates.append(fencedBody)
            }
        }

        if let firstBrace = trimmed.firstIndex(of: "{"),
           let lastBrace = trimmed.lastIndex(of: "}"),
           firstBrace < lastBrace {
            let objectBody = String(trimmed[firstBrace...lastBrace])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !objectBody.isEmpty {
                candidates.append(objectBody)
            }
        }

        var seen = Set<String>()
        return candidates.filter { candidate in
            guard !seen.contains(candidate) else { return false }
            seen.insert(candidate)
            return true
        }
    }

    public static func phraseKey(for sentence: String) -> String {
        sentence.trimmingCharacters(in: .whitespacesAndNewlinesAndPunctuation)
    }

    public static func stableIdentifier(for title: String) -> String {
        var result = ""
        var previousWasSeparator = false

        for scalar in title.lowercased().unicodeScalars {
            if (65...90).contains(Int(scalar.value)) || (97...122).contains(Int(scalar.value)) || (48...57).contains(Int(scalar.value)) {
                result.unicodeScalars.append(scalar)
                previousWasSeparator = false
            } else if !previousWasSeparator {
                result.append("_")
                previousWasSeparator = true
            }
        }

        let trimmed = result.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return trimmed.isEmpty ? "imported_practice" : trimmed
    }

    public static func isChineseCharacter(_ character: Character) -> Bool {
        character.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(Int(scalar.value))
        }
    }

    public static func validate(_ pack: ConversationPracticePack) -> ConversationPracticeValidationResult {
        var issues: [ConversationPracticeValidationIssue] = []

        appendRequiredPackIssue(pack.packID, field: "pack_id", to: &issues)
        appendRequiredPackIssue(pack.title, field: "title", to: &issues)

        if !supportedLanguages.contains(pack.language) {
            issues.append(issue("Unsupported language '\(pack.language)'.", severity: .error))
        }

        if pack.entries.isEmpty {
            issues.append(issue("Conversation practice pack has no entries.", severity: .error))
        }

        let sequences = pack.entries.map(\.sequence)
        appendDuplicateIssues(values: pack.entries.map(\.id), label: "entry id", to: &issues)
        appendDuplicateIssues(values: pack.entries.map { phraseKey(for: $0.sentence.zh) }, label: "Chinese sentence", to: &issues)
        appendDuplicateIssues(values: sequences.map(String.init), label: "sequence", to: &issues)
        appendDuplicateIssues(values: pack.practiceItems.map(\.phraseKey), label: "phrase key", to: &issues)

        let sortedSequences = sequences.sorted()
        if let first = sortedSequences.first, let last = sortedSequences.last {
            let expected = Array(first...last)
            if sortedSequences != expected {
                issues.append(issue("Entry sequences must be contiguous.", severity: .error))
            }
        }

        for entry in pack.entries {
            validate(entry, issues: &issues)
        }

        return ConversationPracticeValidationResult(issues: issues)
    }

    private static func validate(
        _ entry: ConversationPracticeEntry,
        issues: inout [ConversationPracticeValidationIssue]
    ) {
        appendRequiredEntryIssue(entry.id, field: "id", entryID: entry.id, to: &issues)
        if entry.sequence <= 0 {
            issues.append(issue("Sequence must be greater than zero.", entryID: entry.id, severity: .error))
        }
        appendRequiredEntryIssue(entry.category, field: "category", entryID: entry.id, to: &issues)
        appendRequiredEntryIssue(entry.level, field: "level", entryID: entry.id, to: &issues)
        appendRequiredEntryIssue(entry.sentence.zh, field: "sentence.zh", entryID: entry.id, to: &issues)
        appendRequiredEntryIssue(entry.sentence.pinyin, field: "sentence.pinyin", entryID: entry.id, to: &issues)
        appendRequiredEntryIssue(entry.sentence.en, field: "sentence.en", entryID: entry.id, to: &issues)

        let characters = Array(entry.sentence.zh.filter { isChineseCharacter($0) }).map(String.init)
        let uniqueHints = Set(entry.analysis.characters)
        for character in characters where !uniqueHints.contains(character) {
            issues.append(issue(
                "Character hint is missing '\(character)'.",
                entryID: entry.id,
                severity: .warning
            ))
        }

        if !entry.analysis.phrases.contains(entry.sentence.zh.trimmingCharacters(in: .whitespacesAndNewlinesAndPunctuation)) {
            issues.append(issue(
                "Phrase hints should include the full sentence without punctuation.",
                entryID: entry.id,
                severity: .warning
            ))
        }

        if entry.metadata.difficulty < 1 {
            issues.append(issue("Difficulty must be at least 1.", entryID: entry.id, severity: .error))
        }
        if entry.metadata.frequency < 1 {
            issues.append(issue("Frequency must be at least 1.", entryID: entry.id, severity: .warning))
        }
        if entry.metadata.tags.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            issues.append(issue("Tags must not be empty.", entryID: entry.id, severity: .error))
        }
    }

    private static func appendRequiredPackIssue(
        _ value: String,
        field: String,
        to issues: inout [ConversationPracticeValidationIssue]
    ) {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(issue("Missing required field '\(field)'.", severity: .error))
        }
    }

    private static func appendRequiredEntryIssue(
        _ value: String,
        field: String,
        entryID: String,
        to issues: inout [ConversationPracticeValidationIssue]
    ) {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(issue("Missing required field '\(field)'.", entryID: entryID, severity: .error))
        }
    }

    private static func appendDuplicateIssues(
        values: [String],
        label: String,
        to issues: inout [ConversationPracticeValidationIssue]
    ) {
        let duplicates = Dictionary(grouping: values, by: { $0 })
            .filter { !$0.key.isEmpty && $0.value.count > 1 }
            .keys
            .sorted()

        for duplicate in duplicates {
            issues.append(issue("Duplicate \(label): \(duplicate)", severity: .error))
        }
    }

    private static func issue(
        _ message: String,
        entryID: String? = nil,
        severity: ConversationPracticeValidationIssue.Severity
    ) -> ConversationPracticeValidationIssue {
        ConversationPracticeValidationIssue(
            severity: severity,
            entryID: entryID,
            message: message
        )
    }

}

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

private extension CharacterSet {
    static let whitespacesAndNewlinesAndPunctuation = CharacterSet.whitespacesAndNewlines
        .union(.punctuationCharacters)
        .union(CharacterSet(charactersIn: "。！？；，、"))
}
