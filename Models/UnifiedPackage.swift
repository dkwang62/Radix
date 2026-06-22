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

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case exportedAt = "exported_at"
        case dictionary
        case phrases
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
        self.apiKeys = apiKeys
    }
}

/// Platform-neutral JSON contract shared by every Radix client.
///
/// Schema 5 writes ISO-8601 dates so an Android implementation does not need
/// to understand Apple's 2001 reference-date epoch. The decoder deliberately
/// retains support for schema 1–4 backups that used numeric Apple timestamps.
struct PortableBackupCodec {
    static let currentSchemaVersion = 5
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
            return .unified(package)
        }

        if let legacyDictionary = try? JSONDecoder().decode([String: RawComponentEntry].self, from: data) {
            return .legacyDictionary(legacyDictionary)
        }

        throw PortableBackupCodecError.invalidDocument
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
    case invalidDocument

    var errorDescription: String? {
        switch self {
        case .empty:
            return "The selected backup is empty."
        case .tooLarge:
            return "This backup is too large to restore safely."
        case .unsupportedVersion(let version):
            return "This backup uses format version \(version). Update Radix on this device before restoring it."
        case .invalidDocument:
            return "This file is not a compatible Radix backup. Choose a JSON backup created by Radix on iPhone, iPad, or Mac."
        }
    }
}
