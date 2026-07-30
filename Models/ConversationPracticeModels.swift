import Foundation

public enum ConversationPracticeDifficulty: String, Codable, CaseIterable, Hashable {
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

    init(_ difficulty: SentenceExampleDifficulty) {
        switch difficulty {
        case .easy: self = .easy
        case .medium: self = .medium
        case .hard: self = .hard
        case .unknown: self = .easy
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
    public let sourceLink: ConversationPracticeSourceLink?
    public let sentenceReferences: [ConversationPracticeSentenceReference]
    public let entries: [ConversationPracticeEntry]

    enum CodingKeys: String, CodingKey {
        case packID = "pack_id"
        case version
        case title
        case description
        case language
        case sourceType = "source_type"
        case createdFor = "created_for"
        case sourceLink = "source_link"
        case sentenceReferences = "sentence_references"
        case entries
    }

    enum ImportedCodingKeys: String, CodingKey {
        case theme
        case sourceLink = "source_link"
        case entries
    }

    public init(
        packID: String,
        version: String,
        title: String,
        description: String,
        language: String,
        sourceType: String,
        createdFor: String,
        sourceLink: ConversationPracticeSourceLink?,
        sentenceReferences: [ConversationPracticeSentenceReference] = [],
        entries: [ConversationPracticeEntry]
    ) {
        self.packID = packID
        self.version = version
        self.title = title
        self.description = description
        self.language = language
        self.sourceType = sourceType
        self.createdFor = createdFor
        self.sourceLink = sourceLink
        self.sentenceReferences = sentenceReferences
        self.entries = entries
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
            sourceLink = try container.decodeIfPresent(ConversationPracticeSourceLink.self, forKey: .sourceLink)
            sentenceReferences = try container.decodeIfPresent(
                [ConversationPracticeSentenceReference].self,
                forKey: .sentenceReferences
            ) ?? []
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
            sourceLink = try importedContainer.decodeIfPresent(ConversationPracticeSourceLink.self, forKey: .sourceLink)
            sentenceReferences = []
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
        var referencesByItemID: [String: ConversationPracticeSentenceReference] = [:]
        for reference in sentenceReferences {
            referencesByItemID[reference.practiceItemID] = reference
        }
        return entries.sorted { $0.sequence < $1.sequence }.map {
            ConversationPracticeItem(
                entry: $0,
                setID: packID,
                sentenceReference: referencesByItemID[$0.id]
            )
        }
    }

    public var needsCanonicalSentenceReferences: Bool {
        let items = practiceItems
        guard sentenceReferences.count == items.count else { return true }
        var referencesByItemID: [String: ConversationPracticeSentenceReference] = [:]
        for reference in sentenceReferences {
            referencesByItemID[reference.practiceItemID] = reference
        }
        return items.contains { item in
            guard let reference = referencesByItemID[item.id] else { return true }
            return reference.sentenceExampleID == nil ||
                reference.rank != item.rank ||
                reference.sentenceKey != SentenceExampleRecord.normalizedChineseKey(item.simplified)
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

    public func withSourceLink(_ sourceLink: ConversationPracticeSourceLink?) -> ConversationPracticePack {
        ConversationPracticePack(
            packID: packID,
            version: version,
            title: title,
            description: description,
            language: language,
            sourceType: sourceType,
            createdFor: createdFor,
            sourceLink: sourceLink,
            sentenceReferences: sentenceReferences,
            entries: entries
        )
    }

    public func withSentenceReferences(_ references: [ConversationPracticeSentenceReference]) -> ConversationPracticePack {
        ConversationPracticePack(
            packID: packID,
            version: version,
            title: title,
            description: description,
            language: language,
            sourceType: sourceType,
            createdFor: createdFor,
            sourceLink: sourceLink,
            sentenceReferences: references,
            entries: entries
        )
    }

    public func withCanonicalSentenceReferences(
        from sentenceExamples: [SentenceExampleRecord]
    ) -> ConversationPracticePack {
        var recordsByKey: [String: SentenceExampleRecord] = [:]
        for record in sentenceExamples {
            recordsByKey[record.normalizedChineseKey] = record
        }
        let references = practiceItems.map { item in
            let key = SentenceExampleRecord.normalizedChineseKey(item.simplified)
            return ConversationPracticeSentenceReference(
                practiceItemID: item.id,
                rank: item.rank,
                sentenceExampleID: recordsByKey[key]?.id,
                sentenceKey: key
            )
        }
        return withSentenceReferences(references)
    }
}

public enum ConversationPracticeSourceKind: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case savedPage = "saved_page"
}

public struct ConversationPracticeSourceLink: Codable, Equatable, Hashable, Sendable {
    public let kind: ConversationPracticeSourceKind
    public let sourceID: String?
    public let sourceTitle: String
    public let sourceCreatedAt: Date?
    public let contentFingerprint: String?

    enum CodingKeys: String, CodingKey {
        case kind
        case sourceID = "source_id"
        case sourceTitle = "source_title"
        case sourceCreatedAt = "source_created_at"
        case contentFingerprint = "content_fingerprint"
    }

    public static func savedPage(
        id: UUID,
        title: String,
        createdAt: Date?,
        contentFingerprint: String? = nil
    ) -> ConversationPracticeSourceLink {
        ConversationPracticeSourceLink(
            kind: .savedPage,
            sourceID: id.uuidString,
            sourceTitle: title,
            sourceCreatedAt: createdAt,
            contentFingerprint: contentFingerprint
        )
    }

    public var sourcePageID: UUID? {
        guard kind == .savedPage, let sourceID else { return nil }
        return UUID(uuidString: sourceID)
    }
}

public struct ConversationPracticeSentenceReference: Codable, Equatable, Hashable, Identifiable, Sendable {
    public let practiceItemID: String
    public let rank: Int
    public let sentenceExampleID: UUID?
    public let sentenceKey: String

    enum CodingKeys: String, CodingKey {
        case practiceItemID = "practice_item_id"
        case rank
        case sentenceExampleID = "sentence_example_id"
        case sentenceKey = "sentence_key"
    }

    public var id: String {
        "\(rank)#\(practiceItemID)"
    }

    public init(
        practiceItemID: String,
        rank: Int,
        sentenceExampleID: UUID?,
        sentenceKey: String
    ) {
        self.practiceItemID = practiceItemID
        self.rank = rank
        self.sentenceExampleID = sentenceExampleID
        self.sentenceKey = sentenceKey
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

    public static let everydayConversation = generationTopic(
        id: "everyday_conversation",
        title: "Everyday Conversation",
        summary: "Greetings, small talk, plans, time, weather, and daily routines.",
        generationBrief: "Everyday Mandarin conversation for greetings, introductions, polite expressions, small talk, time, dates, weather, daily routines, making plans, clarifying meaning, apologizing, thanking, and simple social responses.",
        situations: [
            "greetings, introductions, and polite expressions",
            "small talk about weather, time, and daily routines",
            "making plans and confirming details",
            "asking for clarification or repetition",
            "apologizing, thanking, and simple social responses"
        ]
    )

    public static let foodShopping = generationTopic(
        id: "food_shopping",
        title: "Food & Shopping",
        summary: "Restaurants, groceries, cooking, payments, bargaining, clothes, and online shopping.",
        generationBrief: "Practical Mandarin for restaurants, cafes, street food, groceries, cooking, dietary needs, paying bills, bargaining, clothes shopping, online shopping, returns, and exchanges.",
        situations: [
            "ordering food and drinks",
            "buying groceries and talking about cooking",
            "explaining taste, price, portions, and dietary needs",
            "shopping for clothes or everyday goods",
            "paying, bargaining, returning, or exchanging items"
        ]
    )

    public static let travelTransportation = generationTopic(
        id: "travel_transportation",
        title: "Travel & Transportation",
        summary: "Airports, trains, taxis, directions, hotels, sightseeing, and travel problems.",
        generationBrief: "Travel Mandarin for airports, trains, taxis, ride-hailing, buses, metro, asking directions, hotel check-in, sightseeing, immigration, customs, luggage, delays, and travel problems.",
        situations: [
            "using airports, trains, buses, metro, taxis, and ride-hailing",
            "asking for directions and route details",
            "checking in at hotels and asking for help",
            "buying tickets and visiting attractions",
            "handling luggage, delays, and travel problems"
        ]
    )

    public static let homePersonalLife = generationTopic(
        id: "home_personal_life",
        title: "Home & Personal Life",
        summary: "Family, friends, relationships, housing, chores, neighbors, hobbies, and weekends.",
        generationBrief: "Mandarin conversation about family, friends, relationships, home life, household chores, rooms, furniture, renting, neighbors, personal habits, hobbies, and weekend activities.",
        situations: [
            "talking about family, friends, and relationships",
            "describing home life, rooms, and furniture",
            "renting housing and talking with neighbors",
            "handling chores and daily household tasks",
            "sharing hobbies, habits, and weekend activities"
        ]
    )

    public static let workSchool = generationTopic(
        id: "work_school",
        title: "Work & School",
        summary: "Office talk, meetings, interviews, school life, homework, exams, and presentations.",
        generationBrief: "Mandarin for work and school, including job interviews, office conversation, meetings, email and messaging, asking for help, project updates, customer service, classroom questions, homework, exams, university life, and presentations.",
        situations: [
            "job interviews and workplace introductions",
            "meetings, project updates, and office requests",
            "customer service and professional messaging",
            "classroom questions, homework, and exams",
            "university life and presentations"
        ]
    )

    public static let healthEmergencies = generationTopic(
        id: "health_emergencies",
        title: "Health & Emergencies",
        summary: "Pharmacy, doctor, dentist, symptoms, medicine, allergies, safety, and urgent help.",
        generationBrief: "Health and safety Mandarin for pharmacies, doctor visits, dentists, hospitals, symptoms, pain, medicine instructions, allergies, mental-health check-ins, exercise, fitness, emergency help, and urgent safety situations.",
        situations: [
            "explaining symptoms, pain, and allergies",
            "visiting a pharmacy, doctor, dentist, or hospital",
            "understanding medicine and care instructions",
            "asking for urgent or emergency help",
            "talking about exercise, fitness, and wellbeing"
        ]
    )

    public static let cityLifeServices = generationTopic(
        id: "city_life_services",
        title: "City Life & Services",
        summary: "Bank, post office, phone shop, salon, repairs, police, lost and found, and local offices.",
        generationBrief: "Mandarin for city services and errands, including banks, post offices, phone shops, hair salons, laundry, repairs, police stations, lost and found, community services, government offices, and appointments.",
        situations: [
            "using banks, post offices, and phone shops",
            "booking salons, laundry, repair, or other services",
            "reporting lost items or asking police for help",
            "handling community or government office tasks",
            "making, changing, and confirming appointments"
        ]
    )

    public static let socialCulture = generationTopic(
        id: "social_culture",
        title: "Social & Culture",
        summary: "Festivals, birthdays, visits, gifts, invitations, parties, dating, media, sports, and culture.",
        generationBrief: "Social and cultural Mandarin for festivals, birthdays, visiting someone's home, giving gifts, dating, making friends, invitations, parties, movies, music, sports, news, current events, and cultural differences.",
        situations: [
            "festivals, birthdays, and visiting someone's home",
            "giving gifts and responding politely",
            "making friends, dating, and invitations",
            "talking about parties, movies, music, and sports",
            "discussing news, culture, and cultural differences"
        ]
    )

    public static let technologyModernLife = generationTopic(
        id: "technology_modern_life",
        title: "Technology & Modern Life",
        summary: "Phones, apps, passwords, payments, delivery, navigation, social media, and tech support.",
        generationBrief: "Modern-life Mandarin for phones, apps, passwords, social media, online payments, delivery apps, navigation apps, tech support, AI, internet topics, privacy, and security.",
        situations: [
            "setting up phones, apps, passwords, and accounts",
            "using online payments and delivery apps",
            "asking for navigation or tech support",
            "talking about social media, AI, and internet topics",
            "handling privacy, security, and account problems"
        ]
    )

    public static let opinionsDeeperTalk = generationTopic(
        id: "opinions_deeper_talk",
        title: "Opinions & Deeper Talk",
        summary: "Preferences, comparisons, advice, disagreement, reasons, emotions, goals, values, and learning Chinese.",
        generationBrief: "Mandarin for opinions and deeper conversation, including preferences, comparisons, advice, agreeing and disagreeing, explaining reasons, describing experiences, emotions, goals, plans, personal values, learning Chinese, and cross-cultural conversation.",
        situations: [
            "expressing preferences and comparing options",
            "giving advice and agreeing or disagreeing politely",
            "explaining reasons and describing experiences",
            "talking about emotions, goals, plans, and values",
            "discussing learning Chinese and cross-cultural topics"
        ]
    )

    public static let defaults: [ConversationPracticeTopic] = [
        .generalGreetings,
        .foodEating,
        .tripToFourCities,
        .stayInShanghai,
        .everydayConversation,
        .foodShopping,
        .travelTransportation,
        .homePersonalLife,
        .workSchool,
        .healthEmergencies,
        .cityLifeServices,
        .socialCulture,
        .technologyModernLife,
        .opinionsDeeperTalk
    ]

    public static let favoriteSentencesID = "favorite_sentences"

    public static func favoriteSentences(count: Int) -> ConversationPracticeTopic {
        ConversationPracticeTopic(
            id: favoriteSentencesID,
            title: "Favorite Sentences",
            summary: "\(count) saved sentences",
            difficultyLabel: "Saved from Study",
            bundledResourceName: nil,
            generationBrief: "Learner-saved Chinese sentences for review and practice.",
            situations: [],
            targetSentenceCount: count
        )
    }

    public static func topic(for id: String) -> ConversationPracticeTopic {
        defaults.first { $0.id == id } ?? .generalGreetings
    }

    private static func generationTopic(
        id: String,
        title: String,
        summary: String,
        generationBrief: String,
        situations: [String],
        targetSentenceCount: Int = 100
    ) -> ConversationPracticeTopic {
        ConversationPracticeTopic(
            id: id,
            title: title,
            summary: summary,
            difficultyLabel: "Generation-ready theme",
            bundledResourceName: nil,
            generationBrief: generationBrief,
            situations: situations,
            targetSentenceCount: targetSentenceCount
        )
    }
}

public struct ConversationPracticeItem: Equatable, Hashable, Identifiable {
    public let id: String
    public let setID: String
    public let phraseKey: String
    public let sentenceExampleID: UUID?
    public let sentenceKey: String
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

    init(
        entry: ConversationPracticeEntry,
        setID: String,
        sentenceReference: ConversationPracticeSentenceReference? = nil
    ) {
        id = entry.id
        self.setID = setID
        phraseKey = ConversationPracticeRules.phraseKey(for: entry.sentence.zh)
        sentenceExampleID = sentenceReference?.sentenceExampleID
        sentenceKey = sentenceReference?.sentenceKey ?? SentenceExampleRecord.normalizedChineseKey(entry.sentence.zh)
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

    init(favoriteSentence record: FavoriteSentenceRecord, rank: Int) {
        id = record.id
        setID = ConversationPracticeTopic.favoriteSentencesID
        phraseKey = ConversationPracticeRules.phraseKey(for: record.simplified)
        sentenceExampleID = nil
        sentenceKey = SentenceExampleRecord.normalizedChineseKey(record.simplified)
        self.rank = rank
        simplified = record.simplified
        pinyin = record.pinyin
        english = record.english
        category = ConversationPracticeTopic.favoriteSentencesID
        difficulty = .easy
        tags = ["favorite"]
        characterHints = record.characterHints
        phraseHints = record.phraseHints
        notes = "Saved from \(record.sourceSetID)"
    }

    init(sentenceExample record: SentenceExampleRecord, rank: Int) {
        id = record.id.uuidString
        setID = "sentence_examples"
        phraseKey = ConversationPracticeRules.phraseKey(for: record.chinese)
        sentenceExampleID = record.id
        sentenceKey = record.normalizedChineseKey
        self.rank = rank
        simplified = record.chinese
        pinyin = record.pinyin ?? ""
        english = record.english ?? ""
        category = record.sources.first?.sourceType.rawValue ?? "sentence_examples"
        difficulty = ConversationPracticeDifficulty(record.difficulty)
        tags = record.tags
        characterHints = record.targetCharacters.isEmpty ? record.detectedCharacters : record.targetCharacters
        phraseHints = record.targetPhrases.isEmpty ? record.detectedPhrases : record.targetPhrases
        notes = record.notes
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

    static func sentenceExamplesLibrary(
        from records: [SentenceExampleRecord],
        title: String = "Sentence Practice"
    ) -> ConversationPracticeLibrary? {
        let records = SentenceExampleRecord.ranked(records)
        guard !records.isEmpty else { return nil }
        let items = records.enumerated().map { index, record in
            ConversationPracticeItem(sentenceExample: record, rank: index + 1)
        }
        return ConversationPracticeLibrary(
            set: ConversationPracticeSet(
                id: "sentence_examples_review",
                title: title,
                description: "\(items.count) sentences",
                language: "zh",
                itemCount: items.count
            ),
            items: items,
            phraseSeeds: items.map(ConversationPracticePhraseSeed.init),
            memberships: items.map(ConversationPracticeMembership.init)
        )
    }

    static func favoriteSentencesLibrary(from records: [FavoriteSentenceRecord]) -> ConversationPracticeLibrary? {
        let records = FavoriteSentenceRecord.deduplicated(records)
        guard !records.isEmpty else { return nil }
        let items = records.enumerated().map { index, record in
            ConversationPracticeItem(favoriteSentence: record, rank: index + 1)
        }
        return ConversationPracticeLibrary(
            set: ConversationPracticeSet(
                id: ConversationPracticeTopic.favoriteSentencesID,
                title: "Favorite Sentences",
                description: "\(items.count) saved sentences",
                language: "zh",
                itemCount: items.count
            ),
            items: items,
            phraseSeeds: items.map(ConversationPracticePhraseSeed.init),
            memberships: items.map(ConversationPracticeMembership.init)
        )
    }

    static func favoriteSentencesLibrary(from sentenceExamples: [SentenceExampleRecord]) -> ConversationPracticeLibrary? {
        let records = SentenceExampleRecord.ranked(sentenceExamples)
            .filter(\.isFavorited)
            .map { FavoriteSentenceRecord(sentenceExample: $0) }
        return favoriteSentencesLibrary(from: records)
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

    static func importJSONCandidates(from text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var candidates = [trimmed]
        let lines = trimmed.components(separatedBy: .newlines)
        if let firstLine = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines),
           firstLine.hasPrefix("```") {
            var bodyLines = Array(lines.dropFirst())
            if bodyLines.last?.trimmingCharacters(in: .whitespacesAndNewlines) == "```" {
                bodyLines.removeLast()
            }
            let fencedBody = bodyLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !fencedBody.isEmpty {
                candidates.append(fencedBody)
            }
        }

        if let firstBrace = trimmed.firstIndex(of: "{"),
           let lastBrace = trimmed.lastIndex(of: "}"),
           firstBrace < lastBrace {
            let objectBody = String(trimmed[firstBrace...lastBrace])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !objectBody.isEmpty {
                candidates.append(objectBody)
            }
        }

        var seen = Set<String>()
        return candidates.filter { candidate in
            guard !seen.contains(candidate) else { return false }
            seen.insert(candidate)
            return true
        }
    }

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

    public static func nonOverlappingPhraseHints(_ phrases: [String], in source: String) -> [String] {
        struct Candidate {
            let phrase: String
            let normalizedPhrase: String
            let start: Int
            let end: Int

            var length: Int { end - start }
        }

        var seen = Set<String>()
        var candidates: [Candidate] = []

        for rawPhrase in phrases {
            let phrase = phraseKey(for: rawPhrase)
            guard phrase.count >= 2, seen.insert(phrase).inserted else { continue }

            var searchRange = source.startIndex..<source.endIndex
            while let range = source.range(of: phrase, range: searchRange) {
                let start = source.distance(from: source.startIndex, to: range.lowerBound)
                let end = source.distance(from: source.startIndex, to: range.upperBound)
                candidates.append(Candidate(
                    phrase: rawPhrase,
                    normalizedPhrase: phrase,
                    start: start,
                    end: end
                ))

                guard range.upperBound < source.endIndex else { break }
                searchRange = range.upperBound..<source.endIndex
            }
        }

        let priorityOrdered = candidates.sorted {
            if $0.length != $1.length { return $0.length > $1.length }
            if $0.start != $1.start { return $0.start < $1.start }
            return $0.normalizedPhrase < $1.normalizedPhrase
        }

        var occupiedOffsets = Set<Int>()
        var acceptedPhrases = Set<String>()
        var accepted: [Candidate] = []

        for candidate in priorityOrdered {
            let offsets = candidate.start..<candidate.end
            guard !offsets.contains(where: occupiedOffsets.contains),
                  acceptedPhrases.insert(candidate.normalizedPhrase).inserted
            else { continue }

            occupiedOffsets.formUnion(offsets)
            accepted.append(candidate)
        }

        return accepted.sorted {
            if $0.start != $1.start { return $0.start < $1.start }
            if $0.length != $1.length { return $0.length > $1.length }
            return $0.normalizedPhrase < $1.normalizedPhrase
        }
        .map(\.phrase)
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

}

private extension CharacterSet {
    static let whitespacesAndNewlinesAndPunctuation = CharacterSet.whitespacesAndNewlines
        .union(.punctuationCharacters)
        .union(CharacterSet(charactersIn: "。！？；，、"))
}
