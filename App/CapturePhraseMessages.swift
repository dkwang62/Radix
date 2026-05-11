import Foundation

enum CapturePhrasePromptLaunchMessage {
    static func opening(defaultAIName: String, prefillsPrompt: Bool) -> String {
        prefillsPrompt
            ? "Opening \(defaultAIName) in 3 seconds. Copy its answer, then come back and tap Add Phrases."
            : "Opening \(defaultAIName) in 3 seconds. The prompt was copied, so paste it into \(defaultAIName), then come back and tap Add Phrases."
    }
}

enum CaptureStatusText {
    static let noChineseCharactersFound = "No Chinese characters found. You can edit the fields manually."
    static let noChineseCharactersToRead = "No Chinese characters to read."
    static let clipboardIsEmpty = "Clipboard is empty."

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

enum PhraseDiscoveryPreviewMessage {
    static func message(candidateCount: Int) -> String {
        candidateCount == 0
            ? "Radix could not read any phrases from that answer."
            : "Radix found \(candidateCount) phrase\(candidateCount == 1 ? "" : "s"). You can edit the list, then tap Add Selected to My Phrases."
    }
}

enum CaptureBrowseTargetResolver {
    static func targetID(
        lastSavedCollectionID: UUID?,
        selectedBrowseCollectionID: UUID?,
        collections: [CharacterCollection]
    ) -> UUID? {
        lastSavedCollectionID ?? selectedBrowseCollectionID ?? collections.first?.id
    }
}

enum CaptureCollectionName {
    static func ocrImageName(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ddMMyy HHmm"
        return formatter.string(from: date)
    }

    static func pastedName(_ name: String, date: Date = Date()) -> String {
        name.isEmpty ? "Pasted \(date.formatted(date: .numeric, time: .shortened))" : name
    }
}
