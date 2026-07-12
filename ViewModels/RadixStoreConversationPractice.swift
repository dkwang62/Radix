import Foundation

struct ConversationPracticeLinkedHints {
    let phrases: [PhraseItem]
    let characters: [String]
}

struct ConversationPracticeHintCacheKey: Hashable {
    let setID: String
    let itemID: String
    let simplified: String
    let phraseHints: [String]
    let characterHints: [String]
}

extension RadixStore {
    func matchingConversationPracticeTopicID(forPageID pageID: UUID, title fallbackTitle: String) -> String? {
        if let linkedPackID = RadixStudyPreferences.importedConversationPracticePacks
            .first(where: { $0.sourceLink?.sourcePageID == pageID })?
            .packID {
            return linkedPackID
        }
        return matchingConversationPracticeTopicID(forPageTitle: fallbackTitle)
    }

    func matchingConversationPracticeTopicID(forPageTitle title: String) -> String? {
        let target = conversationPracticeTitleKey(title)
        guard !target.isEmpty else { return nil }
        return RadixStudyPreferences.importedConversationPracticePacks
            .first { conversationPracticeTitleKey($0.title) == target }?
            .packID
    }

    func openConversationPractice(topicID: String) {
        let trimmed = topicID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        rememberCrossTabOrigin()
        selectedConversationPracticeTopicID = trimmed
        pendingConversationPracticeTopicID = trimmed
        route = .search
        homeTab = .favourites
        activeFavouriteCharacter = nil
        if RadixPlatform.isPhone { showiPhoneDetail = false }
        persistPromptSettings()
    }

    private func conversationPracticeTitleKey(_ value: String) -> String {
        let trimCharacters = CharacterSet.whitespacesAndNewlines
            .union(.punctuationCharacters)
            .union(CharacterSet(charactersIn: "。！？；，、"))
        return value.trimmingCharacters(in: trimCharacters)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    func conversationPracticeSourceLink(for collection: CharacterCollection) -> ConversationPracticeSourceLink {
        ConversationPracticeSourceLink.savedPage(
            id: collection.id,
            title: collection.name,
            createdAt: collection.createdAt
        )
    }

    func invalidateConversationPracticeHintCache() {
        conversationPracticeLinkedHintCache.removeAll()
        sentencePhraseDiscoveryCache.removeAll()
    }

    func loadConversationPracticePhraseCache() {
        RadixStudyPreferences.migrateImportedConversationPracticePacksIntoSentenceExamples()
        guard let library = try? ConversationPracticeService().loadStarterLibrary() else { return }
        registerConversationPracticeLibrary(library)
        if let favoriteLibrary = ConversationPracticeLibrary.favoriteSentencesLibrary(
            from: RadixStudyPreferences.favoriteSentenceExamples()
        ) {
            registerConversationPracticeLibrary(favoriteLibrary)
        }
    }

    func saveImportedConversationPracticePack(_ pack: ConversationPracticePack) {
        let pack = RadixStudyPreferences.canonicalizedConversationPracticePack(pack)
        var packs = RadixStudyPreferences.importedConversationPracticePacks
        packs.removeAll { $0.packID == pack.packID }
        packs.append(pack)
        RadixStudyPreferences.importedConversationPracticePacks = packs
        registerConversationPracticeLibrary(pack.practiceLibrary)
    }

    func applyImportedConversationPracticePacks(
        _ packs: [ConversationPracticePack]?,
        mode: RestoreMode
    ) {
        switch mode {
        case .additive:
            guard let packs, !packs.isEmpty else { return }
            var merged = RadixStudyPreferences.importedConversationPracticePacks
            for pack in packs {
                let pack = RadixStudyPreferences.canonicalizedConversationPracticePack(pack)
                merged.removeAll { $0.packID == pack.packID }
                merged.append(pack)
                registerConversationPracticeLibrary(pack.practiceLibrary)
            }
            RadixStudyPreferences.importedConversationPracticePacks = merged

        case .complete:
            let restored = (packs ?? []).map {
                RadixStudyPreferences.canonicalizedConversationPracticePack($0)
            }
            RadixStudyPreferences.importedConversationPracticePacks = restored
            for pack in restored {
                registerConversationPracticeLibrary(pack.practiceLibrary)
            }
            if !restored.contains(where: { $0.packID == selectedConversationPracticeTopicID }) &&
                !ConversationPracticeTopic.defaults.contains(where: { $0.id == selectedConversationPracticeTopicID }) {
                selectedConversationPracticeTopicID = ConversationPracticeTopic.generalGreetings.id
                persistPromptSettings()
            }
        }
    }

    func applyImportedFavoriteSentences(
        _ records: [FavoriteSentenceRecord]?,
        mode: RestoreMode
    ) {
        switch mode {
        case .additive:
            guard let records, !records.isEmpty else { return }
            RadixStudyPreferences.favoriteSentences = RadixStudyPreferences.favoriteSentences + records
        case .complete:
            RadixStudyPreferences.favoriteSentences = records ?? []
        }

        RadixStudyPreferences.migrateLegacyFavoriteSentencesIntoSentenceExamples()
        if let library = ConversationPracticeLibrary.favoriteSentencesLibrary(from: RadixStudyPreferences.favoriteSentenceExamples()) {
            registerConversationPracticeLibrary(library)
        } else if selectedConversationPracticeTopicID == ConversationPracticeTopic.favoriteSentencesID {
            selectedConversationPracticeTopicID = ConversationPracticeTopic.generalGreetings.id
            persistPromptSettings()
        }
    }

    func applyImportedPagePhraseExtractions(
        _ records: [PagePhraseExtractionRecord]?,
        mode: RestoreMode
    ) {
        switch mode {
        case .additive:
            guard let records, !records.isEmpty else { return }
            for record in records {
                RadixStudyPreferences.recordPagePhraseExtraction(
                    pageID: record.sourcePageID,
                    title: record.sourceTitle,
                    words: record.phraseWords,
                    extractedAt: record.extractedAt
                )
            }
        case .complete:
            RadixStudyPreferences.pagePhraseExtractions = records ?? []
        }
    }

    func registerConversationPracticeLibrary(_ library: ConversationPracticeLibrary) {
        var didRegisterPhrase = false
        for seed in library.phraseSeeds {
            let key = phraseStorageWord(seed.phraseKey)
            guard !key.isEmpty, phraseRepo.fetchPhrase(for: key) == nil else { continue }
            conversationPracticePhraseCache[key] = PhraseItem(
                word: key,
                pinyin: seed.pinyin,
                meanings: seed.english,
                notes: seed.notes
            )
            didRegisterPhrase = true
        }
        if didRegisterPhrase {
            invalidateConversationPracticeHintCache()
        }
    }

    func databasePhrase(for word: String) -> PhraseItem? {
        let key = phraseStorageWord(word)
        guard !key.isEmpty else { return nil }
        return phraseRepo.fetchPhrase(for: key, includeHidden: true)
    }

    func verifiedPracticePhraseHints(for item: ConversationPracticeItem) -> [PhraseItem] {
        let curatedCandidates = item.phraseHints.map(phraseStorageWord(_:))
        let source = phraseStorageWord(item.simplified)
        let discoveredCandidates = phraseDiscoverySubstrings(
            in: source,
            maxLength: phraseRepo.maxPhraseLength()
        )
        .map(phraseStorageWord(_:))
        let candidates = curatedCandidates + discoveredCandidates

        var seen = Set<String>()
        var phrases: [PhraseItem] = []
        for candidate in candidates {
            guard seen.insert(candidate).inserted,
                  let phrase = databasePhrase(for: candidate)
            else { continue }
            phrases.append(phrase)
        }

        var phraseByWord: [String: PhraseItem] = [:]
        for phrase in phrases where phraseByWord[phraseStorageWord(phrase.word)] == nil {
            phraseByWord[phraseStorageWord(phrase.word)] = phrase
        }
        let orderedWords = ConversationPracticeRules.nonOverlappingPhraseHints(
            phrases.map { phraseStorageWord($0.word) },
            in: source
        )
        let nonOverlappingPhrases = orderedWords.compactMap { phraseByWord[$0] }

        return nonOverlappingPhrases.sorted {
            let lhsPosition = source.range(of: phraseStorageWord($0.word))?.lowerBound
            let rhsPosition = source.range(of: phraseStorageWord($1.word))?.lowerBound
            if lhsPosition != rhsPosition {
                if lhsPosition == nil { return false }
                if rhsPosition == nil { return true }
                return lhsPosition! < rhsPosition!
            }
            if $0.word.count != $1.word.count { return $0.word.count > $1.word.count }
            return $0.word < $1.word
        }
    }

    func storedPracticePhraseHints(for item: ConversationPracticeItem) -> [PhraseItem] {
        let source = phraseStorageWord(item.simplified)
        var seen = Set<String>()
        let phrases = item.phraseHints.compactMap { rawHint -> PhraseItem? in
            let key = phraseStorageWord(rawHint)
            guard !key.isEmpty, seen.insert(key).inserted else { return nil }
            return databasePhrase(for: key)
        }
        return phrases.sorted {
            let lhsWord = phraseStorageWord($0.word)
            let rhsWord = phraseStorageWord($1.word)
            let lhsPosition = source.range(of: lhsWord)?.lowerBound
            let rhsPosition = source.range(of: rhsWord)?.lowerBound
            if lhsPosition != rhsPosition {
                if lhsPosition == nil { return false }
                if rhsPosition == nil { return true }
                return lhsPosition! < rhsPosition!
            }
            if lhsWord.count != rhsWord.count { return lhsWord.count > rhsWord.count }
            return lhsWord < rhsWord
        }
    }

    func linkedPracticeHints(for item: ConversationPracticeItem) -> ConversationPracticeLinkedHints {
        let cacheKey = ConversationPracticeHintCacheKey(
            setID: item.setID,
            itemID: item.id,
            simplified: item.simplified,
            phraseHints: item.phraseHints.map(phraseStorageWord(_:)),
            characterHints: item.characterHints
        )
        if let cached = conversationPracticeLinkedHintCache[cacheKey] {
            return cached
        }

        let phrases = verifiedPracticePhraseHints(for: item).sorted {
            if $0.word.count != $1.word.count { return $0.word.count > $1.word.count }

            let lhsPosition = item.simplified.range(of: $0.word)?.lowerBound
            let rhsPosition = item.simplified.range(of: $1.word)?.lowerBound
            if lhsPosition != rhsPosition {
                if lhsPosition == nil { return false }
                if rhsPosition == nil { return true }
                return lhsPosition! < rhsPosition!
            }
            return $0.word < $1.word
        }

        let coveredCharacters = Set(phrases.flatMap { phrase in phrase.word.map(String.init) })
        var seenCharacters = Set<String>()
        let characters = item.characterHints.filter { character in
            guard !coveredCharacters.contains(character) else { return false }
            return seenCharacters.insert(character).inserted
        }

        let hints = ConversationPracticeLinkedHints(
            phrases: phrases,
            characters: characters
        )
        conversationPracticeLinkedHintCache[cacheKey] = hints
        return hints
    }

    func isFavoriteSentence(_ item: ConversationPracticeItem) -> Bool {
        let id = FavoriteSentenceRecord.identifier(for: item)
        if RadixStudyPreferences.favoriteSentences.contains(where: { $0.id == id }) {
            return true
        }
        let key = SentenceExampleRecord.normalizedChineseKey(item.simplified)
        return RadixStudyPreferences.favoriteSentenceExamples()
            .contains { $0.normalizedChineseKey == key }
    }

    func toggleFavoriteSentence(_ item: ConversationPracticeItem) {
        if isFavoriteSentence(item) {
            RadixStudyPreferences.setSentenceExampleFavorite(item, isFavorited: false)
        } else {
            RadixStudyPreferences.setSentenceExampleFavorite(item, isFavorited: true)
        }
        favoriteSentenceRevision += 1
    }
}
