import Foundation

struct ImagePhraseContext: Equatable {
    let collectionID: UUID
    let target: String
    let offset: Int
}

struct BrowseImagePhraseTileData {
    let phrase: PhraseItem
    let start: Int
    let end: Int

    var offsets: [Int] {
        Array(start..<end)
    }
}

struct BrowsePagePhraseCandidate: Identifiable, Hashable {
    let phrase: PhraseItem
    let firstStart: Int
    let occurrenceCount: Int

    var id: String { phrase.word }
}

enum ImagePhraseMatcher {
    static func cacheKey(character: String, lengthKey: String, context: ImagePhraseContext?) -> String {
        guard let context else { return "\(character)|\(lengthKey)" }
        return "\(character)|\(lengthKey)|image|\(context.collectionID.uuidString)|\(context.offset)"
    }
}
