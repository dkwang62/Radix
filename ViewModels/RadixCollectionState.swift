import Foundation

/// Saved pages and their independent Browse and AI Link selections.
struct RadixCollectionState {
    var collections: [CharacterCollection] = []
    var selectedBrowseCollectionID: UUID?
    var selectedAICollectionID: UUID?
}

extension RadixStore {
    var allCollections: [CharacterCollection] {
        get { collectionState.collections }
        set { collectionState.collections = newValue }
    }

    var selectedBrowseCollectionID: UUID? {
        get { collectionState.selectedBrowseCollectionID }
        set {
            guard collectionState.selectedBrowseCollectionID != newValue else { return }
            collectionState.selectedBrowseCollectionID = newValue
            selectedBrowseCollectionCharacters = newValue.flatMap {
                collection(id: $0).map { Set($0.characters) }
            }
            clearBrowseMemoryHighlight()
            if newValue != nil {
                browseHighlightedCharacter = nil
            }
            if let selectedBrowseCollection {
                activeSubject = .collection(selectedBrowseCollection)
            } else if case .collection = activeSubject {
                activeSubject = nil
            }
            gridPage = 0
            scheduleGridRecompute()
        }
    }

    var selectedAICollectionID: UUID? {
        get { collectionState.selectedAICollectionID }
        set {
            guard collectionState.selectedAICollectionID != newValue else { return }
            collectionState.selectedAICollectionID = newValue
            persistSelectedAICollection()
        }
    }
}
