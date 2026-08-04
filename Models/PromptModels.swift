import Foundation

struct LatestAIResult: Codable, Equatable, Identifiable {
    let id: UUID
    let taskTitle: String
    let subject: String
    let body: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        taskTitle: String,
        subject: String,
        body: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.taskTitle = taskTitle
        self.subject = subject
        self.body = body
        self.createdAt = createdAt
    }
}

enum PromptTaskSubjectType: String, Codable, CaseIterable, Identifiable {
    case characterPhrase
    case sentence
    case page
    case practiceTopic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .characterPhrase: return "Character / Phrase"
        case .sentence: return "Sentence"
        case .page: return "Page"
        case .practiceTopic: return "Practice Theme"
        }
    }

    var systemImage: String {
        switch self {
        case .characterPhrase: return "character"
        case .sentence: return "quote.bubble"
        case .page: return "photo.on.rectangle"
        case .practiceTopic: return "bubble.left.and.bubble.right"
        }
    }
}

struct PromptTask: Codable, Hashable, Identifiable {
    let id: String
    var title: String
    var template: String
    var subjectType: PromptTaskSubjectType = .characterPhrase

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case template
        case subjectType
    }

    init(
        id: String,
        title: String,
        template: String,
        subjectType: PromptTaskSubjectType = .characterPhrase
    ) {
        self.id = id
        self.title = title
        self.template = template
        self.subjectType = subjectType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        template = try container.decode(String.self, forKey: .template)
        subjectType = try container.decodeIfPresent(PromptTaskSubjectType.self, forKey: .subjectType) ??
            PromptConfig.defaultSubjectType(forTaskID: id)
    }
}

enum SentenceExtractionDetail: String, CaseIterable, Identifiable {
    case brief
    case detailed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .brief: return "Brief"
        case .detailed: return "Detailed"
        }
    }

    var promptInstruction: String {
        switch self {
        case .brief:
            return """
Brief mode: extract clean, concise sentence records. Keep each English translation short and natural. Include accurate tone-mark pinyin, but do not add notes, analysis, or extra metadata beyond the required JSON keys.
"""
        case .detailed:
            return """
Detailed mode: create richer study-ready sentence records. Keep each Chinese sentence complete and useful, include accurate tone-mark pinyin, provide a natural English meaning, and choose sentences that will display well with Chinese/English toggles, pinyin reveal, read-aloud, and phrase inspection in Radix. Prefer entries whose useful phrases can be inspected later, but do not add extra JSON keys.
"""
        }
    }

    static func normalized(_ rawValue: String?) -> SentenceExtractionDetail {
        guard let rawValue,
              let detail = SentenceExtractionDetail(rawValue: rawValue)
        else { return .brief }
        return detail
    }
}

struct PromptConfig: Codable, Hashable {
    var version: Int
    var preamble: String
    var tasks: [PromptTask]
    var epilogue: String
    var collectionPreamble: String
    var collectionEpilogue: String

    static let collectionTaskIDs: Set<String> = ["task4", "task5", "task7", "task8", "task10", "task11", "task12"]
    static let practiceTopicTaskIDs: Set<String> = ["task9"]
    static let defaultSentenceTaskID = "task13"
    static let sentenceImprovementTaskID = "task14"
    static let conversationEntryCountTaskIDs: Set<String> = ["task9", "task10", "task11"]
    static let conversationEntryCountOptions = [25, 50, 100]
    static let defaultConversationEntryCount = 25

    static func defaultSubjectType(forTaskID taskID: String) -> PromptTaskSubjectType {
        if taskID == defaultSentenceTaskID || taskID == sentenceImprovementTaskID { return .sentence }
        if collectionTaskIDs.contains(taskID) { return .page }
        if practiceTopicTaskIDs.contains(taskID) { return .practiceTopic }
        return .characterPhrase
    }

    static func normalizedConversationEntryCount(_ value: Int) -> Int {
        conversationEntryCountOptions.contains(value) ? value : defaultConversationEntryCount
    }

    static var defaultSelectedTaskIDs: [String] {
        streamlitDefault.tasks
            .filter { $0.subjectType == .characterPhrase }
            .map(\.id)
    }

    init(
        version: Int,
        preamble: String,
        tasks: [PromptTask],
        epilogue: String,
        collectionPreamble: String = "",
        collectionEpilogue: String = ""
    ) {
        self.version = version
        self.preamble = preamble
        self.tasks = tasks
        self.epilogue = epilogue
        self.collectionPreamble = collectionPreamble
        self.collectionEpilogue = collectionEpilogue.isEmpty ? PromptConfig.defaultCollectionEpilogue : collectionEpilogue
    }

    private enum CodingKeys: String, CodingKey {
        case version, preamble, tasks, epilogue, collectionPreamble, collectionEpilogue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        preamble = try container.decode(String.self, forKey: .preamble)
        tasks = try container.decode([PromptTask].self, forKey: .tasks)
        epilogue = try container.decode(String.self, forKey: .epilogue)
        collectionPreamble = try container.decodeIfPresent(String.self, forKey: .collectionPreamble) ?? ""
        collectionEpilogue = try container.decodeIfPresent(String.self, forKey: .collectionEpilogue) ?? PromptConfig.defaultCollectionEpilogue
    }

}

struct PromptRenderContext {
    let char: String
    let definitionEN: String
    let decomposition: String
    let semantic: String
    let phonetic: String
    let phoneticPinyin: String
    let isSoundMatch: String
    let pronunciationFamily: String
    let semanticFamily: String
    let collectionName: String
    let captureCharacters: String
    let captureText: String
    let originalOCRText: String
    let recognizedOCRCharacters: String
    let unrecognizedOCRCharacters: String
    let nearbyOCRPhrases: String
    let practiceTopicID: String
    let practiceTopicTitle: String
    let practiceTopicSummary: String
    let practiceTopicBrief: String
    let practiceTopicSituations: String
    let sentenceChinese: String
    let sentencePinyin: String
    let sentenceEnglish: String
    let sentencePhrases: String
    let sentenceCharacters: String
    let conversationEntryCount: String
    let sentenceExtractionDetail: String

    init(
        char: String,
        definitionEN: String,
        decomposition: String,
        semantic: String,
        phonetic: String,
        phoneticPinyin: String,
        isSoundMatch: String,
        pronunciationFamily: String,
        semanticFamily: String,
        collectionName: String,
        captureCharacters: String,
        captureText: String,
        originalOCRText: String,
        recognizedOCRCharacters: String,
        unrecognizedOCRCharacters: String,
        nearbyOCRPhrases: String,
        practiceTopicID: String,
        practiceTopicTitle: String,
        practiceTopicSummary: String,
        practiceTopicBrief: String,
        practiceTopicSituations: String,
        sentenceChinese: String = "",
        sentencePinyin: String = "",
        sentenceEnglish: String = "",
        sentencePhrases: String = "",
        sentenceCharacters: String = "",
        conversationEntryCount: String,
        sentenceExtractionDetail: String
    ) {
        self.char = char
        self.definitionEN = definitionEN
        self.decomposition = decomposition
        self.semantic = semantic
        self.phonetic = phonetic
        self.phoneticPinyin = phoneticPinyin
        self.isSoundMatch = isSoundMatch
        self.pronunciationFamily = pronunciationFamily
        self.semanticFamily = semanticFamily
        self.collectionName = collectionName
        self.captureCharacters = captureCharacters
        self.captureText = captureText
        self.originalOCRText = originalOCRText
        self.recognizedOCRCharacters = recognizedOCRCharacters
        self.unrecognizedOCRCharacters = unrecognizedOCRCharacters
        self.nearbyOCRPhrases = nearbyOCRPhrases
        self.practiceTopicID = practiceTopicID
        self.practiceTopicTitle = practiceTopicTitle
        self.practiceTopicSummary = practiceTopicSummary
        self.practiceTopicBrief = practiceTopicBrief
        self.practiceTopicSituations = practiceTopicSituations
        self.sentenceChinese = sentenceChinese
        self.sentencePinyin = sentencePinyin
        self.sentenceEnglish = sentenceEnglish
        self.sentencePhrases = sentencePhrases
        self.sentenceCharacters = sentenceCharacters
        self.conversationEntryCount = conversationEntryCount
        self.sentenceExtractionDetail = sentenceExtractionDetail
    }
}
