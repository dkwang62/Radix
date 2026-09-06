import Foundation
import ImageIO

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

struct CaptureCharacterValidation: Equatable {
    let charactersInReadingOrder: [String]
    let uniqueCharacters: [String]
    let dictionarySupportedCharacters: [String]
    let dictionaryUnsupportedCharacters: [String]

    var hasChineseCharacters: Bool {
        !charactersInReadingOrder.isEmpty
    }
}

enum CaptureImageOrientationMetadata {
    static func orientation(in data: Data) -> CGImagePropertyOrientation {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let rawValue = properties[kCGImagePropertyOrientation] as? NSNumber,
              let orientation = CGImagePropertyOrientation(rawValue: rawValue.uint32Value) else {
            return .up
        }
        return orientation
    }
}

enum CaptureImageResourceViolation: Equatable {
    case encodedBytes
    case pixels
}

enum CaptureImageResourceBudget {
    static let maximumEncodedByteCount = 64 * 1_024 * 1_024
    static let maximumPixelCount = 64_000_000
    static let maximumRecognitionDimension = 3_072

    static func violation(
        encodedByteCount: Int,
        pixelWidth: Int,
        pixelHeight: Int
    ) -> CaptureImageResourceViolation? {
        if encodedByteCount > maximumEncodedByteCount {
            return .encodedBytes
        }
        guard pixelWidth > 0, pixelHeight > 0 else { return nil }
        if pixelWidth > maximumPixelCount / pixelHeight {
            return .pixels
        }
        return nil
    }

    static func requiresDownsampling(pixelWidth: Int, pixelHeight: Int) -> Bool {
        max(pixelWidth, pixelHeight) > maximumRecognitionDimension
    }
}

enum CaptureLocalOCRResult: Equatable {
    case recognized(String)
    case noText
    case nonChineseText(String)
    case failed(String)

    var userMessage: String {
        switch self {
        case .recognized:
            "Apple Vision found Chinese text."
        case .noText:
            "Apple Vision found no readable text in this image."
        case .nonChineseText:
            "Apple Vision found text, but no Chinese characters."
        case .failed(let message):
            "Apple Vision could not process this image: \(message)"
        }
    }
}

enum CaptureLocalOCRClassifier {
    static func classify(_ text: String) -> CaptureLocalOCRResult {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .noText
        }
        guard !CaptureTextExtractor.allCharactersInOrder(in: text).isEmpty else {
            return .nonChineseText(text)
        }
        return .recognized(text)
    }
}

enum CaptureImageRecognitionMethod: Equatable {
    case appleVision
    case gemini
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
        uniqueValues(in: allCharactersInOrder(in: text))
    }

    /// Returns all Chinese characters in reading order, including duplicates.
    static func allCharactersInOrder(in text: String) -> [String] {
        text.unicodeScalars
            .filter { isChineseScalar($0) }
            .map { String(Character($0)) }
    }

    static func characterValidation(
        in text: String,
        dictionaryContains: (String) -> Bool
    ) -> CaptureCharacterValidation {
        let characters = allCharactersInOrder(in: text)
        let uniqueCharacters = uniqueValues(in: characters)
        return CaptureCharacterValidation(
            charactersInReadingOrder: characters,
            uniqueCharacters: uniqueCharacters,
            dictionarySupportedCharacters: uniqueCharacters.filter(dictionaryContains),
            dictionaryUnsupportedCharacters: uniqueCharacters.filter { !dictionaryContains($0) }
        )
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
        scalar.properties.isIdeographic
    }

    private static func uniqueValues(in values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}
