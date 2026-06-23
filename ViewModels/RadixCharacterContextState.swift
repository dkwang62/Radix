import Foundation

/// Data assembled around the currently selected character.
struct RadixCharacterContextState {
    var relatedCharacters: [ComponentItem] = []
    var phrases: [PhraseItem] = []
    var phraseLength: Int?
    var sharedComponentPeers: [ComponentItem] = []
    var sharedPeersByComponent: [String: [ComponentItem]] = [:]
}
