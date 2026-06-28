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

    func databasePhrase(for word: String) -> PhraseItem? {
        let key = phraseStorageWord(word)
        guard !key.isEmpty else { return nil }
        return phraseRepo.fetchPhrase(for: key, includeHidden: true)
    }

    func verifiedPracticePhraseHints(for item: ConversationPracticeItem) -> [PhraseItem] {
        let curatedCandidates = item.phraseHints.map(phraseStorageWord(_:))
        let discoveredCandidates = phraseDiscoverySubstrings(in: item.simplified).map(phraseStorageWord(_:))
        let candidates = curatedCandidates + discoveredCandidates

        var seen = Set<String>()
        var phrases: [PhraseItem] = []
        for candidate in candidates {
            guard seen.insert(candidate).inserted,
                  let phrase = databasePhrase(for: candidate)
            else { continue }
            phrases.append(phrase)
        }

        return phrases.sorted {
            let lhsPosition = item.simplified.range(of: $0.word)?.lowerBound
            let rhsPosition = item.simplified.range(of: $1.word)?.lowerBound
            if lhsPosition != rhsPosition {
                if lhsPosition == nil { return false }
                if rhsPosition == nil { return true }
                return lhsPosition! < rhsPosition!
            }
            if $0.word.count != $1.word.count { return $0.word.count > $1.word.count }
            return $0.word < $1.word
        }
    }
}
