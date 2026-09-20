import SwiftUI

extension DataEditTab {
    var addedPhraseEntries: [PhraseItem] {
        changedPhraseEntries.filter { !store.isPhraseInBase($0.word) }
    }

    var phraseEntriesWithNotes: [PhraseItem] {
        changedPhraseEntries.filter { !$0.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var basePhraseCoreEditEntries: [PhraseItem] {
        changedPhraseEntries.filter { store.isBasePhraseCoreEdited($0) }
    }

    var changedPhraseEntries: [PhraseItem] {
        var order: [String] = []
        var mergedByWord: [String: PhraseItem] = [:]
        for phrase in store.addedPhrases + store.dataEditPhrases {
            if mergedByWord[phrase.word] == nil {
                order.append(phrase.word)
            }
            mergedByWord[phrase.word] = phrase
        }
        return order.compactMap { mergedByWord[$0] }
    }
}
