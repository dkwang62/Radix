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
    private static let defaultSourceType = "conversation_pack"
    private static let defaultCreatedFor = "Radix Conversation Practice"

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

    enum ImportedCodingKeys: String, CodingKey {
        case theme
        case entries
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let decodedPackID = try container.decodeIfPresent(String.self, forKey: .packID) {
            packID = decodedPackID
            version = try container.decode(String.self, forKey: .version)
            title = try container.decode(String.self, forKey: .title)
            description = try container.decode(String.self, forKey: .description)
            language = try container.decode(String.self, forKey: .language)
            sourceType = try container.decodeIfPresent(String.self, forKey: .sourceType) ?? Self.defaultSourceType
            createdFor = try container.decodeIfPresent(String.self, forKey: .createdFor) ?? Self.defaultCreatedFor
            let drafts = try container.decode([ConversationPracticeEntryDraft].self, forKey: .entries)
            let defaultCategory = ConversationPracticeRules.stableIdentifier(for: title)
            entries = drafts.enumerated().map { index, draft in
                ConversationPracticeEntry(
                    draft: draft,
                    fallbackSequence: index + 1,
                    defaultCategory: defaultCategory
                )
            }
        } else {
            let importedContainer = try decoder.container(keyedBy: ImportedCodingKeys.self)
            let theme = try importedContainer.decode(String.self, forKey: .theme)
            title = theme
            packID = ConversationPracticeRules.stableIdentifier(for: theme)
            version = "1.0"
            description = "Imported practice pack: \(theme)"
            language = "zh-Hans"
            sourceType = "user_imported_practice"
            createdFor = Self.defaultCreatedFor
            let defaultCategory = ConversationPracticeRules.stableIdentifier(for: theme)
            let drafts = try importedContainer.decode([ConversationPracticeEntryDraft].self, forKey: .entries)
            entries = drafts.enumerated().map { index, draft in
                ConversationPracticeEntry(
                    draft: draft,
                    fallbackSequence: index + 1,
                    defaultCategory: defaultCategory
                )
            }
        }
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

    fileprivate init(
        draft: ConversationPracticeEntryDraft,
        fallbackSequence: Int,
        defaultCategory: String
    ) {
        id = draft.id
        sequence = draft.sequence ?? fallbackSequence
        category = draft.category ?? defaultCategory
        level = draft.level ?? "easy"
        sentence = draft.sentence
        analysis = draft.analysis ?? ConversationPracticeAnalysis(sentence: draft.sentence.zh)
        metadata = draft.metadata ?? ConversationPracticeMetadata(category: category)
        notes = draft.notes ?? ""
    }
}

public struct ConversationPracticeSentence: Codable, Equatable {
    public let zh: String
    public let pinyin: String
    public let en: String
}

public struct ConversationPracticeAnalysis: Codable, Equatable {
    public let characters: [String]
    public let phrases: [String]

    init(characters: [String], phrases: [String]) {
        self.characters = characters
        self.phrases = phrases
    }

    init(sentence: String) {
        var seen: Set<String> = []
        var orderedCharacters: [String] = []
        for character in sentence where ConversationPracticeRules.isChineseCharacter(character) {
            let value = String(character)
            if seen.insert(value).inserted {
                orderedCharacters.append(value)
            }
        }
        characters = orderedCharacters
        phrases = [ConversationPracticeRules.phraseKey(for: sentence)]
    }
}

public struct ConversationPracticeMetadata: Codable, Equatable {
    public let difficulty: Int
    public let frequency: Int
    public let tags: [String]

    init(difficulty: Int, frequency: Int, tags: [String]) {
        self.difficulty = difficulty
        self.frequency = frequency
        self.tags = tags
    }

    init(category: String) {
        difficulty = 1
        frequency = 1
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        tags = trimmedCategory.isEmpty ? [] : [trimmedCategory]
    }
}

private struct ConversationPracticeEntryDraft: Decodable {
    let id: String
    let sequence: Int?
    let category: String?
    let level: String?
    let sentence: ConversationPracticeSentence
    let analysis: ConversationPracticeAnalysis?
    let metadata: ConversationPracticeMetadata?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id
        case sequence
        case category
        case level
        case sentence
        case analysis
        case metadata
        case notes
        case zh
        case pinyin
        case en
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        sequence = try container.decodeIfPresent(Int.self, forKey: .sequence)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        level = try container.decodeIfPresent(String.self, forKey: .level)
        if let decodedSentence = try container.decodeIfPresent(ConversationPracticeSentence.self, forKey: .sentence) {
            sentence = decodedSentence
        } else {
            sentence = ConversationPracticeSentence(
                zh: try container.decode(String.self, forKey: .zh),
                pinyin: try container.decode(String.self, forKey: .pinyin),
                en: try container.decode(String.self, forKey: .en)
            )
        }
        analysis = try container.decodeIfPresent(ConversationPracticeAnalysis.self, forKey: .analysis)
        metadata = try container.decodeIfPresent(ConversationPracticeMetadata.self, forKey: .metadata)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }
}

public struct ConversationPracticeSet: Equatable, Identifiable {
    public let id: String
    public let title: String
    public let description: String
    public let language: String
    public let itemCount: Int
}

public struct ConversationPracticeTopic: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let summary: String
    public let difficultyLabel: String
    public let bundledResourceName: String?
    public let generationBrief: String
    public let situations: [String]
    public let targetSentenceCount: Int

    public var hasBundledContent: Bool {
        bundledResourceName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    public static let generalGreetings = ConversationPracticeTopic(
        id: "general_greetings",
        title: "General Greetings",
        summary: "Common beginner greetings and social basics.",
        difficultyLabel: "Easy starter set",
        bundledResourceName: "conversation100",
        generationBrief: "General greetings and everyday social openings for beginner Mandarin learners.",
        situations: [
            "saying hello and goodbye",
            "morning and evening greetings",
            "asking how someone is",
            "polite thanks and apologies",
            "simple social responses"
        ],
        targetSentenceCount: 100
    )

    public static let foodEating = ConversationPracticeTopic(
        id: "food_eating",
        title: "Food / Eating Conversation",
        summary: "Ordering, sharing dishes, taste, price, portions, and polite mealtime talk.",
        difficultyLabel: "Easy situational set",
        bundledResourceName: "Food Dining",
        generationBrief: "Restaurant, hawker centre or casual eatery, and home dinner-table Mandarin conversation about eating, ordering food, sharing dishes, preferences, prices, portions, taste, and polite offers or responses.",
        situations: [
            "ordering food in a restaurant",
            "eating at a hawker centre or casual eatery",
            "dinner table conversation at home",
            "asking about taste, price, portions, and preferences",
            "offering food and responding politely"
        ],
        targetSentenceCount: 100
    )

    public static let tripToFourCities = ConversationPracticeTopic(
        id: "china_taiwan_travel",
        title: "Trip to 4 Cities",
        summary: "Transport, hotels, sightseeing, and polite travel help in Beijing, Shanghai, Guangzhou, and Taipei.",
        difficultyLabel: "Easy travel set",
        bundledResourceName: "Trip to 4 cities",
        generationBrief: "Travel Mandarin for Beijing, Shanghai, Guangzhou, and Taipei, covering taxis, metro, airport, hotels, sightseeing, shopping, directions, prices, help, and polite local interactions.",
        situations: [
            "taking taxis, metro, trains, and airport transport",
            "checking in and asking hotel questions",
            "asking directions around the city",
            "buying tickets, shopping, and asking prices",
            "sightseeing and polite travel help"
        ],
        targetSentenceCount: 100
    )

    public static let stayInShanghai = ConversationPracticeTopic(
        id: "shanghai_relocation_study",
        title: "Stay in Shanghai",
        summary: "Longer-stay Shanghai Mandarin for study, housing, transport, utilities, and local admin.",
        difficultyLabel: "Practical city-living set",
        bundledResourceName: "Stay in Shanghai",
        generationBrief: "Longer-stay Shanghai Mandarin for Mandarin courses, student life, housing, utilities, transport, healthcare, shopping, local services, and administrative tasks.",
        situations: [
            "asking about Mandarin courses and study schedules",
            "finding housing and handling rent or utilities",
            "using transport and local city services",
            "shopping, errands, healthcare, and daily needs",
            "handling registration and administrative tasks"
        ],
        targetSentenceCount: 100
    )

    public static let defaults: [ConversationPracticeTopic] = [
        .generalGreetings,
        .foodEating,
        .tripToFourCities,
        .stayInShanghai
    ]

    public static func topic(for id: String) -> ConversationPracticeTopic {
        defaults.first { $0.id == id } ?? .generalGreetings
    }
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

    public static func stableIdentifier(for title: String) -> String {
        var result = ""
        var previousWasSeparator = false

        for scalar in title.lowercased().unicodeScalars {
            if (65...90).contains(Int(scalar.value)) || (97...122).contains(Int(scalar.value)) || (48...57).contains(Int(scalar.value)) {
                result.unicodeScalars.append(scalar)
                previousWasSeparator = false
            } else if !previousWasSeparator {
                result.append("_")
                previousWasSeparator = true
            }
        }

        let trimmed = result.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return trimmed.isEmpty ? "imported_practice" : trimmed
    }

    public static func isChineseCharacter(_ character: Character) -> Bool {
        character.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(Int(scalar.value))
        }
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

}

public enum ConversationPracticeQuizRules {
    public struct CharacterQuestion: Equatable {
        public let character: String
        public let blankedSentence: String

        public init(character: String, blankedSentence: String) {
            self.character = character
            self.blankedSentence = blankedSentence
        }
    }

    public struct CharacterChoiceCandidate: Equatable {
        public let character: String
        public let components: [String]
        public let rank: Int?

        public init(character: String, components: [String] = [], rank: Int? = nil) {
            self.character = character
            self.components = components
            self.rank = rank
        }
    }

    public static func characterQuestion(for item: ConversationPracticeItem) -> CharacterQuestion {
        characterQuestion(for: item, candidates: [])
    }

    public static func characterQuestion(
        for item: ConversationPracticeItem,
        candidates: [CharacterChoiceCandidate]
    ) -> CharacterQuestion {
        characterQuestion(
            sentence: item.simplified,
            characterHints: item.characterHints,
            candidates: candidates
        )
    }

    public static func characterQuestion(
        sentence: String,
        characterHints: [String],
        candidates: [CharacterChoiceCandidate]
    ) -> CharacterQuestion {
        let character = questionCharacter(
            characterHints: characterHints,
            fallbackSentence: sentence,
            candidates: candidates
        )
        return CharacterQuestion(
            character: character,
            blankedSentence: sentenceByBlanking(character, in: sentence)
        )
    }

    public static func questionCharacter(for item: ConversationPracticeItem) -> String {
        questionCharacter(for: item, candidates: [])
    }

    public static func questionCharacter(
        for item: ConversationPracticeItem,
        candidates: [CharacterChoiceCandidate]
    ) -> String {
        questionCharacter(
            characterHints: item.characterHints,
            fallbackSentence: item.simplified,
            candidates: candidates
        )
    }

    public static func questionCharacter(
        characterHints: [String],
        fallbackSentence: String,
        candidates: [CharacterChoiceCandidate]
    ) -> String {
        let hintedCharacters = characterHints.filter { $0.count == 1 && isChineseCharacter($0) }
        let usableCandidates = uniqueCandidates(candidates)
        if let confusableCharacter = confusableQuestionCharacter(
            from: hintedCharacters,
            candidates: usableCandidates
        ) {
            return confusableCharacter
        }

        if let substantialCharacter = hintedCharacters.first(where: isSubstantialQuizCharacter) {
            return substantialCharacter
        }

        if let hinted = hintedCharacters.first { return hinted }

        return fallbackSentence
            .map(String.init)
            .first(where: { isChineseCharacter($0) && isSubstantialQuizCharacter($0) })
            ?? fallbackSentence
                .map(String.init)
                .first(where: { $0.count == 1 && isChineseCharacter($0) })
            ?? fallbackSentence
    }

    public static func characterChoices(
        for character: String,
        from candidates: [CharacterChoiceCandidate],
        count: Int = 4
    ) -> [String] {
        let uniqueCandidates = uniqueCandidates(candidates)

        guard let answer = uniqueCandidates.first(where: { $0.character == character }) else {
            return [character]
        }

        let answerComponents = Set(answer.components)
        let distractors = uniqueCandidates
            .filter { $0.character != character }
            .sorted {
                characterChoiceSort(
                    $0,
                    before: $1,
                    answerComponents: answerComponents,
                    answerCharacter: character
                )
            }
            .prefix(max(0, count - 1))

        return ([answer.character] + distractors.map(\.character)).sorted {
            stableOrderKey($0, itemID: character) < stableOrderKey($1, itemID: character)
        }
    }

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

    private static func characterChoiceSort(
        _ lhs: CharacterChoiceCandidate,
        before rhs: CharacterChoiceCandidate,
        answerComponents: Set<String>,
        answerCharacter: String
    ) -> Bool {
        let lhsShared = Set(lhs.components).intersection(answerComponents).count
        let rhsShared = Set(rhs.components).intersection(answerComponents).count
        if lhsShared != rhsShared { return lhsShared > rhsShared }

        let lhsRank = lhs.rank ?? Int.max
        let rhsRank = rhs.rank ?? Int.max
        if lhsRank != rhsRank { return lhsRank < rhsRank }

        return stableOrderKey(lhs.character, itemID: answerCharacter) < stableOrderKey(rhs.character, itemID: answerCharacter)
    }

    private static func isChineseCharacter(_ value: String) -> Bool {
        value.count == 1 && value.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(Int(scalar.value))
        }
    }

    private static func uniqueCandidates(_ candidates: [CharacterChoiceCandidate]) -> [CharacterChoiceCandidate] {
        var uniqueCandidates: [CharacterChoiceCandidate] = []
        var seen = Set<String>()
        for candidate in candidates where candidate.character.count == 1 && isChineseCharacter(candidate.character) {
            guard seen.insert(candidate.character).inserted else { continue }
            uniqueCandidates.append(candidate)
        }
        return uniqueCandidates
    }

    private static func confusableQuestionCharacter(
        from characters: [String],
        candidates: [CharacterChoiceCandidate]
    ) -> String? {
        let byCharacter = Dictionary(uniqueKeysWithValues: candidates.map { ($0.character, $0) })
        let scored = characters.compactMap { character -> (character: String, score: Int, lowValue: Bool)? in
            guard let candidate = byCharacter[character] else { return nil }
            let score = confusabilityScore(for: candidate, in: candidates)
            guard score > 0 else { return nil }
            return (character, score, !isSubstantialQuizCharacter(character))
        }

        return scored.sorted { lhs, rhs in
            if lhs.lowValue != rhs.lowValue { return !lhs.lowValue }
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return characters.firstIndex(of: lhs.character) ?? Int.max < characters.firstIndex(of: rhs.character) ?? Int.max
        }.first?.character
    }

    private static func confusabilityScore(
        for candidate: CharacterChoiceCandidate,
        in candidates: [CharacterChoiceCandidate]
    ) -> Int {
        let components = Set(candidate.components)
        guard !components.isEmpty else { return 0 }

        return candidates
            .filter { $0.character != candidate.character }
            .reduce(0) { score, peer in
                let sharedCount = Set(peer.components).intersection(components).count
                if sharedCount >= 2 { return score + 3 }
                if sharedCount == 1 { return score + 1 }
                return score
            }
    }

    private static func sentenceByBlanking(_ character: String, in sentence: String) -> String {
        guard !character.isEmpty else { return sentence }
        return sentence.replacingOccurrences(of: character, with: "＿", options: [], range: sentence.startIndex..<sentence.endIndex)
    }

    private static func isSubstantialQuizCharacter(_ character: String) -> Bool {
        !lowValueQuestionCharacters.contains(character)
    }

    private static let lowValueQuestionCharacters: Set<String> = [
        "我", "你", "他", "她", "它", "们", "这", "那", "哪", "个", "的", "了", "吗", "呢",
        "吧", "啊", "是", "在", "有", "不", "很", "太", "一", "二", "三"
    ]
}

private extension CharacterSet {
    static let whitespacesAndNewlinesAndPunctuation = CharacterSet.whitespacesAndNewlines
        .union(.punctuationCharacters)
        .union(CharacterSet(charactersIn: "。！？；，、"))
}
