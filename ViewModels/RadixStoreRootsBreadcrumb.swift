import Foundation

/*
 RADIX STORE — ROOTS BREADCRUMB (REMEMBERED BAR)
 =================================================
 Manages the remembered-bar strip: push/pop/step, persistence,
 activation routing, and seeding from favorites on first launch. Values and
 their current position are owned by RadixUserLibraryState.
*/

private let rootBreadcrumbLimit = 1_000

extension RadixStore {

    // MARK: - Push / remove / toggle

    func resetRootBreadcrumb(to character: String) {
        pushRootBreadcrumb(character)
    }

    func pushRootBreadcrumb(_ character: String) {
        let key = normalizedRootBreadcrumbItem(character)
        guard key.count == 1, componentRepo.hasCharacter(key) else { return }
        pushRootBreadcrumbItem(key)
    }

    func pushRootBreadcrumbItem(_ item: String) {
        pushRootBreadcrumbItems([item])
    }

    func pushRootBreadcrumbItems(_ items: [String], preloadedPhrases: [String: PhraseItem] = [:]) {
        let resolved = resolvedRootBreadcrumbItems(items, preloadedPhrases: preloadedPhrases)
        let incoming = resolved.items
        guard !incoming.isEmpty else { return }

        let incomingKeys = Set(incoming)
        let retained = rootBreadcrumb.filter { !incomingKeys.contains($0) }
        rootBreadcrumb = Array((incoming + retained).prefix(rootBreadcrumbLimit))
        rootBreadcrumbPhraseCache.merge(resolved.phrases) { _, latest in latest }
        rootBreadcrumbPhraseCache = rootBreadcrumbPhraseCache.filter { rootBreadcrumb.contains($0.key) }
        rootBreadcrumbIndex = 0
        persistRootBreadcrumb()
    }

    @discardableResult
    func addClipboardStudyItemsToMemoryStrip(force: Bool = false) -> Int {
        guard !isInitializing else { return 0 }
        let clipboardText = RadixPlatform.pasteboardString
        guard force || clipboardText != lastAutomaticMemoryStripClipboardText else { return 0 }
        lastAutomaticMemoryStripClipboardText = clipboardText

        let clipboardCharacters = MemoryStripClipboardRules.chineseCharacters(in: clipboardText)
        guard !clipboardCharacters.isEmpty else { return 0 }

        let lookupCharacters = clipboardCharacters.map(normalizedRootBreadcrumbItem(_:))
        let candidateWords = BrowsePagePhraseRules.candidateWords(
            lookupCharacters: lookupCharacters,
            maxPhraseLength: MemoryStripClipboardRules.characterLimit
        )
        let phrases = resolvedRootBreadcrumbPhrases(matching: candidateWords)
        let items = MemoryStripClipboardRules.prioritizedItems(
            characters: lookupCharacters,
            knownPhrases: Set(phrases.keys),
            supportsCharacter: componentRepo.hasCharacter(_:)
        )
        pushRootBreadcrumbItems(items, preloadedPhrases: phrases)
        return items.count
    }

    func removeRootBreadcrumb(_ character: String) {
        let key = character.trimmingCharacters(in: .whitespacesAndNewlines)
        let next = MemoryStripState.removing(key, from: rootBreadcrumb, currentIndex: rootBreadcrumbIndex)
        rootBreadcrumb = next.0
        rootBreadcrumbPhraseCache.removeValue(forKey: key)
        rootBreadcrumbIndex = next.1
        persistRootBreadcrumb()
    }

    func clearRecentCharacters() {
        rootBreadcrumb = []
        rootBreadcrumbPhraseCache = [:]
        rootBreadcrumbIndex = 0
        persistRootBreadcrumb()
    }

    func toggleRootBreadcrumb(_ character: String) {
        let key = character.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.count == 1 ? componentRepo.hasCharacter(key) : rootBreadcrumbPhraseCache[key] != nil else { return }
        if rootBreadcrumb.contains(key) {
            removeRootBreadcrumb(key)
        } else {
            pushRootBreadcrumbItem(key)
        }
    }

    func stepRootBreadcrumb(by delta: Int) -> String? {
        guard let next = MemoryStripState.stepping(in: rootBreadcrumb, currentIndex: rootBreadcrumbIndex, delta: delta) else { return nil }
        rootBreadcrumbIndex = next.index
        return next.item
    }

    var canRootGoBack: Bool { MemoryStripState.canGoBack(currentIndex: rootBreadcrumbIndex) }
    var canRootGoForward: Bool { MemoryStripState.canGoForward(currentIndex: rootBreadcrumbIndex, count: rootBreadcrumb.count) }

    // MARK: - Activation routing

    func activateBreadcrumbCharacter(_ character: String) {
        let key = character.trimmingCharacters(in: .whitespacesAndNewlines)
        if key.count > 1, let phrase = rootBreadcrumbPhraseCache[key] {
            activateBreadcrumbPhrase(phrase)
            return
        }

        guard key.count == 1, componentRepo.hasCharacter(key) else { return }
        pushRootBreadcrumb(key)
        sidebarPhrasePreview = nil
        imageBrowsePhrasePreview = nil
        if RadixPlatform.isPhone { showiPhoneDetail = false }

        switch route {
        case .capture:
            select(character: key, announce: false)
        case .search:
            switch homeTab {
            case .smart:
                let pinyinText = item(for: key)?.pinyinText.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let searchText = pinyinText.isEmpty ? key : pinyinText
                query = searchText
                previewCharacter = key
                performSearch(customQuery: searchText)
                refreshPhrases(for: key)
            case .filter:
                previewCharacter = key
                let didHighlight = highlightMemoryMatchesInCurrentBrowseSource(key)
                if !didHighlight {
                    _ = focusGridCharacter(key)
                }
                refreshPhrases(for: key)
            case .favourites:
                previewCharacter = key
                refreshPhrases(for: key)
            case .dataEdit:
                openQuickCharacterEditor(key)
            }
        case .lineage:
            select(character: key, announce: false)
        case .aiLink:
            previewCharacter = key
            refreshPhrases(for: key)
        case .favourites:
            previewCharacter = key
            refreshPhrases(for: key)
        case .settings:
            previewCharacter = key
            refreshPhrases(for: key)
        }

        if speechEnabled { speechService.speak(key) }
    }

    func activateBreadcrumbPhrase(_ phrase: PhraseItem) {
        sidebarPhrasePreview = phrase
        imageBrowsePhrasePreview = nil
        previewCharacter = nil
        sidebarPhraseLookupOverride = nil
        if RadixPlatform.isPhone { showiPhoneDetail = false }
        pushPhraseBreadcrumb(phrase)

        switch route {
        case .capture:
            break
        case .search:
            switch homeTab {
            case .smart:
                let pinyinText = phrase.pinyin.trimmingCharacters(in: .whitespacesAndNewlines)
                let searchText = pinyinText.isEmpty ? phrase.word : pinyinText
                query = searchText
                performSearch(customQuery: searchText)
            case .filter:
                _ = highlightMemoryMatchesInCurrentBrowseSource(phrase.word)
            case .favourites:
                break
            case .dataEdit:
                openQuickPhraseEditor(word: phrase.word)
            }
        case .lineage:
            if let firstCharacter = phrase.word.map(String.init).first {
                select(character: firstCharacter, announce: false)
            }
        case .aiLink:
            break
        case .favourites:
            break
        case .settings:
            break
        }

        if speechEnabled { speechService.speak(phrase.word) }
    }

    // MARK: - Persistence

    func loadRootBreadcrumb() {
        guard let saved = preferences.array(forKey: RadixPreferenceKey.rootBreadcrumb) as? [String] else { return }
        applyResolvedRootBreadcrumb(saved, persist: false)
    }

    func persistRootBreadcrumb() {
        preferences.set(rootBreadcrumb, forKey: RadixPreferenceKey.rootBreadcrumb)
    }

    func applyRootBreadcrumb(_ characters: [String]) {
        applyResolvedRootBreadcrumb(characters, persist: true)
    }

    func sanitizedRootBreadcrumb(_ characters: [String]) -> [String] {
        resolvedRootBreadcrumbItems(characters).items
    }

    func historyPhrase(for item: String) -> PhraseItem? {
        rootBreadcrumbPhraseCache[normalizedRootBreadcrumbItem(item)]
    }

    func normalizedRootBreadcrumbItem(_ item: String) -> String {
        let key = item.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return "" }
        if key.count == 1 {
            let simplified = simplifiedText(key).trimmingCharacters(in: .whitespacesAndNewlines)
            return simplified.count == 1 ? simplified : key
        }
        return phraseStorageWord(key)
    }

    private func applyResolvedRootBreadcrumb(_ items: [String], persist: Bool) {
        let resolved = resolvedRootBreadcrumbItems(items)
        rootBreadcrumb = resolved.items
        rootBreadcrumbPhraseCache = resolved.phrases
        rootBreadcrumbIndex = resolved.items.isEmpty ? 0 : min(rootBreadcrumbIndex, resolved.items.count - 1)
        if persist { persistRootBreadcrumb() }
    }

    private func resolvedRootBreadcrumbItems(
        _ items: [String],
        preloadedPhrases: [String: PhraseItem] = [:]
    ) -> (items: [String], phrases: [String: PhraseItem]) {
        let normalized = items.map(normalizedRootBreadcrumbItem(_:))
        let phraseWords = Set(normalized.filter { $0.count > 1 })
        var phrases = rootBreadcrumbPhraseCache
        for (word, phrase) in preloadedPhrases {
            phrases[normalizedRootBreadcrumbItem(word)] = phrase
        }
        let unresolvedWords = phraseWords.subtracting(Set(phrases.keys))
        phrases.merge(resolvedRootBreadcrumbPhrases(matching: unresolvedWords)) { _, latest in latest }

        var remembered: [String] = []
        var seen = Set<String>()
        for key in normalized {
            let isValid = key.count == 1 ? componentRepo.hasCharacter(key) : phrases[key] != nil
            guard isValid, seen.insert(key).inserted else { continue }
            remembered.append(key)
            if remembered.count >= rootBreadcrumbLimit { break }
        }
        return (remembered, phrases.filter { remembered.contains($0.key) })
    }

    private func resolvedRootBreadcrumbPhrases(matching words: Set<String>) -> [String: PhraseItem] {
        let normalizedWords = Set(words.map(normalizedRootBreadcrumbItem(_:)).filter { $0.count > 1 })
        guard !normalizedWords.isEmpty else { return [:] }

        var phrases: [String: PhraseItem] = [:]
        for phrase in phraseRepo.fetchPhrases(matching: normalizedWords) {
            phrases[normalizedRootBreadcrumbItem(phrase.word)] = phrase
        }
        for word in normalizedWords where phrases[word] == nil {
            if let phrase = conversationPracticePhraseCache[word] {
                phrases[word] = phrase
            }
        }
        return phrases
    }

    var recentCharacterItems: [ComponentItem] {
        let combinedCharacters = rootBreadcrumb.filter { $0.count == 1 } + Array(favorites)
        var seen = Set<String>()
        let uniqueCharacters = combinedCharacters.filter { seen.insert($0).inserted }
        return uniqueCharacters
            .compactMap { componentRepo.byCharacter[$0] }
            .sorted(by: frequencySortPredicate)
    }

    var recentOnlyCharacterItems: [ComponentItem] {
        rootBreadcrumb
            .filter { $0.count == 1 && !favorites.contains($0) }
            .compactMap { componentRepo.byCharacter[$0] }
    }

    var recentCharacterCount: Int {
        rootBreadcrumb.filter { $0.count == 1 && componentRepo.hasCharacter($0) }.count
    }

    func applySearchHistory(_ queries: [String]) {
        searchHistory = queries
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        preferences.set(searchHistory, forKey: RadixPreferenceKey.searchHistory)
    }

    func seedBreadcrumbFromFavorites() {
        var seeded: [String] = []
        var seen = Set<String>()

        let sortedFavoriteCharacters = FavoriteOrdering.sortedByAddedDate(
            Array(favorites),
            dateForValue: { favoriteAddedDates[$0] },
            fallbackSort: <
        )

        func append(_ character: String) {
            guard character.count == 1, componentRepo.hasCharacter(character), !seen.contains(character) else { return }
            seen.insert(character)
            seeded.append(character)
        }
        sortedFavoriteCharacters.forEach(append)

        let sortedFavoritePhrases = FavoriteOrdering.sortedByAddedDate(
            Array(favoritePhrases),
            dateForValue: { favoritePhraseDates[$0] },
            fallbackSort: <
        )
        for phrase in sortedFavoritePhrases {
            guard phraseRepo.fetchPhrase(for: phrase) != nil, !seen.contains(phrase) else { continue }
            seen.insert(phrase)
            seeded.append(phrase)
        }

        rootBreadcrumb = seeded
        rootBreadcrumbIndex = seeded.isEmpty ? 0 : min(rootBreadcrumbIndex, seeded.count - 1)
        persistRootBreadcrumb()
    }
}
