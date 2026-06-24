import Foundation

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
