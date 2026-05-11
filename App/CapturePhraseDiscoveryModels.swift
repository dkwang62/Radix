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
    var skippedCount: Int
    var skippedExistingCount: Int = 0
    var errors: [String]

    func message(defaultAIName: String) -> String {
        if selectedCount == 0 {
            return "No new phrases were found in the \(defaultAIName) answer."
        }
        if addedCount == 0 {
            return "Radix read \(selectedCount) phrase\(selectedCount == 1 ? "" : "s"), but none were added to My Phrases.\(skippedSuffix)\(errorSuffix)"
        }
        return "Added \(addedCount) to My Phrases. Delete any phrase below that you do not want to keep.\(skippedSuffix)\(errorSuffix)"
    }

    private var skippedSuffix: String {
        let invalidOrDuplicateCount = skippedCount - skippedExistingCount
        var parts: [String] = []
        if skippedExistingCount > 0 {
            parts.append("\(skippedExistingCount) already in the phrase database")
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

struct PhraseDiscoveryStats {
    var totalParsed = 0
    var duplicatesRemoved = 0
    var alreadyExisting = 0
    var invalidLines = 0
}

struct PhraseDiscoveryReadResult {
    var candidates: [PhraseDiscoveryCandidate]
    var stats: PhraseDiscoveryStats
}

struct PhraseDiscoveryParseResult {
    var candidates: [PhraseDiscoveryCandidate]
    var totalParsed: Int
    var duplicatesRemoved: Int
    var invalidLines: Int
}
