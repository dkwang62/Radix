import Foundation

/// User-facing search session state. Search execution and repository-backed
/// results remain coordinated by `RadixStore`.
struct RadixSearchState: Equatable {
    var query = ""
    var mode: SearchMode = .smart
    var scriptFilter: ScriptFilter = .any
    var hasPerformedSearch = false
    var lastQuery = ""
    var history: [String] = []
}

/// Repository-produced results for the active search. Keeping these separate
/// from the user's search session makes result production replaceable without
/// changing navigation or input state.
struct RadixSearchResults {
    var characters: [ComponentItem] = []
    var phrases: [PhraseItem] = []
    var definitionCharacters: [ComponentItem] = []
    var definitionPhrases: [PhraseItem] = []
}
