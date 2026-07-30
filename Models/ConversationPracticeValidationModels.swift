import Foundation

public struct ConversationPracticeValidationIssue: Equatable, Sendable, CustomStringConvertible {
    public enum Severity: String, Equatable, Sendable {
        case error
        case warning
    }

    public let severity: Severity
    public let entryID: String?
    public let message: String

    public var description: String {
        if let entryID {
            return "[\(severity.rawValue)] \(entryID): \(message)"
        }
        return "[\(severity.rawValue)] \(message)"
    }
}

public struct ConversationPracticeValidationResult: Equatable {
    public let issues: [ConversationPracticeValidationIssue]

    public var errors: [ConversationPracticeValidationIssue] {
        issues.filter { $0.severity == .error }
    }

    public var warnings: [ConversationPracticeValidationIssue] {
        issues.filter { $0.severity == .warning }
    }

    public var isValid: Bool {
        errors.isEmpty
    }
}

extension ConversationPracticeRules {
    public static let supportedLanguages: Set<String> = ["zh-Hans"]

    public static func validate(_ pack: ConversationPracticePack) -> ConversationPracticeValidationResult {
        var issues: [ConversationPracticeValidationIssue] = []

        appendRequiredPackIssue(pack.packID, field: "pack_id", to: &issues)
        appendRequiredPackIssue(pack.title, field: "title", to: &issues)

        if !supportedLanguages.contains(pack.language) {
            issues.append(issue("Unsupported language '\(pack.language)'.", severity: .error))
        }

        if pack.entries.isEmpty {
            issues.append(issue("Conversation practice pack has no entries.", severity: .error))
        }

        let sequences = pack.entries.map(\.sequence)
        appendDuplicateIssues(values: pack.entries.map(\.id), label: "entry id", to: &issues)
        appendDuplicateIssues(values: pack.entries.map { phraseKey(for: $0.sentence.zh) }, label: "Chinese sentence", to: &issues)
        appendDuplicateIssues(values: sequences.map(String.init), label: "sequence", to: &issues)
        appendDuplicateIssues(values: pack.practiceItems.map(\.phraseKey), label: "phrase key", to: &issues)

        let sortedSequences = sequences.sorted()
        if let first = sortedSequences.first, let last = sortedSequences.last {
            let expected = Array(first...last)
            if sortedSequences != expected {
                issues.append(issue("Entry sequences must be contiguous.", severity: .error))
            }
        }

        for entry in pack.entries {
            validate(entry, issues: &issues)
        }

        return ConversationPracticeValidationResult(issues: issues)
    }

    private static func validate(
        _ entry: ConversationPracticeEntry,
        issues: inout [ConversationPracticeValidationIssue]
    ) {
        appendRequiredEntryIssue(entry.id, field: "id", entryID: entry.id, to: &issues)
        if entry.sequence <= 0 {
            issues.append(issue("Sequence must be greater than zero.", entryID: entry.id, severity: .error))
        }
        appendRequiredEntryIssue(entry.category, field: "category", entryID: entry.id, to: &issues)
        appendRequiredEntryIssue(entry.level, field: "level", entryID: entry.id, to: &issues)
        appendRequiredEntryIssue(entry.sentence.zh, field: "sentence.zh", entryID: entry.id, to: &issues)
        appendRequiredEntryIssue(entry.sentence.pinyin, field: "sentence.pinyin", entryID: entry.id, to: &issues)
        appendRequiredEntryIssue(entry.sentence.en, field: "sentence.en", entryID: entry.id, to: &issues)

        let characters = Array(entry.sentence.zh.filter { isChineseCharacter($0) }).map(String.init)
        let uniqueHints = Set(entry.analysis.characters)
        for character in characters where !uniqueHints.contains(character) {
            issues.append(issue(
                "Character hint is missing '\(character)'.",
                entryID: entry.id,
                severity: .warning
            ))
        }

        if !entry.analysis.phrases.contains(entry.sentence.zh.trimmingCharacters(in: .whitespacesAndNewlinesAndPunctuation)) {
            issues.append(issue(
                "Phrase hints should include the full sentence without punctuation.",
                entryID: entry.id,
                severity: .warning
            ))
        }

        if entry.metadata.difficulty < 1 {
            issues.append(issue("Difficulty must be at least 1.", entryID: entry.id, severity: .error))
        }
        if entry.metadata.frequency < 1 {
            issues.append(issue("Frequency must be at least 1.", entryID: entry.id, severity: .warning))
        }
        if entry.metadata.tags.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            issues.append(issue("Tags must not be empty.", entryID: entry.id, severity: .error))
        }
    }

    private static func appendRequiredPackIssue(
        _ value: String,
        field: String,
        to issues: inout [ConversationPracticeValidationIssue]
    ) {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(issue("Missing required field '\(field)'.", severity: .error))
        }
    }

    private static func appendRequiredEntryIssue(
        _ value: String,
        field: String,
        entryID: String,
        to issues: inout [ConversationPracticeValidationIssue]
    ) {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(issue("Missing required field '\(field)'.", entryID: entryID, severity: .error))
        }
    }

    private static func appendDuplicateIssues(
        values: [String],
        label: String,
        to issues: inout [ConversationPracticeValidationIssue]
    ) {
        let duplicates = Dictionary(grouping: values, by: { $0 })
            .filter { !$0.key.isEmpty && $0.value.count > 1 }
            .keys
            .sorted()

        for duplicate in duplicates {
            issues.append(issue("Duplicate \(label): \(duplicate)", severity: .error))
        }
    }

    private static func issue(
        _ message: String,
        entryID: String? = nil,
        severity: ConversationPracticeValidationIssue.Severity
    ) -> ConversationPracticeValidationIssue {
        ConversationPracticeValidationIssue(
            severity: severity,
            entryID: entryID,
            message: message
        )
    }
}
