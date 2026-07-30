import Foundation

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
