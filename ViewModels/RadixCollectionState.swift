import Foundation

/// Saved pages and their independent Browse and AI Link selections.
struct RadixCollectionState {
    var collections: [CharacterCollection] = []
    var selectedBrowseCollectionID: UUID?
    var selectedAICollectionID: UUID?
}
