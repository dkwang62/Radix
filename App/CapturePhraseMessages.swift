import Foundation

enum CaptureStatusText {
    static let noChineseCharactersFound = "No Chinese characters found. You can edit the fields manually."
    static let noChineseCharactersToRead = "No Chinese characters to read."
    static func savedCollection(name: String, characterCount: Int) -> String {
        "Saved \(name) with \(characterCount) characters."
    }

    static func readingCharacters(count: Int) -> String {
        "Reading \(count) character\(count == 1 ? "" : "s") aloud."
    }

    static func removedPhrase(_ phrase: String) -> String {
        "Removed \(phrase) from My Phrases."
    }
}
