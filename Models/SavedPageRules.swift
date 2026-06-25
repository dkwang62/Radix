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

    private static func effectiveDate(_ page: CharacterCollection) -> Date {
        page.lastViewedAt ?? page.createdAt
    }
}
