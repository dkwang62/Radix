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
        profile: UserProfile
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
    }
}
