import Foundation

struct CaptureDraft: Hashable {
    var rawText: String
    var charactersText: String
    var phrasesText: String

    init(rawText: String = "", charactersText: String = "", phrasesText: String = "") {
        self.rawText = rawText
        self.charactersText = charactersText
        self.phrasesText = phrasesText
    }

    var isEmpty: Bool {
        rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        charactersText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        phrasesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
            guard (2...4).contains(cleaned.count), seen.insert(cleaned).inserted else { continue }
            result.append(cleaned)
        }
        return result
    }

    private static func isChineseScalar(_ scalar: UnicodeScalar) -> Bool {
        (0x4E00...0x9FFF).contains(Int(scalar.value))
    }
}
