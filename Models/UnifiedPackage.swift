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
    let dictionary: [String: RawComponentEntry]?
    let dictionaryOverlay: DictionaryOverlayPackage?
    let phrases: [PhraseItem]
    let profile: UserProfile

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case dictionary
        case dictionaryOverlay = "dictionary_overlay"
        case phrases
        case profile
    }
}
