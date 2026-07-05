import Foundation

/// Derived diagnostics describing how user data differs from bundled data.
struct RadixDataAuditState {
    var dictionaryVariances: [DictionaryVariance] = []
    var phraseVariances: [DictionaryVariance] = []
    var varianceMasterPhraseWords: Set<String>?
    var addedDictionaryCharacters: [String] = []
    var editedDictionaryCharacters: [String] = []
    var baseDictionaryCoreEditedCharacters: [String] = []
    var dictionaryCharactersWithNotes: [String] = []
    var editedDictionaryCharacterSet: Set<String> = []
    var changedDictionaryCharacters: [String] = []
}
