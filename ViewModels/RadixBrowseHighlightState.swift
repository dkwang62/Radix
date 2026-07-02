import Foundation

/// Phrase, character, and scroll highlighting state for saved-page Browse grids.
struct RadixBrowseHighlightState {
    var phraseContext: ImagePhraseContext?
    var phraseOffsets: Set<Int> = []
    var anchoredPhraseContext: ImagePhraseContext?
    var anchoredPhraseOffsets: Set<Int> = []
    var anchoredPhraseWord: String?
    var anchoredCollectionID: UUID?
    var revision = 0
    var imagePhrasePreview: PhraseItem?
    var sidebarPhrasePreview: PhraseItem?
    var sidebarPhraseLookupOverride: [PhraseItem]?
    var sidebarPracticeSentenceItem: ConversationPracticeItem?
    var pendingScrollTarget: BrowseScrollTarget?
    var highlightedCharacter: String?
    var memoryCollectionID: UUID?
    var memoryOffsets: Set<Int> = []
    var memoryHighlightedItem: String?
}

extension RadixStore {
    var imagePhraseContext: ImagePhraseContext? {
        get { browseHighlightState.phraseContext }
        set { browseHighlightState.phraseContext = newValue }
    }

    var imagePhraseHighlightOffsets: Set<Int> {
        get { browseHighlightState.phraseOffsets }
        set { browseHighlightState.phraseOffsets = newValue }
    }

    // This store-level anchor restores the original phrase highlight after an
    // iPhone phrase preview drills into one of its component characters.
    var anchoredImagePhraseContext: ImagePhraseContext? {
        get { browseHighlightState.anchoredPhraseContext }
        set { browseHighlightState.anchoredPhraseContext = newValue }
    }

    var anchoredImagePhraseHighlightOffsets: Set<Int> {
        get { browseHighlightState.anchoredPhraseOffsets }
        set { browseHighlightState.anchoredPhraseOffsets = newValue }
    }

    var anchoredImagePhraseWord: String? {
        get { browseHighlightState.anchoredPhraseWord }
        set { browseHighlightState.anchoredPhraseWord = newValue }
    }

    var anchoredImagePhraseCollectionID: UUID? {
        get { browseHighlightState.anchoredCollectionID }
        set { browseHighlightState.anchoredCollectionID = newValue }
    }

    var imagePhraseHighlightRevision: Int {
        get { browseHighlightState.revision }
        set { browseHighlightState.revision = newValue }
    }

    var imageBrowsePhrasePreview: PhraseItem? {
        get { browseHighlightState.imagePhrasePreview }
        set { browseHighlightState.imagePhrasePreview = newValue }
    }

    var sidebarPhrasePreview: PhraseItem? {
        get { browseHighlightState.sidebarPhrasePreview }
        set {
            browseHighlightState.sidebarPhrasePreview = newValue
            if newValue == nil {
                browseHighlightState.sidebarPhraseLookupOverride = nil
                browseHighlightState.sidebarPracticeSentenceItem = nil
            }
        }
    }

    var sidebarPhraseLookupOverride: [PhraseItem]? {
        get { browseHighlightState.sidebarPhraseLookupOverride }
        set { browseHighlightState.sidebarPhraseLookupOverride = newValue }
    }

    var activePracticeSentenceItem: ConversationPracticeItem? {
        get { browseHighlightState.sidebarPracticeSentenceItem }
        set { browseHighlightState.sidebarPracticeSentenceItem = newValue }
    }

    var pendingBrowseScrollTarget: BrowseScrollTarget? {
        get { browseHighlightState.pendingScrollTarget }
        set { browseHighlightState.pendingScrollTarget = newValue }
    }

    var browseHighlightedCharacter: String? {
        get { browseHighlightState.highlightedCharacter }
        set { browseHighlightState.highlightedCharacter = newValue }
    }

    var browseMemoryHighlightCollectionID: UUID? {
        get { browseHighlightState.memoryCollectionID }
        set { browseHighlightState.memoryCollectionID = newValue }
    }

    var browseMemoryHighlightOffsets: Set<Int> {
        get { browseHighlightState.memoryOffsets }
        set { browseHighlightState.memoryOffsets = newValue }
    }

    var browseMemoryHighlightedItem: String? {
        get { browseHighlightState.memoryHighlightedItem }
        set { browseHighlightState.memoryHighlightedItem = newValue }
    }
}
