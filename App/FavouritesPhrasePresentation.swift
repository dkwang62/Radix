import SwiftUI

extension FavouritesTab {
    func presentPhrase(_ phrase: PhraseItem) {
        store.speakPhrase(phrase)
        if isPhone {
            store.presentPhraseInSidebar(phrase)
            selectedPhrase = nil
        } else {
            selectedPhrase = nil
            store.presentPhraseInSidebar(phrase)
        }
    }

    var phonePhraseSheetBinding: Binding<PhraseItem?> {
        Binding(
            get: { nil },
            set: { newValue in
                if isPhone {
                    selectedPhrase = newValue
                }
            }
        )
    }
}
