import Foundation

/*
 RADIX STORE — ROOTS BREADCRUMB (REMEMBERED BAR)
 =================================================
 Manages the remembered-bar strip: push/pop/step, persistence,
 activation routing, and seeding from favorites on first launch. Values and
 their current position are owned by RadixUserLibraryState.
*/

extension RadixStore {

    // MARK: - Push / remove / toggle

    func resetRootBreadcrumb(to character: String) {
        pushRootBreadcrumb(character)
    }

    func pushRootBreadcrumb(_ character: String) {
        let key = character.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.count == 1, componentRepo.hasCharacter(key) else { return }
        pushRootBreadcrumbItem(key)
    }

    func pushRootBreadcrumbItem(_ item: String) {
        let key = item.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidRootBreadcrumbItem(key) else { return }
        let next = MemoryStripState.inserting(key, into: rootBreadcrumb)
        rootBreadcrumb = next.0
        rootBreadcrumbIndex = next.1
        persistRootBreadcrumb()
    }

    func removeRootBreadcrumb(_ character: String) {
        let key = character.trimmingCharacters(in: .whitespacesAndNewlines)
        let next = MemoryStripState.removing(key, from: rootBreadcrumb, currentIndex: rootBreadcrumbIndex)
        rootBreadcrumb = next.0
        rootBreadcrumbIndex = next.1
        persistRootBreadcrumb()
    }

    func clearRecentCharacters() {
        rootBreadcrumb = []
        rootBreadcrumbIndex = 0
        persistRootBreadcrumb()
    }

    func toggleRootBreadcrumb(_ character: String) {
        let key = character.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidRootBreadcrumbItem(key) else { return }
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
        if let phrase = phraseRepo.fetchPhrase(for: key), key.count > 1 {
            activateBreadcrumbPhrase(phrase)
            return
        }

        guard key.count == 1, componentRepo.hasCharacter(key) else { return }
        pushRootBreadcrumb(key)
        sidebarPhrasePreview = nil
        imageBrowsePhrasePreview = nil

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
                let shouldHighlightOnly = shouldHighlightBrowseImageMemoryOnly
                if !shouldHighlightOnly { previewCharacter = key }
                let didHighlight = highlightMemoryMatchesInCurrentBrowseSource(key)
                if shouldHighlightOnly, didHighlight {
                    previewCharacter = nil
                } else if !didHighlight {
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
            loadSharedComponentPeers(for: key)
            loadSharedPeersByComponent(for: key)
            loadRootDerivatives(for: key)
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
        let shouldHighlightOnly = shouldHighlightBrowseImageMemoryOnly
        if shouldHighlightOnly {
            let didHighlight = highlightMemoryMatchesInCurrentBrowseSource(phrase.word)
            if didHighlight {
                sidebarPhrasePreview = nil
                imageBrowsePhrasePreview = nil
                previewCharacter = nil
                pushPhraseBreadcrumb(phrase)
                if speechEnabled { speechService.speak(phrase.word) }
                return
            }
        }

        sidebarPhrasePreview = phrase
        imageBrowsePhrasePreview = nil
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
                loadSharedComponentPeers(for: firstCharacter)
                loadSharedPeersByComponent(for: firstCharacter)
                loadRootDerivatives(for: firstCharacter)
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

    // MARK: - Platform highlight mode

    var shouldHighlightBrowseImageMemoryOnly: Bool {
        RadixPlatform.isPhone
            && route == .search
            && homeTab == .filter
            && selectedBrowseCollection != nil
    }

    // MARK: - Persistence

    func loadRootBreadcrumb() {
        guard let saved = preferences.array(forKey: rootBreadcrumbKey) as? [String] else { return }
        let loaded = sanitizedRootBreadcrumb(saved)
        rootBreadcrumb = loaded
        rootBreadcrumbIndex = loaded.isEmpty ? 0 : min(rootBreadcrumbIndex, loaded.count - 1)
    }

    func persistRootBreadcrumb() {
        preferences.set(rootBreadcrumb, forKey: rootBreadcrumbKey)
    }

    func applyRootBreadcrumb(_ characters: [String]) {
        let remembered = sanitizedRootBreadcrumb(characters)
        rootBreadcrumb = remembered
        rootBreadcrumbIndex = remembered.isEmpty ? 0 : min(rootBreadcrumbIndex, remembered.count - 1)
        persistRootBreadcrumb()
    }

    func sanitizedRootBreadcrumb(_ characters: [String]) -> [String] {
        var remembered: [String] = []
        var seen = Set<String>()
        for item in characters {
            let key = item.trimmingCharacters(in: .whitespacesAndNewlines)
            guard isValidRootBreadcrumbItem(key), !seen.contains(key) else { continue }
            seen.insert(key)
            remembered.append(key)
        }
        return remembered
    }

    func isValidRootBreadcrumbItem(_ item: String) -> Bool {
        guard !item.isEmpty else { return false }
        if item.count == 1 { return componentRepo.hasCharacter(item) }
        return phraseRepo.fetchPhrase(for: item) != nil
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
        preferences.set(searchHistory, forKey: searchHistoryKey)
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
