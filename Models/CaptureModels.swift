import Foundation

struct CaptureItem: Identifiable, Hashable, Codable {
    let id: UUID
    let createdAt: Date
    let rawText: String
    let characters: [String]
    let phrases: [String]
    let notes: String

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        rawText: String,
        characters: [String],
        phrases: [String],
        notes: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.rawText = rawText
        self.characters = CaptureTextExtractor.uniqueCharacters(in: characters.joined())
        self.phrases = CaptureTextExtractor.uniquePhrases(from: phrases)
        self.notes = notes
    }

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case rawText = "raw_text"
        case characters
        case phrases
        case notes
    }
}

enum CaptureTextExtractor {
    static func uniqueCharacters(in text: String) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for scalar in text.unicodeScalars where isChineseScalar(scalar) {
            let character = String(Character(scalar))
            if seen.insert(character).inserted {
                result.append(character)
            }
        }
        return result
    }

    static func uniquePhrases(in text: String) -> [String] {
        let candidates = text
            .components(separatedBy: CharacterSet.whitespacesAndNewlines)
            .flatMap { segment in
                segment.split { character in
                    character.unicodeScalars.allSatisfy { !isChineseScalar($0) }
                }
            }
            .map(String.init)
        return uniquePhrases(from: candidates)
    }

    static func uniquePhrases(from candidates: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for candidate in candidates {
            let cleaned = candidate.filter { character in
                character.unicodeScalars.contains(where: isChineseScalar)
            }
            guard cleaned.count >= 2, seen.insert(cleaned).inserted else { continue }
            result.append(cleaned)
        }
        return result
    }

    private static func isChineseScalar(_ scalar: UnicodeScalar) -> Bool {
        (0x4E00...0x9FFF).contains(Int(scalar.value))
    }
}
