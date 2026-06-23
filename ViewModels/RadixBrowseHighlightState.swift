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
    var pendingScrollTarget: BrowseScrollTarget?
    var highlightedCharacter: String?
    var memoryCollectionID: UUID?
    var memoryOffsets: Set<Int> = []
    var memoryHighlightedItem: String?
}
