import Foundation

// Browse page phrases are explicit user-visible tiles. Keep these as plain data
// models so page phrase selection does not grow hidden preview behaviour again.
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
