import SwiftUI

extension DataEditTab {
    var addedPhraseEntries: [PhraseItem] {
        changedPhraseEntries.filter { !store.isPhraseInBase($0.word) && $0.isActivePhrase }
    }

    var phraseEntriesWithNotes: [PhraseItem] {
        changedPhraseEntries.filter { !$0.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var basePhraseCoreEditEntries: [PhraseItem] {
        changedPhraseEntries.filter { store.isBasePhraseCoreEdited($0) }
    }

    var changedPhraseEntries: [PhraseItem] {
        var merged: [PhraseItem] = []
        for phrase in store.addedPhrases + store.dataEditPhrases {
            if let index = merged.firstIndex(where: { $0.word == phrase.word }) {
                merged[index] = phrase
            } else {
                merged.append(phrase)
            }
        }
        return merged
    }

    var activeCharacterContext: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let current = store.previewCharacter {
                standardPhoneCharacterPreview(
                    character: current,
                    onClear: { store.previewCharacter = nil }
                )
            }
        }
    }
}
