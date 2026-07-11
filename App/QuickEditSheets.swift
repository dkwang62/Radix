import SwiftUI

struct QuickEditSheet: View {
    let destination: QuickEditDestination

    var body: some View {
        switch destination {
        case .character(let character):
            QuickCharacterEditorView(character: character, isNew: false)
        case .newCharacter:
            QuickCharacterEditorView(character: "", isNew: true)
        case .phrase(let word):
            QuickPhraseEditorView(word: word, isNew: false)
        case .newPhrase(let phrase):
            QuickPhraseEditorView(word: phrase, isNew: true)
        }
    }
}
