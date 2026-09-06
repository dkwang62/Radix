import Foundation

struct DictionaryOverlayPackage: Codable, Equatable {
    let schemaVersion: Int
    let upserts: [String: RawComponentEntry]
    let deletions: [String]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case upserts
        case deletions
    }
}

struct DictionaryEntryPatch: Codable, Equatable {
    let character: String
    let relatedCharacters: [String]?
    let meta: RawMetaPatch
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case character
        case relatedCharacters = "related_characters"
        case meta
        case updatedAt = "updated_at"
    }
}

struct RawMetaPatch: Codable, Equatable {
    let variant: String?
    let additionalVariants: [String]?
    let pinyin: StringOrMany?
    let definition: String?
    let decomposition: String?
    let idc: String?
    let radical: String?
    let strokes: IntOrString?
    let compounds: StringOrMany?
    let etymology: RawEtymology?
    let notes: StringOrMany?

    enum CodingKeys: String, CodingKey {
        case variant, pinyin, definition, decomposition, radical, strokes, compounds, etymology, notes
        case additionalVariants = "additional_variants"
        case idc = "IDC"
    }

    var isEmpty: Bool {
        variant == nil &&
        additionalVariants == nil &&
        pinyin == nil &&
        definition == nil &&
        decomposition == nil &&
        idc == nil &&
        radical == nil &&
        strokes == nil &&
        compounds == nil &&
        etymology == nil &&
        notes == nil
    }
}

struct DictionaryOverlayPatchPackage: Codable, Equatable {
    let schemaVersion: Int
    let customEntries: [String: RawComponentEntry]
    let patches: [DictionaryEntryPatch]
    let deletions: [String]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case customEntries = "custom_entries"
        case patches
        case deletions
    }
}

struct FullDatasetExportPackage: Codable {
    let schemaVersion: Int
    let exportedAt: Date
    let dictionary: [String: RawComponentEntry]
    let phrases: [PhraseItem]
    let portableBackup: UnifiedPackage

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case exportedAt = "exported_at"
        case dictionary
        case phrases
        case portableBackup = "portable_backup"
    }
}

struct APIKeyBackup: Codable, Equatable {
    let openAI: String
    let gemini: String
    let claude: String
    let deepSeek: String
    let custom: String

    enum CodingKeys: String, CodingKey {
        case openAI = "open_ai"
        case gemini
        case claude
        case deepSeek = "deep_seek"
        case custom
    }

    var savedCount: Int {
        [openAI, gemini, claude, deepSeek, custom]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .count
    }
}

struct ExtractedSentenceReferencePackage: Codable, Equatable {
    let schemaVersion: Int
    let sentenceDatabaseFingerprint: SentenceDatabasePointerFingerprint?
    let pages: [ExtractedSentencePageReference]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case sentenceDatabaseFingerprint = "sentence_database_fingerprint"
        case pages
    }

    init(
        schemaVersion: Int = 1,
        sentenceDatabaseFingerprint: SentenceDatabasePointerFingerprint?,
        pages: [ExtractedSentencePageReference]
    ) {
        self.schemaVersion = schemaVersion
        self.sentenceDatabaseFingerprint = sentenceDatabaseFingerprint
        self.pages = pages
    }
}

enum ExtractedSentenceRestoreError: LocalizedError, Equatable {
    case unresolvedSentence(pageID: UUID, sentenceID: String)
    case emptyPage(pageID: UUID)

    var errorDescription: String? {
        switch self {
        case .unresolvedSentence:
            return "The backup contains an extracted-page sentence that is missing from its sentence database. Nothing was restored."
        case .emptyPage:
            return "The backup contains an extracted page with no sentence references. Nothing was restored."
        }
    }
}

enum ExtractedSentenceRestoreRules {
    static let pointerSchemaVersion = 6

    static func resolvedPages(
        from package: ExtractedSentenceReferencePackage?,
        sourceSchemaVersion: Int,
        mode: RestoreMode,
        sentenceForPointer: (ExtractedSentencePointer) -> SentenceExampleRecord?
    ) throws -> [AICleanedPageRecord]? {
        let shouldApply: Bool
        if let package, !package.pages.isEmpty {
            shouldApply = true
        } else {
            shouldApply = mode == .complete && (package != nil || sourceSchemaVersion >= pointerSchemaVersion)
        }
        guard shouldApply else { return nil }

        return try (package?.pages ?? []).map { reference in
            let pointers = reference.sentenceReferences.sorted { lhs, rhs in
                if lhs.ordinal != rhs.ordinal { return lhs.ordinal < rhs.ordinal }
                return lhs.pageSentenceID < rhs.pageSentenceID
            }
            guard !pointers.isEmpty else {
                throw ExtractedSentenceRestoreError.emptyPage(pageID: reference.sourcePageID)
            }

            let sentences = try pointers.map { pointer -> AICleanedPageSentence in
                guard let record = sentenceForPointer(pointer) else {
                    throw ExtractedSentenceRestoreError.unresolvedSentence(
                        pageID: reference.sourcePageID,
                        sentenceID: pointer.pageSentenceID
                    )
                }
                let phraseHints = record.targetPhrases.isEmpty ? record.detectedPhrases : record.targetPhrases
                return AICleanedPageSentence(
                    id: pointer.pageSentenceID,
                    chinese: record.chinese,
                    pinyin: record.pinyin,
                    english: record.english,
                    phraseHints: phraseHints
                )
            }

            return AICleanedPageRecord(
                sourcePageID: reference.sourcePageID,
                sourceTitle: reference.sourceTitle,
                cleanedTitle: reference.cleanedTitle,
                cleanedChineseText: sentences.map(\.chinese).joined(separator: " "),
                sentences: sentences,
                createdAt: reference.createdAt
            )
        }
    }
}

struct SentenceDatabasePointerFingerprint: Codable, Equatable {
    let sentenceCount: Int
    let latestCreatedAt: TimeInterval
    let latestUpdatedAt: TimeInterval
    let normalizedKeyHash: String

    enum CodingKeys: String, CodingKey {
        case sentenceCount = "sentence_count"
        case latestCreatedAt = "latest_created_at"
        case latestUpdatedAt = "latest_updated_at"
        case normalizedKeyHash = "normalized_key_hash"
    }
}

struct ExtractedSentencePageReference: Codable, Equatable, Identifiable {
    let sourcePageID: UUID
    let sourceTitle: String
    let cleanedTitle: String
    let sentenceReferences: [ExtractedSentencePointer]
    let createdAt: Date

    var id: UUID { sourcePageID }

    enum CodingKeys: String, CodingKey {
        case sourcePageID = "source_page_id"
        case sourceTitle = "source_title"
        case cleanedTitle = "cleaned_title"
        case sentenceReferences = "sentence_references"
        case createdAt = "created_at"
    }
}

struct ExtractedSentencePointer: Codable, Equatable {
    let pageSentenceID: String
    let sentenceExampleID: UUID
    let sentenceKey: String
    let ordinal: Int

    enum CodingKeys: String, CodingKey {
        case pageSentenceID = "page_sentence_id"
        case sentenceExampleID = "sentence_example_id"
        case sentenceKey = "sentence_key"
        case ordinal
    }
}

enum APIKeyRetentionPolicy {
    static func resolvedGeminiKey(
        current: String,
        retainedLatest: String?,
        imported: String?
    ) -> String {
        let current = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !current.isEmpty { return current }

        let retainedLatest = retainedLatest?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !retainedLatest.isEmpty { return retainedLatest }

        return imported?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

/// A unified package containing all user-editable data across dictionary, phrases, and settings.
struct UnifiedPackage: Codable {
    let schemaVersion: Int
    let exportedAt: Date?
    let backupID: UUID?
    let baseDictionaryFingerprint: String?
    let dictionary: [String: RawComponentEntry]?
    let dictionaryOverlay: DictionaryOverlayPackage?
    let dictionaryPatchOverlay: DictionaryOverlayPatchPackage?
    let phrases: [PhraseItem]
    let profile: UserProfile
    let collections: [CharacterCollection]?
    let selectedAICollectionID: UUID?
    let conversationPracticePacks: [ConversationPracticePack]?
    let conversationPracticeProgress: ConversationPracticeProgressSnapshot?
    let favoriteSentences: [FavoriteSentenceRecord]?
    let sentenceExamples: [SentenceExampleRecord]?
    let pagePhraseExtractions: [PagePhraseExtractionRecord]?
    let aiCleanedPages: [AICleanedPageRecord]?
    let extractedSentencePageReferences: ExtractedSentenceReferencePackage?
    let apiKeys: APIKeyBackup?

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case exportedAt = "exported_at"
        case backupID = "backup_id"
        case baseDictionaryFingerprint = "base_dictionary_fingerprint"
        case dictionary
        case dictionaryOverlay = "dictionary_overlay"
        case dictionaryPatchOverlay = "dictionary_patch_overlay"
        case phrases
        case profile
        case collections
        case selectedAICollectionID = "selected_ai_collection_id"
        case conversationPracticePacks = "conversation_practice_packs"
        case conversationPracticeProgress = "conversation_practice_progress"
        case favoriteSentences = "favorite_sentences"
        case sentenceExamples = "sentence_examples"
        case pagePhraseExtractions = "page_phrase_extractions"
        case aiCleanedPages = "ai_cleaned_pages"
        case extractedSentencePageReferences = "extracted_sentence_page_references"
        case apiKeys = "api_keys"
    }

    init(
        schemaVersion: Int,
        exportedAt: Date? = nil,
        backupID: UUID? = nil,
        baseDictionaryFingerprint: String? = nil,
        dictionary: [String: RawComponentEntry]? = nil,
        dictionaryOverlay: DictionaryOverlayPackage? = nil,
        dictionaryPatchOverlay: DictionaryOverlayPatchPackage? = nil,
        phrases: [PhraseItem],
        profile: UserProfile,
        collections: [CharacterCollection]? = nil,
        selectedAICollectionID: UUID? = nil,
        conversationPracticePacks: [ConversationPracticePack]? = nil,
        conversationPracticeProgress: ConversationPracticeProgressSnapshot? = nil,
        favoriteSentences: [FavoriteSentenceRecord]? = nil,
        sentenceExamples: [SentenceExampleRecord]? = nil,
        pagePhraseExtractions: [PagePhraseExtractionRecord]? = nil,
        aiCleanedPages: [AICleanedPageRecord]? = nil,
        extractedSentencePageReferences: ExtractedSentenceReferencePackage? = nil,
        apiKeys: APIKeyBackup? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.backupID = backupID
        self.baseDictionaryFingerprint = baseDictionaryFingerprint
        self.dictionary = dictionary
        self.dictionaryOverlay = dictionaryOverlay
        self.dictionaryPatchOverlay = dictionaryPatchOverlay
        self.phrases = phrases
        self.profile = profile
        self.collections = collections
        self.selectedAICollectionID = selectedAICollectionID
        self.conversationPracticePacks = conversationPracticePacks
        self.conversationPracticeProgress = conversationPracticeProgress
        self.favoriteSentences = favoriteSentences
        self.sentenceExamples = sentenceExamples
        self.pagePhraseExtractions = pagePhraseExtractions
        self.aiCleanedPages = aiCleanedPages
        self.extractedSentencePageReferences = extractedSentencePageReferences
        self.apiKeys = apiKeys
    }
}

struct SentenceLibraryExportPackage: Codable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let exportedAt: Date
    let sentenceExamples: [SentenceExampleRecord]
    let favoriteSentences: [FavoriteSentenceRecord]
    let aiCleanedPages: [AICleanedPageRecord]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case exportedAt = "exported_at"
        case sentenceExamples = "sentence_examples"
        case favoriteSentences = "favorite_sentences"
        case aiCleanedPages = "ai_cleaned_pages"
    }

    init(
        schemaVersion: Int = Self.currentSchemaVersion,
        exportedAt: Date = Date(),
        sentenceExamples: [SentenceExampleRecord],
        favoriteSentences: [FavoriteSentenceRecord] = [],
        aiCleanedPages: [AICleanedPageRecord]
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.sentenceExamples = sentenceExamples
        self.favoriteSentences = favoriteSentences
        self.aiCleanedPages = aiCleanedPages
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion
        exportedAt = try container.decodeIfPresent(Date.self, forKey: .exportedAt) ?? Date()
        sentenceExamples = try container.decodeIfPresent([SentenceExampleRecord].self, forKey: .sentenceExamples) ?? []
        favoriteSentences = try container.decodeIfPresent([FavoriteSentenceRecord].self, forKey: .favoriteSentences) ?? []
        aiCleanedPages = try container.decodeIfPresent([AICleanedPageRecord].self, forKey: .aiCleanedPages) ?? []
    }
}

struct SentenceLibraryImportResult {
    let sentenceCount: Int
    let extractedPageCount: Int
}

/// Platform-neutral JSON contract shared by every Radix client.
///
/// Schema 5 writes ISO-8601 dates so an Android implementation does not need
/// to understand Apple's 2001 reference-date epoch. The decoder deliberately
/// retains support for schema 1–4 backups that used numeric Apple timestamps.
///
/// Schema 6 adds pointer-only extracted-sentence page references. Full sentence
/// rows continue to live in the sentence database export/snapshot.
struct PortableBackupCodec {
    static let currentSchemaVersion = 6
    static let maximumBackupBytes = 250 * 1_024 * 1_024

    func encode(_ package: UnifiedPackage) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(package)
    }

    func decode(_ data: Data) throws -> PortableBackupPayload {
        guard !data.isEmpty else { throw PortableBackupCodecError.empty }
        guard data.count <= Self.maximumBackupBytes else { throw PortableBackupCodecError.tooLarge }

        if let package = decodeUnifiedPackage(data) {
            guard (1...Self.currentSchemaVersion).contains(package.schemaVersion) else {
                throw PortableBackupCodecError.unsupportedVersion(package.schemaVersion)
            }
            try validate(.unified(package))
            return .unified(package)
        }

        if let legacyDictionary = try? JSONDecoder().decode([String: RawComponentEntry].self, from: data) {
            return .legacyDictionary(legacyDictionary)
        }

        throw PortableBackupCodecError.invalidDocument
    }

    func validate(_ payload: PortableBackupPayload) throws {
        guard case .unified(let package) = payload,
              let duplicateID = CharacterCollectionIdentityRules.firstDuplicateID(in: package.collections ?? [])
        else { return }
        throw PortableBackupCodecError.duplicateCollectionID(duplicateID)
    }

    private func decodeUnifiedPackage(_ data: Data) -> UnifiedPackage? {
        let portableDecoder = JSONDecoder()
        portableDecoder.dateDecodingStrategy = .iso8601
        if let package = try? portableDecoder.decode(UnifiedPackage.self, from: data) {
            return package
        }

        // Backward compatibility for schema 1–4, whose dates were encoded as
        // seconds from Apple's 2001-01-01 reference date.
        return try? JSONDecoder().decode(UnifiedPackage.self, from: data)
    }
}

enum PortableBackupPayload {
    case unified(UnifiedPackage)
    case legacyDictionary([String: RawComponentEntry])
}

enum PortableBackupCodecError: LocalizedError {
    case empty
    case tooLarge
    case unsupportedVersion(Int)
    case duplicateCollectionID(UUID)
    case invalidDocument

    var errorDescription: String? {
        switch self {
        case .empty:
            return "The selected backup is empty."
        case .tooLarge:
            return "This backup is too large to restore safely."
        case .unsupportedVersion(let version):
            return "This backup uses format version \(version). Update Radix on this device before restoring it."
        case .duplicateCollectionID(let id):
            return "This backup contains more than one saved page with the identifier \(id.uuidString). It was not restored because those pages cannot be matched safely."
        case .invalidDocument:
            return "This file is not a compatible Radix backup. Choose a JSON backup created by Radix on iPhone, iPad, or Mac."
        }
    }
}
