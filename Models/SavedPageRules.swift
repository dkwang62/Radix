import Foundation

enum SavedPageRules {
    static let maximumNameLength = 11

    static func displayName(_ name: String) -> String {
        String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maximumNameLength))
    }

    static func mostRecentID(in pages: [CharacterCollection]) -> UUID? {
        pages.max {
            effectiveDate($0) < effectiveDate($1)
        }?.id
    }

    static func correctedName(originalName: String, existingNames: Set<String>) -> String {
        let cleanOriginal = displayName(originalName)
        let stem = cleanOriginal.isEmpty ? "Corrected" : cleanOriginal

        for suffix in 1...99 {
            let suffixText = String(suffix)
            let prefixLength = max(0, maximumNameLength - suffixText.count)
            let candidate = String(stem.prefix(prefixLength)) + suffixText
            if !existingNames.contains(candidate) {
                return candidate
            }
        }

        return String(UUID().uuidString.prefix(maximumNameLength))
    }

    static func ownership(for artifactType: PageArtifactType) -> PageArtifactOwnership {
        artifactType.defaultOwnership
    }

    static func isDeletedWithPage(_ artifact: PageArtifactDescriptor) -> Bool {
        artifact.ownership == .pageOwned
    }

    private static func effectiveDate(_ page: CharacterCollection) -> Date {
        page.lastViewedAt ?? page.createdAt
    }
}

enum PageArtifactOwnership: String, Codable, CaseIterable, Equatable, Hashable {
    case pageOwned
    case linked
}

enum PageArtifactType: String, Codable, CaseIterable, Equatable, Hashable {
    case aiCleanedPage
    case correctedOCRPage
    case translation
    case quiz
    case extractedSentencePractice
    case pageConversationPractice
    case pageLocalNotes
    case pageAIResult
    case addedPhrase
    case favoriteCharacter
    case favoritePhrase
    case favoriteSentence
    case globalNote
    case reusablePracticeProgress

    var defaultOwnership: PageArtifactOwnership {
        switch self {
        case .aiCleanedPage,
             .correctedOCRPage,
             .translation,
             .quiz,
             .extractedSentencePractice,
             .pageConversationPractice,
             .pageLocalNotes,
             .pageAIResult:
            return .pageOwned
        case .addedPhrase,
             .favoriteCharacter,
             .favoritePhrase,
             .favoriteSentence,
             .globalNote,
             .reusablePracticeProgress:
            return .linked
        }
    }
}

struct AICleanedPageRecord: Codable, Equatable, Hashable, Identifiable {
    let sourcePageID: UUID
    var sourceTitle: String
    var cleanedTitle: String
    var cleanedChineseText: String
    var sentences: [AICleanedPageSentence]
    var englishSummary: String?
    var repairNotes: [String]
    var createdAt: Date

    var id: UUID { sourcePageID }

    enum CodingKeys: String, CodingKey {
        case sourcePageID = "source_page_id"
        case sourceTitle = "source_title"
        case cleanedTitle = "cleaned_title"
        case cleanedChineseText = "cleaned_chinese_text"
        case sentences
        case englishSummary = "english_summary"
        case repairNotes = "repair_notes"
        case createdAt = "created_at"
    }

    init(
        sourcePageID: UUID,
        sourceTitle: String,
        cleanedTitle: String,
        cleanedChineseText: String,
        sentences: [AICleanedPageSentence],
        englishSummary: String? = nil,
        repairNotes: [String] = [],
        createdAt: Date
    ) {
        self.sourcePageID = sourcePageID
        self.sourceTitle = sourceTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        self.cleanedTitle = cleanedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        self.cleanedChineseText = cleanedChineseText.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sentences = sentences
        let cleanSummary = englishSummary?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.englishSummary = cleanSummary?.isEmpty == true ? nil : cleanSummary
        self.repairNotes = repairNotes
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.createdAt = createdAt
    }

    var artifactDescriptor: PageArtifactDescriptor {
        PageArtifactDescriptor(
            sourcePageID: sourcePageID,
            artifactType: .aiCleanedPage,
            artifactID: sourcePageID.uuidString,
            displayTitle: cleanedTitle.isEmpty ? "Extracted sentences" : cleanedTitle,
            createdAt: createdAt
        )
    }
}

struct AICleanedPageSentence: Codable, Equatable, Hashable, Identifiable {
    var id: String
    var chinese: String
    var pinyin: String?
    var english: String?
    var phraseHints: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case chinese
        case pinyin
        case english
        case phraseHints = "phrase_hints"
    }

    init(
        id: String,
        chinese: String,
        pinyin: String? = nil,
        english: String? = nil,
        phraseHints: [String] = []
    ) {
        self.id = id.trimmingCharacters(in: .whitespacesAndNewlines)
        self.chinese = chinese.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPinyin = pinyin?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.pinyin = cleanPinyin?.isEmpty == true ? nil : cleanPinyin
        let cleanEnglish = english?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.english = cleanEnglish?.isEmpty == true ? nil : cleanEnglish
        self.phraseHints = phraseHints
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: FlexibleCodingKey.self)
        self.init(
            id: container.decodeFirstString(for: ["id", "sentence_id", "sentenceID"]) ?? "",
            chinese: container.decodeFirstString(for: ["chinese", "zh", "sentence", "text", "cn"]) ?? "",
            pinyin: container.decodeFirstString(for: ["pinyin", "pin_yin"]),
            english: container.decodeFirstString(for: ["english", "en", "meaning", "translation"]),
            phraseHints: container.decodeFirstStringArray(for: [
                "phrase_hints",
                "phraseHints",
                "phrases",
                "key_phrases",
                "keyPhrases"
            ])
        )
    }
}

struct AICleanedPageImportParser {
    static func parse(
        _ text: String,
        sourcePageID: UUID,
        sourceTitle: String,
        createdAt: Date = Date()
    ) throws -> AICleanedPageRecord {
        var lastError: Error?
        for candidate in ConversationPracticeRules.importJSONCandidates(from: text) {
            guard let data = candidate.data(using: .utf8) else { continue }
            do {
                let payload = try JSONDecoder().decode(AICleanedPageImportPayload.self, from: data)
                let record = payload.record(
                    sourcePageID: sourcePageID,
                    sourceTitle: sourceTitle,
                    createdAt: createdAt
                )
                guard !record.cleanedChineseText.isEmpty || !record.sentences.isEmpty else {
                    throw DecodingError.dataCorrupted(.init(
                        codingPath: [],
                        debugDescription: "The extracted-sentences JSON is empty."
                    ))
                }
                return record
            } catch {
                lastError = error
            }

            do {
                let sentences = try JSONDecoder().decode([AICleanedPageSentence].self, from: data)
                let payload = AICleanedPageImportPayload(
                    cleanedTitle: sourceTitle,
                    cleanedChineseText: sentences.map(\.chinese).joined(separator: " "),
                    sentences: sentences,
                    englishSummary: nil,
                    repairNotes: ["Imported a top-level sentence array from the AI response."]
                )
                let record = payload.record(
                    sourcePageID: sourcePageID,
                    sourceTitle: sourceTitle,
                    createdAt: createdAt
                )
                guard !record.sentences.isEmpty else { continue }
                return record
            } catch {
                lastError = error
            }
        }
        if let lastError {
            throw lastError
        }
        throw DecodingError.dataCorrupted(.init(
            codingPath: [],
            debugDescription: "Paste extracted-sentences JSON with cleaned_chinese_text and sentences."
        ))
    }
}

private struct AICleanedPageImportPayload: Codable {
    var cleanedTitle: String
    var cleanedChineseText: String
    var sentences: [AICleanedPageSentence]
    var englishSummary: String?
    var repairNotes: [String]?

    enum CodingKeys: String, CodingKey {
        case cleanedTitle = "cleaned_title"
        case cleanedChineseText = "cleaned_chinese_text"
        case sentences
        case englishSummary = "english_summary"
        case repairNotes = "repair_notes"
    }

    init(
        cleanedTitle: String,
        cleanedChineseText: String,
        sentences: [AICleanedPageSentence],
        englishSummary: String?,
        repairNotes: [String]?
    ) {
        self.cleanedTitle = cleanedTitle
        self.cleanedChineseText = cleanedChineseText
        self.sentences = sentences
        self.englishSummary = englishSummary
        self.repairNotes = repairNotes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: FlexibleCodingKey.self)
        let nestedPage = try? container.nestedContainer(
            keyedBy: FlexibleCodingKey.self,
            forKey: FlexibleCodingKey("page")
        )
        let nestedResult = try? container.nestedContainer(
            keyedBy: FlexibleCodingKey.self,
            forKey: FlexibleCodingKey("result")
        )
        let nestedData = try? container.nestedContainer(
            keyedBy: FlexibleCodingKey.self,
            forKey: FlexibleCodingKey("data")
        )
        let containers = [container, nestedPage, nestedResult, nestedData].compactMap { $0 }

        cleanedTitle = containers.decodeFirstString(for: [
            "cleaned_title",
            "cleanedTitle",
            "title",
            "page_title",
            "pageTitle"
        ]) ?? ""
        cleanedChineseText = containers.decodeFirstString(for: [
            "cleaned_chinese_text",
            "cleanedChineseText",
            "cleaned_text",
            "cleanedText",
            "cleaned_chinese",
            "cleanedChinese",
            "prose",
            "text",
            "content"
        ]) ?? ""
        sentences = containers.decodeFirstSentenceArray(for: [
            "sentences",
            "sentence_records",
            "sentenceRecords",
            "sentence_list",
            "sentenceList",
            "items",
            "records"
        ])
        englishSummary = containers.decodeFirstString(for: [
            "english_summary",
            "englishSummary",
            "summary"
        ])
        repairNotes = containers.decodeFirstStringArray(for: [
            "repair_notes",
            "repairNotes",
            "notes"
        ])
    }

    func record(
        sourcePageID: UUID,
        sourceTitle: String,
        createdAt: Date
    ) -> AICleanedPageRecord {
        let normalizedSentences = normalizedSentences()
        let normalizedCleanedText = cleanedChineseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? normalizedSentences.map(\.chinese).joined(separator: " ")
            : cleanedChineseText
        return AICleanedPageRecord(
            sourcePageID: sourcePageID,
            sourceTitle: sourceTitle,
            cleanedTitle: cleanedTitle,
            cleanedChineseText: normalizedCleanedText,
            sentences: normalizedSentences,
            englishSummary: englishSummary,
            repairNotes: repairNotes ?? [],
            createdAt: createdAt
        )
    }

    private func normalizedSentences() -> [AICleanedPageSentence] {
        let sourceSentences = sentences.isEmpty
            ? SentenceExampleRecord.sentenceFragments(in: cleanedChineseText).enumerated().map { index, sentence in
                AICleanedPageSentence(
                    id: String(format: "ai_page_sentence_%03d", index + 1),
                    chinese: sentence
                )
            }
            : sentences
        return sourceSentences.enumerated().compactMap { index, sentence in
            let chinese = sentence.chinese.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !chinese.isEmpty else { return nil }
            let id = sentence.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? String(format: "ai_page_sentence_%03d", index + 1)
                : sentence.id
            return AICleanedPageSentence(
                id: id,
                chinese: chinese,
                pinyin: sentence.pinyin,
                english: sentence.english,
                phraseHints: sentence.phraseHints
            )
        }
    }
}

private struct FlexibleCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(_ stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

private extension KeyedDecodingContainer where Key == FlexibleCodingKey {
    func decodeFirstString(for keys: [String]) -> String? {
        for key in keys {
            guard contains(FlexibleCodingKey(key)) else { continue }
            if let value = try? decode(String.self, forKey: FlexibleCodingKey(key)) {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return nil
    }

    func decodeFirstStringArray(for keys: [String]) -> [String] {
        for key in keys {
            guard contains(FlexibleCodingKey(key)) else { continue }
            if let values = try? decode([String].self, forKey: FlexibleCodingKey(key)) {
                return values
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
            if let value = try? decode(String.self, forKey: FlexibleCodingKey(key)) {
                let pieces = value
                    .components(separatedBy: CharacterSet(charactersIn: ",，、;；\n"))
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                if !pieces.isEmpty { return pieces }
            }
        }
        return []
    }

    func decodeFirstSentenceArray(for keys: [String]) -> [AICleanedPageSentence] {
        for key in keys {
            guard contains(FlexibleCodingKey(key)) else { continue }
            if let values = try? decode([AICleanedPageSentence].self, forKey: FlexibleCodingKey(key)) {
                return values
            }
            if let strings = try? decode([String].self, forKey: FlexibleCodingKey(key)) {
                return strings.enumerated().map { index, chinese in
                    AICleanedPageSentence(
                        id: String(format: "ai_page_sentence_%03d", index + 1),
                        chinese: chinese
                    )
                }
            }
        }
        return []
    }
}

private extension Array where Element == KeyedDecodingContainer<FlexibleCodingKey> {
    func decodeFirstString(for keys: [String]) -> String? {
        for container in self {
            if let value = container.decodeFirstString(for: keys) {
                return value
            }
        }
        return nil
    }

    func decodeFirstStringArray(for keys: [String]) -> [String] {
        for container in self {
            let value = container.decodeFirstStringArray(for: keys)
            if !value.isEmpty { return value }
        }
        return []
    }

    func decodeFirstSentenceArray(for keys: [String]) -> [AICleanedPageSentence] {
        for container in self {
            let value = container.decodeFirstSentenceArray(for: keys)
            if !value.isEmpty { return value }
        }
        return []
    }
}

struct PageArtifactDescriptor: Codable, Equatable, Hashable, Identifiable {
    let id: String
    let sourcePageID: UUID
    let artifactType: PageArtifactType
    let artifactID: String
    let displayTitle: String
    let createdAt: Date?
    let ownership: PageArtifactOwnership

    init(
        sourcePageID: UUID,
        artifactType: PageArtifactType,
        artifactID: String,
        displayTitle: String,
        createdAt: Date? = nil,
        ownership: PageArtifactOwnership? = nil
    ) {
        self.sourcePageID = sourcePageID
        self.artifactType = artifactType
        self.artifactID = artifactID
        self.displayTitle = displayTitle
        self.createdAt = createdAt
        self.ownership = ownership ?? artifactType.defaultOwnership
        self.id = "\(sourcePageID.uuidString):\(artifactType.rawValue):\(artifactID)"
    }
}

struct PagePhraseExtractionRecord: Codable, Equatable, Hashable, Identifiable {
    let sourcePageID: UUID
    var sourceTitle: String
    var phraseWords: [String]
    var extractedAt: Date

    var id: UUID { sourcePageID }

    enum CodingKeys: String, CodingKey {
        case sourcePageID = "source_page_id"
        case sourceTitle = "source_title"
        case phraseWords = "phrase_words"
        case extractedAt = "extracted_at"
    }

    init(
        sourcePageID: UUID,
        sourceTitle: String,
        phraseWords: [String],
        extractedAt: Date
    ) {
        self.sourcePageID = sourcePageID
        self.sourceTitle = sourceTitle
        self.phraseWords = Self.deduplicated(phraseWords)
        self.extractedAt = extractedAt
    }

    func merging(words newWords: [String], title: String, extractedAt date: Date) -> PagePhraseExtractionRecord {
        PagePhraseExtractionRecord(
            sourcePageID: sourcePageID,
            sourceTitle: title,
            phraseWords: Self.deduplicated(phraseWords + newWords),
            extractedAt: date
        )
    }

    static func deduplicated(_ words: [String]) -> [String] {
        var seen = Set<String>()
        return words
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0).inserted }
    }
}
