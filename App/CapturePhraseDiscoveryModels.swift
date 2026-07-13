import Foundation

struct PhraseDiscoveryCandidate: Identifiable, Hashable {
    let id = UUID()
    var phrase: String
    var pinyin: String
    var meaning: String
    var isSelected = true
}

struct PhraseDiscoveryPreparedCandidate {
    var candidate: PhraseDiscoveryCandidate
    var phrase: String
}

struct PhraseDiscoveryImportPreparation {
    var candidates: [PhraseDiscoveryPreparedCandidate]
    var skippedCount: Int
}

struct PhraseDiscoveryImportSummary {
    var selectedCount: Int
    var addedCount: Int
    var addedWords: [String] = []
    var skippedCount: Int
    var skippedExistingCount: Int = 0
    var errors: [String]

    func message(defaultAIName: String) -> String {
        if selectedCount == 0 {
            return "No new phrases were found in the \(defaultAIName) answer."
        }
        if addedCount == 0 {
            if skippedExistingCount >= selectedCount && errors.isEmpty {
                return "No phrases were added because every extracted phrase is already in your phrase library."
            }
            return "Radix read \(selectedCount) phrase\(selectedCount == 1 ? "" : "s"), but none were added to My Phrases.\(skippedSuffix)\(errorSuffix)"
        }
        return "Added \(addedCount) to My Phrases.\(skippedSuffix)\(errorSuffix)"
    }

    private var skippedSuffix: String {
        let invalidOrDuplicateCount = skippedCount - skippedExistingCount
        var parts: [String] = []
        if skippedExistingCount > 0 {
            parts.append("\(skippedExistingCount) already in your phrase library")
        }
        if invalidOrDuplicateCount > 0 {
            parts.append("\(invalidOrDuplicateCount) duplicate or invalid")
        }
        return parts.isEmpty ? "" : " Skipped \(parts.joined(separator: ", "))."
    }

    private var errorSuffix: String {
        errors.isEmpty ? "" : " Errors: \(errors.joined(separator: "; "))"
    }
}

struct PhraseDiscoveryParseResult {
    var candidates: [PhraseDiscoveryCandidate]
    var totalParsed: Int
    var duplicatesRemoved: Int
    var invalidLines: Int
}
