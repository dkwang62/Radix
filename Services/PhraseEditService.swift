import Foundation

struct PhraseEditService {
    let repository: PhraseRepository
    let normalizeWord: (String) -> String

    func isBaseCoreEdited(_ phrase: PhraseItem) -> Bool {
        let storedWord = normalizeWord(phrase.word)
        guard repository.isInBase(word: storedWord),
              repository.isInAdd(word: storedWord)
        else { return false }

        return BackupSummaryBuilder.phraseHasCoreEdit(
            phrase: phrase,
            basePhrase: repository.fetchBasePhrase(for: storedWord)
        )
    }

    func unnotedBasePhraseEditWords() -> [String] {
        repository.fetchAddedPhrases()
            .filter {
                repository.isInBase(word: normalizeWord($0.word))
                    && $0.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            .map(\.word)
    }
}
