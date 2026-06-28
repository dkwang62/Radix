import Foundation

extension RadixStore {
    func loadConversationPracticePhraseCache() {
        guard let library = try? ConversationPracticeService().loadStarterLibrary() else { return }
        registerConversationPracticeLibrary(library)
    }

    func registerConversationPracticeLibrary(_ library: ConversationPracticeLibrary) {
        for seed in library.phraseSeeds {
            let key = phraseStorageWord(seed.phraseKey)
            guard !key.isEmpty, phraseRepo.fetchPhrase(for: key) == nil else { continue }
            conversationPracticePhraseCache[key] = PhraseItem(
                word: key,
                pinyin: seed.pinyin,
                meanings: seed.english,
                notes: seed.notes
            )
        }
    }
}
