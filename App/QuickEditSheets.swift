import SwiftUI

enum QuickEditorManagementAction {
    case delete
    case revert

    func title(for subject: String) -> String {
        "\(confirmationTitle) \(subject)?"
    }

    var confirmationTitle: String {
        switch self {
        case .delete: "Delete"
        case .revert: "Revert"
        }
    }
}

struct QuickEditSheet: View {
    let destination: QuickEditDestination

    var body: some View {
        switch destination {
        case .character(let character):
            QuickCharacterEditorView(character: character, isNew: false)
                .presentationDetents([.large])
        case .newCharacter:
            QuickCharacterEditorView(character: "", isNew: true)
                .presentationDetents([.large])
        case .phrase(let word):
            QuickPhraseEditorView(word: word, isNew: false)
                .presentationDetents([.medium, .large])
        case .newPhrase(let phrase):
            AddPhraseSheet(initialWord: phrase)
                .presentationDetents([.medium, .large])
        }
    }
}
