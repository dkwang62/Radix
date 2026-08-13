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

/// Rolling save-history filenames used before Radix updates an existing
/// portable file. The active file keeps its name and older copies sit beside it.
enum RollingSaveHistoryRules {
    static let retainedVersionCount = 3

    static func retainedVersionURL(for url: URL, slot: Int) -> URL {
        precondition(slot >= 1)
        let directory = url.deletingLastPathComponent()
        let pathExtension = url.pathExtension
        let baseName = pathExtension.isEmpty
            ? url.lastPathComponent
            : url.deletingPathExtension().lastPathComponent
        let retainedName = pathExtension.isEmpty
            ? "\(baseName).bk\(slot)"
            : "\(baseName).bk\(slot).\(pathExtension)"
        return directory.appendingPathComponent(retainedName)
    }

    static func retainedVersionURLs(for url: URL) -> [URL] {
        (1...retainedVersionCount).map { retainedVersionURL(for: url, slot: $0) }
    }
}
