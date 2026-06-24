import Foundation

/// Script-selection values persisted in portable user profiles.
enum ScriptFilter: String, CaseIterable, Identifiable, Codable, Sendable {
    case any = "Any"
    case simplified = "Simplified"
    case traditional = "Traditional"

    var id: String { rawValue }
}

/// Defines whether imported user data is merged or replaces local data.
/// These values are platform-neutral so Apple and Android restore flows can
/// share the same behavior and terminology.
enum RestoreMode: String, CaseIterable, Codable, Sendable {
    case additive
    case complete
}
