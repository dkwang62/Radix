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

public enum ConversationPracticeRules {
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

    public static func nonOverlappingPhraseHints(_ phrases: [String], in source: String) -> [String] {
        struct Candidate {
            let phrase: String
            let normalizedPhrase: String
            let start: Int
            let end: Int

            var length: Int { end - start }
        }

        var seen = Set<String>()
        var candidates: [Candidate] = []

        for rawPhrase in phrases {
            let phrase = phraseKey(for: rawPhrase)
            guard phrase.count >= 2, seen.insert(phrase).inserted else { continue }

            var searchRange = source.startIndex..<source.endIndex
            while let range = source.range(of: phrase, range: searchRange) {
                let start = source.distance(from: source.startIndex, to: range.lowerBound)
                let end = source.distance(from: source.startIndex, to: range.upperBound)
                candidates.append(Candidate(
                    phrase: rawPhrase,
                    normalizedPhrase: phrase,
                    start: start,
                    end: end
                ))

                guard range.upperBound < source.endIndex else { break }
                searchRange = range.upperBound..<source.endIndex
            }
        }

        let priorityOrdered = candidates.sorted {
            if $0.length != $1.length { return $0.length > $1.length }
            if $0.start != $1.start { return $0.start < $1.start }
            return $0.normalizedPhrase < $1.normalizedPhrase
        }

        var occupiedOffsets = Set<Int>()
        var acceptedPhrases = Set<String>()
        var accepted: [Candidate] = []

        for candidate in priorityOrdered {
            let offsets = candidate.start..<candidate.end
            guard !offsets.contains(where: occupiedOffsets.contains),
                  acceptedPhrases.insert(candidate.normalizedPhrase).inserted
            else { continue }

            occupiedOffsets.formUnion(offsets)
            accepted.append(candidate)
        }

        return accepted.sorted {
            if $0.start != $1.start { return $0.start < $1.start }
            if $0.length != $1.length { return $0.length > $1.length }
            return $0.normalizedPhrase < $1.normalizedPhrase
        }
        .map(\.phrase)
    }

}

extension CharacterSet {
    static let whitespacesAndNewlinesAndPunctuation = CharacterSet.whitespacesAndNewlines
        .union(.punctuationCharacters)
        .union(CharacterSet(charactersIn: "。！？；，、"))
}
