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

struct OCRReviewProposal: Equatable {
    let correctedText: String
    let changes: String
    let uncertainties: String
}

enum OCRReviewParser {
    static func parse(_ response: String) -> OCRReviewProposal? {
        let corrected = section("CORRECTED TEXT", in: response)
        guard !corrected.isEmpty else { return nil }
        return OCRReviewProposal(
            correctedText: corrected,
            changes: section("CHANGES", in: response),
            uncertainties: section("UNCERTAIN", in: response)
        )
    }

    private static func section(_ name: String, in response: String) -> String {
        let marker = "[[\(name)]]"
        guard let start = response.range(of: marker) else { return "" }
        let remaining = response[start.upperBound...]
        let end = remaining.range(of: "[[")?.lowerBound ?? response.endIndex
        return response[start.upperBound..<end]
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum AIImageOCRTextParser {
    static func parse(_ response: String) -> String {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        if let section = markedSection("OCR TEXT", in: trimmed), !section.isEmpty {
            return section
        }

        return trimmed
            .replacingOccurrences(of: "```text", with: "")
            .replacingOccurrences(of: "```markdown", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func markedSection(_ name: String, in response: String) -> String? {
        let marker = "[[\(name)]]"
        guard let start = response.range(of: marker) else { return nil }
        let remaining = response[start.upperBound...]
        let end = remaining.range(of: "[[")?.lowerBound ?? response.endIndex
        return response[start.upperBound..<end]
            .trimmingCharacters(in: .whitespacesAndNewlines)
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

    /// Returns all Chinese characters in reading order, including duplicates.
    static func allCharactersInOrder(in text: String) -> [String] {
        text.unicodeScalars
            .filter { isChineseScalar($0) }
            .map { String(Character($0)) }
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
