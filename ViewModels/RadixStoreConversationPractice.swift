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

    func sentencePreviewPhrase(
        for item: ConversationPracticeItem,
        usesTraditionalScript: Bool
    ) -> PhraseItem {
        ConversationPracticeScriptSupport.phraseItem(
            for: item,
            usesTraditionalScript: usesTraditionalScript,
            store: self
        )
    }

    func sentencePreviewPhrases(
        for item: ConversationPracticeItem,
        usesTraditionalScript: Bool
    ) -> [PhraseItem] {
        let phraseHints = storedPracticePhraseHints(for: item)
        return phraseHints
            .filter { phraseStorageWord($0.word) != item.phraseKey }
            .map {
                ConversationPracticeScriptSupport.displayPhrase(
                    $0,
                    usesTraditionalScript: usesTraditionalScript,
                    store: self
                )
            }
    }

    func allPracticePhraseMatches(for item: ConversationPracticeItem) -> [PhraseItem] {
        let source = phraseStorageWord(item.simplified)
        let sentenceKey = item.phraseKey
        let storedPhrases = storedPracticePhraseHints(for: item)
        let discoveredPhrases = source.count <= 240
            ? phraseDiscoveryKnownPhraseItems(in: source, includeHidden: true)
            : []

        var seen = Set<String>()
        var phrases: [PhraseItem] = []

        func append(_ phrase: PhraseItem) {
            let key = phraseStorageWord(phrase.word)
            guard key.count > 1,
                  key != sentenceKey,
                  source.contains(key),
                  seen.insert(key).inserted
            else { return }
            phrases.append(phrase)
        }

        storedPhrases.forEach(append)
        discoveredPhrases.forEach(append)

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

    func presentSentencePreviewInSidebar(
        _ item: ConversationPracticeItem,
        usesTraditionalScript: Bool,
        speak: Bool = true
    ) {
        let phrase = sentencePreviewPhrase(
            for: item,
            usesTraditionalScript: usesTraditionalScript
        )
        let sentencePhrases = sentencePreviewPhrases(
            for: item,
            usesTraditionalScript: usesTraditionalScript
        )
        if speak {
            speakPhrase(phrase)
        }
        presentPracticeSentenceInSidebar(
            phrase,
            sentencePhrases: sentencePhrases,
            practiceItem: item
        )
    }

    func sentenceExample(for item: ConversationPracticeItem) -> SentenceExampleRecord? {
        if let id = item.sentenceExampleID,
           let example = RadixStudyPreferences.sentenceExample(id: id) {
            return example
        }
        return RadixStudyPreferences.sentenceExample(normalizedKey: item.sentenceKey)
    }

    func sentenceExampleSourceLabel(_ example: SentenceExampleRecord) -> String {
        if let title = example.sources.compactMap(\.sourceTitle).first, !title.isEmpty {
            return title
        }
        if example.hasSourceType(.aiCleanedPage) { return "Extracted Sentences" }
        if example.hasSourceType(.ocrSource) { return "Captured Text" }
        if example.hasSourceType(.sentencePractice) { return "Page Sentences" }
        if example.hasSourceType(.conversationPractice) { return "Conversation Practice" }
        if example.hasSourceType(.favoriteSentence) { return "Favorite Sentence" }
        return "Sentence Example"
    }

    func sentencePreviewReturnTitle(
        for item: ConversationPracticeItem,
        topics: [ConversationPracticeTopic]
    ) -> String? {
        if let example = sentenceExample(for: item) {
            return sentenceExampleSourceLabel(example)
        }
        if let topic = topics.first(where: { $0.id == item.setID }) {
            return topic.title
        }
        return nil
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

    func toggleFavoriteSentence(_ item: ConversationPracticeItem) throws {
        if isFavoriteSentence(item) {
            try RadixStudyPreferences.setSentenceExampleFavorite(item, isFavorited: false)
        } else {
            try RadixStudyPreferences.setSentenceExampleFavorite(item, isFavorited: true)
        }
        favoriteSentenceRevision += 1
    }

    func deleteSentenceExample(_ item: ConversationPracticeItem) throws {
        let example = sentenceExample(for: item)
        if let example {
            try deleteSentenceExamples([example], dismissActivePreview: true)
        } else {
            let sentenceKey = SentenceExampleRecord.normalizedChineseKey(item.simplified)
            try RadixStudyPreferences.deleteSentenceExample(matchingChinese: item.simplified)
            removeSentencesFromOwningAICleanedPages(sentenceKeys: [sentenceKey])
            dismissSidebarPhrasePreview()
            favoriteSentenceRevision += 1
        }
    }

    func deleteSentenceExamples(_ examples: [SentenceExampleRecord], dismissActivePreview: Bool = false) throws {
        let uniqueExamples = Dictionary(grouping: examples, by: \.id).compactMap { $0.value.first }
        guard !uniqueExamples.isEmpty else { return }

        _ = try createSentenceDatabaseSafetySnapshot(reason: "Before deleting sentences")
        let sentenceKeys = Set(uniqueExamples.map(\.normalizedChineseKey).filter { !$0.isEmpty })
        try RadixStudyPreferences.deleteSentenceExamples(ids: uniqueExamples.map(\.id))
        removeSentencesFromOwningAICleanedPages(sentenceKeys: sentenceKeys)
        if dismissActivePreview,
           let activePracticeSentenceItem,
           sentenceKeys.contains(SentenceExampleRecord.normalizedChineseKey(activePracticeSentenceItem.simplified)) {
            dismissSidebarPhrasePreview()
        }
        favoriteSentenceRevision += 1
    }

    @discardableResult
    func convertStudySentencesToSimplified() -> Int {
        let convertedSentenceCount = RadixStudyPreferences.convertStoredSentenceExamplesToSimplified()
        let convertedPageCount = convertAICleanedPagesToSimplified()
        favoriteSentenceRevision += 1
        if convertedPageCount > 0 {
            try? RadixStudyPreferences.recordSentenceExamples(
                RadixStudyPreferences.aiCleanedPages.flatMap(SentenceExampleRecord.fromAICleanedPage(_:))
            )
        }
        return convertedSentenceCount
    }

    func convertAICleanedPagesToSimplified() -> Int {
        var pages = RadixStudyPreferences.aiCleanedPages
        var changedCount = 0
        for index in pages.indices {
            let original = pages[index]
            pages[index].cleanedTitle = ScriptTextConverter.simplified(original.cleanedTitle)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            pages[index].cleanedChineseText = ScriptTextConverter.simplified(original.cleanedChineseText)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            pages[index].repairNotes = original.repairNotes.map {
                ScriptTextConverter.simplified($0).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            pages[index].sentences = original.sentences.map { sentence in
                AICleanedPageSentence(
                    id: sentence.id,
                    chinese: ScriptTextConverter.simplified(sentence.chinese),
                    pinyin: sentence.pinyin,
                    english: sentence.english,
                    phraseHints: sentence.phraseHints.map { ScriptTextConverter.simplified($0) }
                )
            }
            if pages[index] != original {
                changedCount += 1
            }
        }
        if changedCount > 0 {
            RadixStudyPreferences.aiCleanedPages = pages
        }
        return changedCount
    }

    private func removeSentencesFromOwningAICleanedPages(sentenceKeys: Set<String>) {
        let keys = sentenceKeys.filter { !$0.isEmpty }
        guard !keys.isEmpty else { return }
        var pages = RadixStudyPreferences.aiCleanedPages
        var changed = false
        for index in pages.indices {
            let beforeCount = pages[index].sentences.count
            pages[index].sentences.removeAll {
                keys.contains(SentenceExampleRecord.normalizedChineseKey($0.chinese))
            }
            if pages[index].sentences.count != beforeCount {
                pages[index].cleanedChineseText = pages[index].sentences
                    .map(\.chinese)
                    .joined(separator: " ")
                changed = true
            }
        }
        if changed {
            RadixStudyPreferences.aiCleanedPages = pages
        }
    }
}
