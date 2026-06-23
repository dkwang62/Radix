import Foundation

/*
 RADIX STORE — SEARCH
 =====================
 Search execution, phrase lookup, and search-adjacent thin accessors. Session
 values and produced results are owned by the focused search models and exposed
 through compatibility properties on RadixStore.
*/

extension RadixStore {

    // MARK: - Search execution

    func prepareFirstInteractionWarmup() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            speechService.prepareForFirstUtterance()
            _ = phraseRepo.maxPhraseLength()
        }
    }

    func performSearch(customQuery: String? = nil, recordHistory: Bool = true) {
        let targetQuery = customQuery ?? query
        let parsedQuery = RadixSearchQuery(targetQuery)

        guard !parsedQuery.isEmpty else {
            clearSearch()
            return
        }

        hasPerformedSearch = true
        lastSearchQuery = parsedQuery.rawText
        if recordHistory {
            appendSearchHistory(parsedQuery.rawText)
        }

        switch searchMode {
        case .smart:
            if parsedQuery.isForcedEnglish {
                results = componentRepo.searchDefinitions(query: parsedQuery.effectiveText, scriptFilter: .any, isStrict: true)
                smartPhraseResults = sortPhrasesByPinyin(phraseRepo.searchByDefinition(term: parsedQuery.effectiveText, isStrict: true))
                definitionCharacterResults = []
                definitionPhraseResults = []
            } else {
                results = componentRepo.search(query: parsedQuery.effectiveText, scriptFilter: .any)
                let characterPhrases = containsChineseCharacters(parsedQuery.effectiveText)
                    ? phraseRepo.searchByCharacters(term: phraseStorageWord(parsedQuery.effectiveText))
                    : []
                let meaningPhrases = parsedQuery.effectiveText.count >= 2
                    ? phraseRepo.searchByDefinition(term: parsedQuery.effectiveText)
                    : []
                let pinyinPhrases = normalizedCompactQuery(parsedQuery.effectiveText).count > 2
                    ? phraseRepo.searchByPinyin(term: parsedQuery.effectiveText)
                    : []
                smartPhraseResults = mergePhraseResults(
                    primary: characterPhrases,
                    secondary: mergePhraseResults(primary: meaningPhrases, secondary: pinyinPhrases)
                )
                definitionCharacterResults = []
                definitionPhraseResults = []
            }
        case .definition:
            definitionCharacterResults = componentRepo.searchDefinitions(query: parsedQuery.effectiveText, scriptFilter: .any, isStrict: parsedQuery.isForcedEnglish)
            definitionPhraseResults = sortPhrasesByPinyin(phraseRepo.searchByDefinition(term: parsedQuery.effectiveText, isStrict: parsedQuery.isForcedEnglish))
            smartPhraseResults = []
            results = []
        }

        if customQuery == nil {
            query = ""
        }
    }

    func clearSearch() {
        results = []
        smartPhraseResults = []
        definitionCharacterResults = []
        definitionPhraseResults = []
        hasPerformedSearch = false
    }

    func clearSearchHistory() {
        searchHistory = []
        preferences.removeObject(forKey: searchHistoryKey)
    }

    func setSearchMode(_ mode: SearchMode) {
        searchMode = mode
        performSearch(recordHistory: false)
    }

    func setScriptFilter(_ filter: ScriptFilter) {
        scriptFilter = filter
        if let previewCharacter {
            select(character: previewCharacter, announce: false)
        }
    }

    func setLineageSortMode(_ mode: LineageSortMode) {
        lineageSortMode = mode
        lineagePage = 0
    }

    // MARK: - Phrase accessors

    func refreshPhrases(for char: String? = nil) {
        let target = char ?? previewCharacter
        guard let targetToLoad = target else {
            phrases = []
            return
        }

        let length = phraseLength
        let cacheKey = phraseCacheKey(character: targetToLoad, length: length)
        let lookupTarget = phraseLookupTarget(for: targetToLoad)

        if let cached = phraseCache[cacheKey] {
            phrases = cached
            return
        }

        Task {
            let finalPhrases = phraseCandidates(containing: lookupTarget, originalTarget: targetToLoad, length: length)
            let result = rankedPhraseResults(finalPhrases)
            await MainActor.run {
                if (char ?? previewCharacter) == targetToLoad && phraseLength == length {
                    self.phrases = result
                    self.phraseCache[cacheKey] = result
                }
            }
        }
    }

    func phraseMatches(for character: String, length: Int? = nil) -> [PhraseItem] {
        let targetLength = length ?? phraseLength
        if character.count > 1 {
            let matches = phraseRepo.phrases(matchingPartsOf: character, length: nil)
            guard let targetLength else { return sortPhrasesByPinyin(matches) }
            return sortPhrasesByPinyin(matches.filter { PhraseLengthRule.matches(word: $0.word, selectedLength: targetLength) })
        }
        let targetToLoad = character.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !targetToLoad.isEmpty else { return [] }

        let phraseLength = length ?? self.phraseLength
        let cacheKey = phraseCacheKey(character: targetToLoad, length: phraseLength)
        let lookupTarget = phraseLookupTarget(for: targetToLoad)
        if let cached = phraseCache[cacheKey] {
            return cached
        }

        let finalPhrases = phraseCandidates(containing: lookupTarget, originalTarget: targetToLoad, length: phraseLength)
        let result = rankedPhraseResults(finalPhrases)
        phraseCache[cacheKey] = result
        return result
    }

    func phraseMatchesActiveLength(_ phrase: PhraseItem) -> Bool {
        PhraseLengthRule.matches(word: phrase.word, selectedLength: phraseLength)
    }

    func isPhraseInBase(_ word: String) -> Bool {
        phraseRepo.isInBase(word: phraseStorageWord(word))
    }

    func isPhraseInAdd(_ word: String) -> Bool {
        phraseRepo.isInAdd(word: phraseStorageWord(word))
    }

    func phraseNotesActionTitle(for word: String) -> String { "Notes" }

    func mergedPhrase(for word: String) -> PhraseItem? {
        let trimmedWord = phraseStorageWord(word)
        guard !trimmedWord.isEmpty else { return nil }
        return phraseRepo.fetchPhrase(for: trimmedWord)
    }

    func addedPhraseForReview(word: String) -> PhraseItem? {
        let trimmedWord = phraseStorageWord(word)
        guard !trimmedWord.isEmpty else { return nil }
        return phraseRepo.fetchAddedPhrase(for: trimmedWord)
    }

    func existingPhraseWords(in words: Set<String>) -> Set<String> {
        let normalizedWords = Set(words.map(phraseStorageWord(_:)).filter { !$0.isEmpty })
        return phraseRepo.existingWords(in: normalizedWords)
    }

    func isBasePhraseCoreEdited(_ phrase: PhraseItem) -> Bool {
        PhraseEditService(repository: phraseRepo, normalizeWord: phraseStorageWord(_:))
            .isBaseCoreEdited(phrase)
    }

    func phraseDiscoveryKnownPhrases(in text: String) -> [String] {
        let candidates = phraseDiscoverySubstrings(in: text)
        let known = phraseRepo.existingWords(in: candidates)
        return known.sorted {
            if $0.count != $1.count { return $0.count < $1.count }
            return $0 < $1
        }
    }

    func normalizedPhraseWord(_ word: String) -> String { phraseStorageWord(word) }

    // MARK: - Thin component/phrase accessors

    func item(for character: String?) -> ComponentItem? {
        guard let character else { return nil }
        return componentRepo.byCharacter[character]
    }

    func items(for characters: [String]) -> [ComponentItem] {
        var seen = Set<String>()
        var result: [ComponentItem] = []
        for character in characters {
            let key = character.trimmingCharacters(in: .whitespacesAndNewlines)
            guard key.count == 1, seen.insert(key).inserted, let item = componentRepo.byCharacter[key] else { continue }
            result.append(item)
        }
        return result
    }

    func components(for character: String) -> [ComponentItem] {
        componentRepo.components(for: character, scriptFilter: scriptFilter)
    }

    func counterpart(for character: String?) -> ComponentItem? {
        guard let character else { return nil }
        guard let counterpartChar = componentRepo.counterpart(for: character) else { return nil }
        return componentRepo.byCharacter[counterpartChar]
    }

    func allVariants(for character: String?) -> [ComponentItem] {
        guard let character else { return [] }
        return componentRepo.allVariants(for: character).compactMap { componentRepo.byCharacter[$0] }
    }

    func isTraditional(_ character: String) -> Bool { componentRepo.isTraditionalForGrid(character) }
    func isSimplified(_ character: String) -> Bool { componentRepo.isSimplifiedForGrid(character) }
    func simplifiedText(_ value: String) -> String { componentRepo.simplifiedText(value) }
    func traditionalText(_ value: String) -> String { componentRepo.traditionalText(value) }

    func structureText(for character: String) -> String? {
        let key = character.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.count == 1 else { return nil }
        let raw = componentRepo.entry(for: key)?.meta
        let value = (raw?.decomposition ?? raw?.idc ?? item(for: key)?.decomposition ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    func meaningText(for character: String) -> String? {
        let key = character.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.count == 1 else { return nil }
        let value = (componentRepo.entry(for: key)?.meta.definition ?? item(for: key)?.definition ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    func characterNotesActionTitle(for character: String) -> String { "Notes" }
    var speechMenuSymbolName: String { speechEnabled ? "speaker.wave.2" : "speaker.slash" }

    // MARK: - Phrase discovery substrings

    func phraseDiscoverySubstrings(in text: String) -> Set<String> {
        var results = Set<String>()
        var run: [Character] = []

        func flushRun() {
            guard run.count >= 2 else { run.removeAll(); return }
            for start in run.indices {
                for length in 2...4 {
                    let end = start + length
                    guard end <= run.count else { continue }
                    results.insert(String(run[start..<end]))
                }
            }
            run.removeAll()
        }

        for character in text {
            let isChinese = character.unicodeScalars.contains {
                (0x3400...0x4DBF).contains($0.value)
                || (0x4E00...0x9FFF).contains($0.value)
                || (0x20000...0x2EBEF).contains($0.value)
            }
            if isChinese { run.append(character) } else { flushRun() }
        }
        flushRun()
        return results
    }
}
