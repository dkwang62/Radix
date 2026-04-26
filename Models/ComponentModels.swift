import Foundation

struct ComponentStructureAnalysis: Hashable {
    let semantic: String?
    let phonetic: String?
    let phoneticPinyin: String?
    let isSoundMatch: Bool
}

struct ComponentItem: Identifiable, Hashable {
    let id: String
    let character: String
    let variant: String?
    let additionalVariants: [String]
    let pinyin: [String]
    let definition: String
    let decomposition: String
    let radical: String
    let strokes: Int?
    let relatedCharacters: [String]
    let etymologyHint: String
    let etymologyDetails: String
    let notes: String
    let usageCount: Int
    let freqPerMillion: Double
    let rank: Int?
    let tier: Int

    /// All script variants in order: primary variant first, then additional variants.
    var allVariants: [String] {
        var result: [String] = []
        if let v = variant { result.append(v) }
        for v in additionalVariants where !result.contains(v) { result.append(v) }
        return result
    }

    var pinyinText: String { pinyin.joined(separator: ", ") }
    var searchableText: String {
        [character, pinyinText, definition, decomposition, radical, etymologyHint, etymologyDetails, notes]
            .joined(separator: " ")
            .lowercased()
    }
}

struct CharacterCollection: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var characters: Set<String>
    var createdAt: Date
    var sourceType: CollectionSourceType
    var isFavorite: Bool
}

enum CollectionSourceType: String, Codable, Hashable {
    case ocr
    case manual
    case imported
    case other
}

enum ActiveSubject: Equatable {
    case character(String)
    case collection(CharacterCollection)
}

struct RawComponentEntry: Codable, Equatable {
    let relatedCharacters: [String]
    let meta: RawMeta

    enum CodingKeys: String, CodingKey {
        case relatedCharacters = "related_characters"
        case meta
    }
}

struct RawMeta: Codable, Equatable {
    let variant: String?
    let additionalVariants: [String]?
    let pinyin: StringOrMany?
    let definition: String?
    let decomposition: String?
    let idc: String?
    let radical: String?
    let strokes: IntOrString?
    let compounds: StringOrMany?
    let etymology: RawEtymology?
    let notes: StringOrMany?

    enum CodingKeys: String, CodingKey {
        case variant, pinyin, definition, decomposition, radical, strokes, compounds, etymology, notes
        case additionalVariants = "additional_variants"
        case idc = "IDC"
    }
}

struct RawEtymology: Codable, Equatable {
    let type: String?
    let hint: StringOrMany?
    let details: StringOrMany?
}

enum StringOrMany: Codable, Equatable {
    case single(String)
    case many([String])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .single(value)
            return
        }
        if let values = try? container.decode([String].self) {
            self = .many(values)
            return
        }
        self = .single("")
    }

    var list: [String] {
        switch self {
        case .single(let value):
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? [] : [trimmed]
        case .many(let values):
            return values
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
    }

    var text: String { list.joined(separator: " ") }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .single(let value):
            try container.encode(value)
        case .many(let values):
            try container.encode(values)
        }
    }
}

enum IntOrString: Codable, Equatable {
    case int(Int)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Int.self) {
            self = .int(value)
            return
        }
        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }
        self = .string("")
    }

    var intValue: Int? {
        switch self {
        case .int(let value):
            return value
        case .string(let value):
            return Int(value)
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        }
    }
}

struct DictionaryVariance: Identifiable {
    enum VarianceType: String {
        case added = "Added (Custom)"
        case missing = "Missing from Studio"
    }
    
    var id: String { character }
    let character: String
    let type: VarianceType
}
