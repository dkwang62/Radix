import Foundation
import SwiftUI

/// Editable Character Studio form values and its current save status.
struct RadixDataEditFormState {
    var character = ""
    var definition = ""
    var pinyin = ""
    var decomposition = ""
    var radical = ""
    var strokes = ""
    var compounds = ""
    var etymologyHint = ""
    var etymologyDetails = ""
    var notes = ""
    var relatedCharacters = ""
    var isFavourite = false
    var phrases: [PhraseItem] = []
    var autosaveStatus = ""
    var variant = ""
    var additionalVariants = ""
}

extension RadixStore {
    var dataEditCharacter: String { get { dataEditFormState.character } set { dataEditFormState.character = newValue } }
    var dataEditDefinition: String { get { dataEditFormState.definition } set { dataEditFormState.definition = newValue } }
    var dataEditPinyin: String { get { dataEditFormState.pinyin } set { dataEditFormState.pinyin = newValue } }
    var dataEditDecomposition: String { get { dataEditFormState.decomposition } set { dataEditFormState.decomposition = newValue } }
    var dataEditRadical: String { get { dataEditFormState.radical } set { dataEditFormState.radical = newValue } }
    var dataEditStrokes: String { get { dataEditFormState.strokes } set { dataEditFormState.strokes = newValue } }
    var dataEditCompounds: String { get { dataEditFormState.compounds } set { dataEditFormState.compounds = newValue } }
    var dataEditEtymHint: String { get { dataEditFormState.etymologyHint } set { dataEditFormState.etymologyHint = newValue } }
    var dataEditEtymDetails: String { get { dataEditFormState.etymologyDetails } set { dataEditFormState.etymologyDetails = newValue } }
    var dataEditNotes: String { get { dataEditFormState.notes } set { dataEditFormState.notes = newValue } }
    var dataEditRelatedCharacters: String { get { dataEditFormState.relatedCharacters } set { dataEditFormState.relatedCharacters = newValue } }
    var dataEditIsFavourite: Bool { get { dataEditFormState.isFavourite } set { dataEditFormState.isFavourite = newValue } }
    var dataEditPhrases: [PhraseItem] { get { dataEditFormState.phrases } set { dataEditFormState.phrases = newValue } }
    var dataEditAutoSaveStatus: String { get { dataEditFormState.autosaveStatus } set { dataEditFormState.autosaveStatus = newValue } }
    var dataEditVariant: String { get { dataEditFormState.variant } set { dataEditFormState.variant = newValue } }
    var dataEditAdditionalVariants: String { get { dataEditFormState.additionalVariants } set { dataEditFormState.additionalVariants = newValue } }

    func dataEditBinding<Value>(_ keyPath: WritableKeyPath<RadixDataEditFormState, Value>) -> Binding<Value> {
        Binding(
            get: { self.dataEditFormState[keyPath: keyPath] },
            set: { self.dataEditFormState[keyPath: keyPath] = $0 }
        )
    }
}
