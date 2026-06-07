import Foundation

/*
 RADIX STORE — NAVIGATION
 =========================
 Character selection, preview, route transitions, breadcrumb management,
 quick-editor entry points, and AI Link dispatch.
 All @Published state remains in RadixStore.swift.
*/

extension RadixStore {

    // MARK: - Selection

    func select(character: String, announce: Bool = true) {
        let trimmedCharacter = character.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedCharacter.count == 1 else { return }
        activeSubject = .character(trimmedCharacter)

        if route == .capture {
            previewCharacter = trimmedCharacter
            refreshPhrases(for: trimmedCharacter)
            pushRootBreadcrumb(trimmedCharacter)
            showiPhoneDetail = false
            if announce && speechEnabled { speechService.speak(trimmedCharacter) }
            return
        }

        previewCharacter = trimmedCharacter
        if RadixPlatform.isPhone {
            showiPhoneDetail = (route != .lineage && route != .search)
        } else {
            showiPhoneDetail = true
        }
        if !suppressHelpReset {
            showBrowseHelp = false
            showComponentHelp = false
        }
        pushRootBreadcrumb(trimmedCharacter)

        phrases = []
        related = []
        lineageParents = []
        lineageDerivatives = []

        Task {
            let derivatives = componentRepo.related(for: trimmedCharacter, scriptFilter: scriptFilter)
            let parents = componentRepo.components(for: trimmedCharacter, scriptFilter: scriptFilter)
            let phonetic = componentRepo.pronunciationFamily(for: trimmedCharacter).compactMap { componentRepo.byCharacter[$0] }
            let semantic = componentRepo.semanticFamily(for: trimmedCharacter).compactMap { componentRepo.byCharacter[$0] }
            let analysis = componentRepo.analyzeStructure(for: trimmedCharacter)

            await MainActor.run {
                guard previewCharacter == trimmedCharacter else { return }
                self.lineageParents = parents
                self.lineageDerivatives = derivatives
                self.sortedLineageDerivatives = derivatives.sorted(by: frequencySortPredicate)
                self.phoneticFamily = phonetic
                self.semanticFamily = semantic
                self.structureAnalysis = analysis
                self.lineagePage = 0
                self.related = derivatives
                self.refreshPhrases(for: trimmedCharacter)
            }
        }

        loadSharedComponentPeers(for: trimmedCharacter)
        loadSharedPeersByComponent(for: trimmedCharacter)
        loadRootDerivatives(for: trimmedCharacter)

        if announce && speechEnabled { speechService.speak(trimmedCharacter) }
    }

    // MARK: - Preview

    func preview(character: String, announce: Bool = true, preservePhraseContext: Bool = false) {
        activeSubject = .character(character)
        let shouldPreservePhraseHighlight = preservePhraseContext || shouldPreserveBrowseImagePhraseHighlight
        if !shouldPreservePhraseHighlight {
            imagePhraseContext = nil
            imagePhraseHighlightOffsets = []
            clearAnchoredImagePhraseHighlight()
            imageBrowsePhrasePreview = nil
            sidebarPhrasePreview = nil
            imagePhraseHighlightRevision += 1
        }
        pushRootBreadcrumb(character)

        if route == .capture {
            previewCharacter = character
            refreshPhrases(for: character)
            showiPhoneDetail = false
            if announce && speechEnabled { speechService.speak(character) }
            return
        }

        if RadixPlatform.isPhone {
            if route == .search {
                browsePreview(character: character, announce: announce, preservePhraseContext: preservePhraseContext)
            } else if route == .lineage {
                previewCharacter = character
                refreshPhrases(for: character)
                showiPhoneDetail = false
            } else if route == .aiLink || route == .favourites {
                previewCharacter = character
                refreshPhrases(for: character)
                showiPhoneDetail = false
            } else {
                select(character: character)
            }
        } else {
            previewCharacter = character
            refreshPhrases()
            if homeTab == .dataEdit { loadDataEditEntry(for: character) }
            showiPhoneDetail = true
        }

        if announce && speechEnabled { speechService.speak(character) }
    }

    /// iPhone Browse: preview without pushing detail.
    func browsePreview(character: String, announce: Bool = true, preservePhraseContext: Bool = false) {
        let shouldPreservePhraseHighlight = preservePhraseContext || shouldPreserveBrowseImagePhraseHighlight
        if !shouldPreservePhraseHighlight {
            imagePhraseContext = nil
            imagePhraseHighlightOffsets = []
            clearAnchoredImagePhraseHighlight()
            imageBrowsePhrasePreview = nil
            sidebarPhrasePreview = nil
            imagePhraseHighlightRevision += 1
        }
        pushRootBreadcrumb(character)
        previewCharacter = character
        showiPhoneDetail = false
        refreshPhrases(for: character)
        showBrowseHelp = false
        showComponentHelp = false
        if announce && speechEnabled { speechService.speak(character) }
    }

    func clearBrowsePreview() {
        previewCharacter = nil
        imageBrowsePhrasePreview = nil
        sidebarPhrasePreview = nil
    }

    func selectFavouriteCharacter(_ character: String) {
        activeFavouriteCharacter = character
        preview(character: character)
    }

    // MARK: - Route transitions

    func enterLineage() {
        rootsReturnContext = nil
        if let target = previewCharacter { select(character: target) } else { previewCharacter = nil }
        route = .lineage
        showComponentHelp = true
        if RadixPlatform.isPhone { showiPhoneDetail = false }
    }

    func enterAILink() {
        if let target = previewCharacter { select(character: target) } else { previewCharacter = nil }
        route = .aiLink
    }

    func goToSearchRoot() {
        route = .search
        homeTab = .smart
        activeFavouriteCharacter = nil
        restoreLastPreviewedCharacterIfNeeded()
    }

    func goToFavourites() {
        route = .favourites
        activeFavouriteCharacter = nil
    }

    func goToBrowse() {
        route = .search
        homeTab = .filter
        gridSortMode = .characterFrequency
        activeFavouriteCharacter = nil
        showBrowseHelp = true
        showComponentHelp = false
        clearBrowsePreview()
    }

    func goToDataEdit() {
        route = .search
        homeTab = .dataEdit
        startBlankDataEdit()
        requestDataEditDictionaryFocus()
    }

    func goToRoots(character: String) {
        if route != .lineage {
            rootsReturnContext = RootsReturnContext(
                route: route,
                homeTab: route == .search ? homeTab : nil
            )
        }
        route = .lineage
        select(character: character, announce: false)
        showComponentHelp = true
        if RadixPlatform.isPhone { showiPhoneDetail = false }
    }

    func goToAILink(character: String) {
        select(character: character, announce: false)
        route = .aiLink
        if RadixPlatform.isPhone { showiPhoneDetail = false }
    }

    func goBack() {
        if route == .aiLink { route = .lineage; return }
        if route == .favourites { route = .search; return }
        if route == .lineage { route = .search; return }
        if let previous = history.popLast() {
            select(character: previous)
            route = .lineage
        } else {
            route = .search
        }
    }

    func returnFromRoots() {
        guard let rootsReturnContext else { return }
        route = rootsReturnContext.route
        if let homeTab = rootsReturnContext.homeTab { self.homeTab = homeTab }
        self.rootsReturnContext = nil
        if RadixPlatform.isPhone { showiPhoneDetail = false }
    }

    func returnToBrowseGrid() {
        restoreAnchoredImagePhraseHighlightIfNeeded()
        prepareBrowseReturnScrollTarget()
        clearBrowsePreview()
        showiPhoneDetail = false
    }

    var rootsReturnButtonTitle: String {
        guard let rootsReturnContext else { return "Back" }
        switch rootsReturnContext.route {
        case .capture: return "Back to Image"
        case .search:
            switch rootsReturnContext.homeTab ?? .smart {
            case .smart:      return "Back to Search"
            case .filter:     return "Back to Browse"
            case .favourites: return "Back to Favorites"
            case .dataEdit:   return "Back to My Data"
            }
        case .lineage:    return "Back to Components"
        case .aiLink:     return "Back to AI Link"
        case .favourites: return "Back to Favorites"
        }
    }

    // MARK: - Quick editors

    func openQuickCharacterEditor(_ character: String) {
        let trimmed = character.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 1 else { return }
        select(character: trimmed, announce: false)
        loadDataEditEntry(for: trimmed)
        quickEditDestination = .character(trimmed)
    }

    func openNewCharacterEditor() { quickEditDestination = .newCharacter }

    func openQuickPhraseEditor(word: String) {
        let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedWord.isEmpty else { return }
        quickEditDestination = .phrase(simplifiedText(trimmedWord))
    }

    func openNewPhraseEditor() { quickEditDestination = .newPhrase }

    // MARK: - AI Link dispatch

    func showPaywall(for feature: EntitlementManager.FeatureGate) {
        paywallFeatureName = feature.rawValue
        showPaywall = true
    }

    @MainActor
    func triggerSelectedAITasks(for character: String) {
        let trimmed = character.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let prompt = promptText(for: .character(trimmed), selectedTaskIDs: selectedPromptTaskIDsForCharacterLaunch())
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        RadixPlatform.copyToPasteboard(prompt)
        activeSubject = .character(trimmed)
        guard let url = defaultAIURL(prompt: prompt) else { return }
        RadixPlatform.open(url, after: 0.1)
        scheduleMacClipboardPasteIfPossible()
    }

    func goToAILinkTask4FromCapture(characters: [String]) {
        let validText = characters.joined()
        if let collection = createCollection(name: "Apple Vision Image", sourceText: validText, sourceType: .ocr) {
            goToAILinkTask4(collection: collection)
            return
        }
        if let target = characters.first ?? previewCharacter { select(character: target, announce: false) }
        promptSelectedTaskIDs = ["task4"]
        shouldAutoOpenAILinkTask4 = true
        route = .aiLink
        if RadixPlatform.isPhone { showiPhoneDetail = false }
        persistPromptSettings()
    }

    func goToAILinkTask4(collection: CharacterCollection) {
        goToAILinkCollectionTask(collection: collection, taskID: "task4")
    }

    func goToAILinkCollectionTask(collection: CharacterCollection, taskID: String) {
        selectedAICollectionID = collection.id
        selectedBrowseCollectionID = collection.id
        selectedBrowseCollectionCharacters = Set(collection.characters)
        promptSelectedTaskIDs = [taskID]
        shouldAutoOpenAILinkTask4 = taskID != "task6"
        shouldAutoRunGeminiPhraseAPI = taskID == "task6"
        route = .aiLink
        if RadixPlatform.isPhone { showiPhoneDetail = false }
        persistPromptSettings()
    }

    // MARK: - Phrase sidebar/preview

    var activeSidebarPhrasePreview: PhraseItem? { sidebarPhrasePreview ?? imageBrowsePhrasePreview }

    func presentPhraseInSidebar(_ phrase: PhraseItem) {
        sidebarPhrasePreview = phrase
        imageBrowsePhrasePreview = nil
        pushPhraseBreadcrumb(phrase)
    }

    func dismissSidebarPhrasePreview() {
        sidebarPhrasePreview = nil
        imageBrowsePhrasePreview = nil
    }

    func dismissImagePhrasePreview() {
        imageBrowsePhrasePreview = nil
        sidebarPhrasePreview = nil
    }

    // MARK: - Highlight helpers

    func highlightBrowseDictionaryCharacter(_ character: String?) {
        browseHighlightedCharacter = character
    }
}
