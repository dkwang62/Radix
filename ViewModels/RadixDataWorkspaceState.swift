import Foundation

/// Runtime status and file locations for the editable user-data workspace.
struct RadixDataWorkspaceState {
    var addedPhrases: [PhraseItem] = []
    var addedPhraseReviewPhrases: [PhraseItem] = []
    var loadingError: String?
    var dictionaryOverlayPath = ""
    var addedPhrasesDatabasePath = ""
}
