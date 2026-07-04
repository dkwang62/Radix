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
    }

    func loadConversationPracticePhraseCache() {
        guard let library = try? ConversationPracticeService().loadStarterLibrary() else { return }
        registerConversationPracticeLibrary(library)
    }

    func saveImportedConversationPracticePack(_ pack: ConversationPracticePack) {
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
                merged.removeAll { $0.packID == pack.packID }
                merged.append(pack)
                registerConversationPracticeLibrary(pack.practiceLibrary)
            }
            RadixStudyPreferences.importedConversationPracticePacks = merged

        case .complete:
            let restored = packs ?? []
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

        if let library = ConversationPracticeLibrary.favoriteSentencesLibrary(from: RadixStudyPreferences.favoriteSentences) {
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
        return RadixStudyPreferences.favoriteSentences.contains { $0.id == id }
    }

    func toggleFavoriteSentence(_ item: ConversationPracticeItem) {
        let id = FavoriteSentenceRecord.identifier(for: item)
        var records = RadixStudyPreferences.favoriteSentences
        if records.contains(where: { $0.id == id }) {
            records.removeAll { $0.id == id }
        } else {
            records.append(FavoriteSentenceRecord(item: item))
        }
        RadixStudyPreferences.favoriteSentences = records
        favoriteSentenceRevision += 1
    }
}
