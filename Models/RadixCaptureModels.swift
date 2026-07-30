import Foundation

public struct RadixCapturePayload: Decodable, Equatable, Sendable {
    public let source: RadixCaptureSourceDraft?
    public let sentenceExamples: [RadixCaptureSentenceDraft]

    enum CodingKeys: String, CodingKey {
        case source
        case sentences
        case sentenceExamples = "sentence_examples"
    }

    public init(
        source: RadixCaptureSourceDraft? = nil,
        sentenceExamples: [RadixCaptureSentenceDraft]
    ) {
        self.source = source
        self.sentenceExamples = sentenceExamples
    }

    public init(from decoder: Decoder) throws {
        if var unkeyedContainer = try? decoder.unkeyedContainer() {
            var drafts: [RadixCaptureSentenceDraft] = []
            while !unkeyedContainer.isAtEnd {
                drafts.append(try unkeyedContainer.decode(RadixCaptureSentenceDraft.self))
            }
            source = nil
            sentenceExamples = drafts
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        source = try container.decodeIfPresent(RadixCaptureSourceDraft.self, forKey: .source)
        sentenceExamples = try container.decodeIfPresent([RadixCaptureSentenceDraft].self, forKey: .sentenceExamples)
            ?? container.decodeIfPresent([RadixCaptureSentenceDraft].self, forKey: .sentences)
            ?? []
    }

    public func sentenceRecords(createdAt: Date = Date()) -> [SentenceExampleRecord] {
        sentenceExamples.compactMap {
            $0.sentenceRecord(defaultSource: source, createdAt: createdAt)
        }
    }
}

public struct RadixCaptureSourceDraft: Codable, Equatable, Sendable {
    public let sourceType: SentenceExampleSourceType?
    public let sourceID: String?
    public let sourceTitle: String?
    public let sourcePageID: UUID?
    public let practicePackID: String?
    public let practiceItemID: String?

    enum CodingKeys: String, CodingKey {
        case sourceType = "source_type"
        case sourceID = "source_id"
        case sourceTitle = "source_title"
        case sourcePageID = "source_page_id"
        case practicePackID = "practice_pack_id"
        case practiceItemID = "practice_item_id"
    }

    public init(
        sourceType: SentenceExampleSourceType? = nil,
        sourceID: String? = nil,
        sourceTitle: String? = nil,
        sourcePageID: UUID? = nil,
        practicePackID: String? = nil,
        practiceItemID: String? = nil
    ) {
        self.sourceType = sourceType
        self.sourceID = sourceID
        self.sourceTitle = sourceTitle
        self.sourcePageID = sourcePageID
        self.practicePackID = practicePackID
        self.practiceItemID = practiceItemID
    }

    func sourceReference(fallbackType: SentenceExampleSourceType = .aiGenerated) -> SentenceExampleSourceReference {
        SentenceExampleSourceReference(
            sourceType: sourceType ?? fallbackType,
            sourceID: sourceID,
            sourceTitle: sourceTitle,
            sourcePageID: sourcePageID,
            practicePackID: practicePackID,
            practiceItemID: practiceItemID
        )
    }
}

public struct RadixCaptureSentenceDraft: Decodable, Equatable, Sendable {
    public let chinese: String
    public let script: SentenceExampleScript?
    public let pinyin: String?
    public let english: String?
    public let source: RadixCaptureSourceDraft?
    public let characters: [String]
    public let phrases: [String]
    public let grammarPoints: [String]
    public let hskLevel: Int?
    public let difficulty: SentenceExampleDifficulty?
    public let naturalness: String?
    public let isFavorited: Bool
    public let isHidden: Bool
    public let qualityScore: Double?
    public let notes: String
    public let tags: [String]

    enum CodingKeys: String, CodingKey {
        case zh
        case chinese
        case script
        case pinyin
        case en
        case english
        case source
        case characters
        case targetCharacters = "target_characters"
        case phrases
        case targetPhrases = "target_phrases"
        case grammarPoints = "grammar_points"
        case hskLevel = "hsk_level"
        case difficulty
        case naturalness
        case isFavorited = "is_favorited"
        case isHidden = "is_hidden"
        case qualityScore = "quality_score"
        case notes
        case tags
    }

    public init(
        chinese: String,
        script: SentenceExampleScript? = nil,
        pinyin: String? = nil,
        english: String? = nil,
        source: RadixCaptureSourceDraft? = nil,
        characters: [String] = [],
        phrases: [String] = [],
        grammarPoints: [String] = [],
        hskLevel: Int? = nil,
        difficulty: SentenceExampleDifficulty? = nil,
        naturalness: String? = nil,
        isFavorited: Bool = false,
        isHidden: Bool = false,
        qualityScore: Double? = nil,
        notes: String = "",
        tags: [String] = []
    ) {
        self.chinese = chinese
        self.script = script
        self.pinyin = pinyin
        self.english = english
        self.source = source
        self.characters = characters
        self.phrases = phrases
        self.grammarPoints = grammarPoints
        self.hskLevel = hskLevel
        self.difficulty = difficulty
        self.naturalness = naturalness
        self.isFavorited = isFavorited
        self.isHidden = isHidden
        self.qualityScore = qualityScore
        self.notes = notes
        self.tags = tags
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        chinese = try container.decodeIfPresent(String.self, forKey: .chinese)
            ?? container.decodeIfPresent(String.self, forKey: .zh)
            ?? ""
        script = try container.decodeIfPresent(SentenceExampleScript.self, forKey: .script)
        pinyin = try container.decodeIfPresent(String.self, forKey: .pinyin)
        english = try container.decodeIfPresent(String.self, forKey: .english)
            ?? container.decodeIfPresent(String.self, forKey: .en)
        source = try container.decodeIfPresent(RadixCaptureSourceDraft.self, forKey: .source)
        characters = try container.decodeIfPresent([String].self, forKey: .characters)
            ?? container.decodeIfPresent([String].self, forKey: .targetCharacters)
            ?? []
        phrases = try container.decodeIfPresent([String].self, forKey: .phrases)
            ?? container.decodeIfPresent([String].self, forKey: .targetPhrases)
            ?? []
        grammarPoints = try container.decodeIfPresent([String].self, forKey: .grammarPoints) ?? []
        hskLevel = try container.decodeIfPresent(Int.self, forKey: .hskLevel)
        difficulty = try container.decodeIfPresent(SentenceExampleDifficulty.self, forKey: .difficulty)
        naturalness = try container.decodeIfPresent(String.self, forKey: .naturalness)
        isFavorited = try container.decodeIfPresent(Bool.self, forKey: .isFavorited) ?? false
        isHidden = try container.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false
        qualityScore = try container.decodeIfPresent(Double.self, forKey: .qualityScore)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
    }

    public func sentenceRecord(
        defaultSource: RadixCaptureSourceDraft?,
        createdAt: Date = Date()
    ) -> SentenceExampleRecord? {
        let trimmedChinese = chinese.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedChinese.isEmpty else { return nil }
        let sourceReference = (source ?? defaultSource)?.sourceReference(fallbackType: .aiGenerated)
        return SentenceExampleRecord(
            chinese: trimmedChinese,
            script: script ?? .unknown,
            pinyin: pinyin,
            english: english,
            sources: sourceReference.map { [$0] } ?? [],
            targetCharacters: characters,
            targetPhrases: phrases,
            detectedCharacters: SentenceExampleRecord.detectChineseCharacters(in: trimmedChinese),
            detectedPhrases: phrases,
            grammarPoints: grammarPoints,
            hskLevel: hskLevel,
            difficulty: difficulty ?? .unknown,
            naturalness: naturalness,
            createdAt: createdAt,
            isFavorited: isFavorited,
            isHidden: isHidden,
            qualityScore: qualityScore ?? (isFavorited ? 2 : 0),
            notes: notes,
            tags: tags
        )
    }
}

public enum RadixCaptureJSONParser {
    private static let startMarker = "[Radix Capture JSON]"
    private static let endMarker = "[/Radix Capture JSON]"

    public static func captureJSONCandidates(from text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var candidates: [String] = []
        var searchRange = trimmed.startIndex..<trimmed.endIndex
        while let startRange = trimmed.range(
            of: startMarker,
            options: [.caseInsensitive],
            range: searchRange
        ) {
            let bodyStart = startRange.upperBound
            let endRange = trimmed.range(
                of: endMarker,
                options: [.caseInsensitive],
                range: bodyStart..<trimmed.endIndex
            )
            let bodyEnd = endRange?.lowerBound ?? trimmed.endIndex
            appendJSONCandidates(from: String(trimmed[bodyStart..<bodyEnd]), to: &candidates)
            guard let endRange else { break }
            searchRange = endRange.upperBound..<trimmed.endIndex
        }

        if candidates.isEmpty {
            appendJSONCandidates(from: trimmed, to: &candidates)
        }

        var seen = Set<String>()
        return candidates.filter { candidate in
            guard !seen.contains(candidate) else { return false }
            seen.insert(candidate)
            return true
        }
    }

    public static func payloads(from text: String) -> [RadixCapturePayload] {
        let decoder = JSONDecoder()
        return captureJSONCandidates(from: text).compactMap { candidate in
            try? decoder.decode(RadixCapturePayload.self, from: Data(candidate.utf8))
        }
    }

    public static func sentenceExamples(from text: String, createdAt: Date = Date()) -> [SentenceExampleRecord] {
        let records = payloads(from: text).flatMap {
            $0.sentenceRecords(createdAt: createdAt)
        }
        return SentenceExampleRecord.upserting(records, into: [])
    }

    private static func appendJSONCandidates(from text: String, to candidates: inout [String]) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        candidates.append(trimmed)

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

        if let object = jsonSubstring(in: trimmed, opening: "{", closing: "}") {
            candidates.append(object)
        }
        if let array = jsonSubstring(in: trimmed, opening: "[", closing: "]") {
            candidates.append(array)
        }
    }

    private static func jsonSubstring(in text: String, opening: Character, closing: Character) -> String? {
        guard let first = text.firstIndex(of: opening),
              let last = text.lastIndex(of: closing),
              first < last
        else {
            return nil
        }
        return String(text[first...last]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
