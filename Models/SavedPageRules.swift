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
        case .correctedOCRPage,
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
