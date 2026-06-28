import Foundation

public enum ConversationPracticeDifficulty: String, Codable, CaseIterable {
    case easy
    case medium
    case hard

    init(level: String, numericDifficulty: Int) {
        let normalizedLevel = level.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalizedLevel {
        case "advanced", "hard":
            self = .hard
        case "intermediate", "medium":
            self = .medium
        default:
            if numericDifficulty >= 4 {
                self = .hard
            } else if numericDifficulty >= 3 {
                self = .medium
            } else {
                self = .easy
            }
        }
    }
}

public struct ConversationPracticePack: Codable, Equatable {
    public let packID: String
    public let version: String
    public let title: String
    public let description: String
    public let language: String
    public let sourceType: String
    public let createdFor: String
    public let entries: [ConversationPracticeEntry]

    enum CodingKeys: String, CodingKey {
        case packID = "pack_id"
        case version
        case title
        case description
        case language
        case sourceType = "source_type"
        case createdFor = "created_for"
        case entries
    }

    public var practiceSet: ConversationPracticeSet {
        ConversationPracticeSet(
            id: packID,
            title: title,
            description: description,
            language: language,
            itemCount: entries.count
        )
    }

    public var practiceItems: [ConversationPracticeItem] {
        entries.sorted { $0.sequence < $1.sequence }.map {
            ConversationPracticeItem(entry: $0, setID: packID)
        }
    }

    public var practiceLibrary: ConversationPracticeLibrary {
        let items = practiceItems
        return ConversationPracticeLibrary(
            set: practiceSet,
            items: items,
            phraseSeeds: items.map(ConversationPracticePhraseSeed.init),
            memberships: items.map(ConversationPracticeMembership.init)
        )
    }
}

public struct ConversationPracticeEntry: Codable, Equatable, Identifiable {
    public let id: String
    public let sequence: Int
    public let category: String
    public let level: String
    public let sentence: ConversationPracticeSentence
    public let analysis: ConversationPracticeAnalysis
    public let metadata: ConversationPracticeMetadata
    public let notes: String
}

public struct ConversationPracticeSentence: Codable, Equatable {
    public let zh: String
    public let pinyin: String
    public let en: String
}

public struct ConversationPracticeAnalysis: Codable, Equatable {
    public let characters: [String]
    public let phrases: [String]
}

public struct ConversationPracticeMetadata: Codable, Equatable {
    public let difficulty: Int
    public let frequency: Int
    public let tags: [String]
}

public struct ConversationPracticeSet: Equatable, Identifiable {
    public let id: String
    public let title: String
    public let description: String
    public let language: String
    public let itemCount: Int
}

public struct ConversationPracticeItem: Equatable, Identifiable {
    public let id: String
    public let setID: String
    public let phraseKey: String
    public let rank: Int
    public let simplified: String
    public let pinyin: String
    public let english: String
    public let category: String
    public let difficulty: ConversationPracticeDifficulty
    public let tags: [String]
    public let characterHints: [String]
    public let phraseHints: [String]
    public let notes: String

    init(entry: ConversationPracticeEntry, setID: String) {
        id = entry.id
        self.setID = setID
        phraseKey = ConversationPracticeRules.phraseKey(for: entry.sentence.zh)
        rank = entry.sequence
        simplified = entry.sentence.zh
        pinyin = entry.sentence.pinyin
        english = entry.sentence.en
        category = entry.category
        difficulty = ConversationPracticeDifficulty(
            level: entry.level,
            numericDifficulty: entry.metadata.difficulty
        )
        tags = entry.metadata.tags
        characterHints = entry.analysis.characters
        phraseHints = entry.analysis.phrases
        notes = entry.notes
    }
}

public struct ConversationPracticePhraseSeed: Equatable, Identifiable {
    public let id: String
    public let phraseKey: String
    public let simplified: String
    public let pinyin: String
    public let english: String
    public let notes: String
    public let sourceItemID: String

    init(item: ConversationPracticeItem) {
        id = item.phraseKey
        phraseKey = item.phraseKey
        simplified = item.simplified
        pinyin = item.pinyin
        english = item.english
        notes = item.notes
        sourceItemID = item.id
    }
}

public struct ConversationPracticeMembership: Equatable, Identifiable {
    public let id: String
    public let setID: String
    public let itemID: String
    public let phraseKey: String
    public let rank: Int
    public let category: String
    public let difficulty: ConversationPracticeDifficulty
    public let tags: [String]

    init(item: ConversationPracticeItem) {
        id = "\(item.setID)#\(item.id)"
        setID = item.setID
        itemID = item.id
        phraseKey = item.phraseKey
        rank = item.rank
        category = item.category
        difficulty = item.difficulty
        tags = item.tags
    }
}

public struct ConversationPracticeLibrary: Equatable {
    public let set: ConversationPracticeSet
    public let items: [ConversationPracticeItem]
    public let phraseSeeds: [ConversationPracticePhraseSeed]
    public let memberships: [ConversationPracticeMembership]

    public var phraseKeys: [String] {
        memberships.map(\.phraseKey)
    }
}

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

public enum ConversationPracticeRules {
    public static let supportedLanguages: Set<String> = ["zh-Hans"]

    public static func phraseKey(for sentence: String) -> String {
        sentence.trimmingCharacters(in: .whitespacesAndNewlinesAndPunctuation)
    }

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

    private static func normalizedText(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isChineseCharacter(_ character: Character) -> Bool {
        character.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(Int(scalar.value))
        }
    }
}

public enum ConversationPracticeQuizRules {
    public static func choices(
        for item: ConversationPracticeItem,
        in items: [ConversationPracticeItem],
        count: Int = 4
    ) -> [ConversationPracticeItem] {
        guard let itemIndex = items.firstIndex(where: { $0.id == item.id }) else {
            return [item]
        }

        let distractors = (1..<items.count)
            .map { items[(itemIndex + ($0 * 7)) % items.count] }
            .filter { $0.id != item.id }
            .prefix(max(0, count - 1))

        let ordered = [item] + Array(distractors)
        return ordered.sorted {
            stableOrderKey($0.id, itemID: item.id) < stableOrderKey($1.id, itemID: item.id)
        }
    }

    private static func stableOrderKey(_ id: String, itemID: String) -> Int {
        let combined = "\(itemID)#\(id)"
        return combined.unicodeScalars.reduce(0) { partial, scalar in
            ((partial * 31) + Int(scalar.value)) % 997
        }
    }
}

private extension CharacterSet {
    static let whitespacesAndNewlinesAndPunctuation = CharacterSet.whitespacesAndNewlines
        .union(.punctuationCharacters)
        .union(CharacterSet(charactersIn: "。！？；，、"))
}
