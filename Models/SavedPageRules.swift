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
            displayTitle: cleanedTitle.isEmpty ? "AI-cleaned page" : cleanedTitle,
            createdAt: createdAt
        )
    }
}

struct AICleanedPageSentence: Codable, Equatable, Hashable, Identifiable {
    var id: String
    var chinese: String
    var english: String?
    var phraseHints: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case chinese
        case english
        case phraseHints = "phrase_hints"
    }

    init(
        id: String,
        chinese: String,
        english: String? = nil,
        phraseHints: [String] = []
    ) {
        self.id = id.trimmingCharacters(in: .whitespacesAndNewlines)
        self.chinese = chinese.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEnglish = english?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.english = cleanEnglish?.isEmpty == true ? nil : cleanEnglish
        self.phraseHints = phraseHints
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
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
