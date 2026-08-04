import Foundation

/*
 RADIX STORE — NAVIGATION
 =========================
 Character selection, lineage loading, preview, route transitions, breadcrumb
 management, quick-editor entry points, and AI Link dispatch.
 Navigation values are owned by RadixNavigationState and exposed through the
 compatibility properties on RadixStore. Lineage results are owned separately
 by RadixLineageState.
*/

extension RadixStore {

    func pushPhraseBreadcrumb(_ phrase: PhraseItem) {
        pushRootBreadcrumbItem(phrase.word)
    }

    func recordInspectedPhraseInHistory(_ phrase: PhraseItem) {
        pushPhraseBreadcrumb(phrase)
    }

    func recordInspectedCharacterInHistory(_ character: String) {
        pushRootBreadcrumb(character)
    }

    func rememberLastPreviewedCharacter(_ character: String?) {
        guard let character else { return }
        let key = character.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.count == 1, componentRepo.hasCharacter(key) else { return }
        preferences.set(key, forKey: RadixPreferenceKey.lastPreviewCharacter)
    }

    func restoreLastPreviewedCharacterIfNeeded() {
        guard previewCharacter == nil,
              let saved = preferences.string(forKey: RadixPreferenceKey.lastPreviewCharacter)
        else { return }
        let key = saved.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.count == 1, componentRepo.hasCharacter(key) else { return }

        previewCharacter = key
        refreshPhrases(for: key)
        loadSharedComponentPeers(for: key)
        loadSharedPeersByComponent(for: key)
        loadRootDerivatives(for: key)
    }

    // MARK: - Lineage paging

    var lineageBatchSize: Int { RadixPlatform.isDesktop ? 225 : 12 }

    var pagedLineageDerivatives: [ComponentItem] {
        let limitedItems = entitlement.limitLineage(sortedLineageDerivatives)
        let start = min(max(0, lineagePage), max(0, lineagePageCount - 1)) * lineageBatchSize
        let end = min(start + lineageBatchSize, limitedItems.count)
        guard start < end else { return [] }
        return Array(limitedItems[start..<end])
    }

    var lineagePageCount: Int {
        let count = entitlement.limitLineage(sortedLineageDerivatives).count
        return count == 0 ? 1 : Int(ceil(Double(count) / Double(lineageBatchSize)))
    }

    func nextLineagePage() {
        guard lineagePage + 1 < lineagePageCount else { return }
        lineagePage += 1
    }

    func previousLineagePage() {
        guard lineagePage > 0 else { return }
        lineagePage -= 1
    }

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

    func currentRootsReturnContext() -> RootsReturnContext {
        RootsReturnContext(
            route: route,
            homeTab: route == .search ? homeTab : nil,
            studyTarget: currentStudyNavigationTargetForReturn(),
            browseCollectionID: route == .search && homeTab == .filter ? selectedBrowseCollectionID : nil
        )
    }

    func currentStudyNavigationTargetForReturn() -> StudyNavigationTarget? {
        let isStudyRoute = route == .favourites || (route == .search && homeTab == .favourites)
        guard isStudyRoute else { return nil }
        return activeStudySectionTitle == StudyNavigationTarget.savedPages.title ? .savedPages : nil
    }

    func rememberCrossTabOrigin() {
        rootsReturnContext = currentRootsReturnContext()
    }

    func clearCrossTabOrigin() {
        rootsReturnContext = nil
    }

    func enterLineage() {
        rootsReturnContext = nil
        if let target = previewCharacter { select(character: target) } else { previewCharacter = nil }
        route = .lineage
        showComponentHelp = true
        if RadixPlatform.isPhone { showiPhoneDetail = false }
    }

    func enterAILink() {
        clearCrossTabOrigin()
        if let target = previewCharacter { select(character: target) } else { previewCharacter = nil }
        route = .aiLink
    }

    func goToSearchRoot(restorePreview: Bool = true) {
        clearCrossTabOrigin()
        route = .search
        homeTab = .smart
        activeFavouriteCharacter = nil
        if restorePreview {
            restoreLastPreviewedCharacterIfNeeded()
        }
    }

    func goToFavourites(preservingOrigin: Bool = false) {
        if preservingOrigin {
            rememberCrossTabOrigin()
        } else {
            clearCrossTabOrigin()
        }
        route = .favourites
        activeFavouriteCharacter = nil
    }

    func goToSettings() {
        clearCrossTabOrigin()
        shouldRevealAPIKeys = false
        route = .settings
        activeFavouriteCharacter = nil
        if RadixPlatform.isPhone { showiPhoneDetail = false }
    }

    func goToSettingsForAPIKeySetup() {
        rememberCrossTabOrigin()
        shouldRevealAPIKeys = true
        route = .settings
        activeFavouriteCharacter = nil
        if RadixPlatform.isPhone { showiPhoneDetail = false }
    }

    func goToBrowse() {
        clearCrossTabOrigin()
        route = .search
        homeTab = .filter
        gridSortMode = .characterFrequency
        activeFavouriteCharacter = nil
        showBrowseHelp = true
        showComponentHelp = false
        clearBrowsePreview()
        selectMostRecentBrowsePage()
    }

    func goToBrowseCollection(id collectionID: UUID, preservingOrigin: Bool = false) {
        let origin = preservingOrigin ? currentRootsReturnContext() : nil
        goToBrowse()
        rootsReturnContext = origin
        selectBrowseCollection(id: collectionID)
        shouldCloseBrowseSource = true
    }

    func goToPagesWorkspace(id collectionID: UUID? = nil, preservingOrigin: Bool = false) {
        let origin = preservingOrigin ? currentRootsReturnContext() : nil
        if preservingOrigin {
            rootsReturnContext = origin
        } else {
            clearCrossTabOrigin()
        }
        route = .favourites
        activeFavouriteCharacter = nil
        if let collectionID {
            selectBrowseCollection(id: collectionID)
        } else if selectedBrowseCollectionID == nil,
                  let collection = sortedCollections(order: .lastViewed).first {
            selectBrowseCollection(id: collection.id)
        }
        activeStudySectionTitle = StudyNavigationTarget.savedPages.title
        requestedStudyNavigationTarget = .savedPages
        shouldCloseBrowseSource = true
        showiPhoneDetail = false
    }

    func goToStudyAddedPhrases() {
        rememberCrossTabOrigin()
        route = .search
        homeTab = .favourites
        activeFavouriteCharacter = nil
        showiPhoneDetail = false
        shouldOpenAddedPhraseReview = true
    }

    func startBrowseCameraPage(preservingOrigin: Bool = false) {
        if preservingOrigin {
            rememberCrossTabOrigin()
        } else {
            clearCrossTabOrigin()
        }
        route = .capture
        activeFavouriteCharacter = nil
        clearBrowsePreview()
        shouldOpenCaptureCamera = true
    }

    func startCaptureTextPage() {
        startCapturePageRequest()
        shouldOpenCaptureTextPage = true
    }

    func startCaptureClipboardImagePage() {
        startCapturePageRequest()
        shouldOpenCaptureClipboardImage = true
    }

    func startCaptureAlbumPage() {
        startCapturePageRequest()
        shouldOpenCaptureAlbum = true
    }

    func startCaptureFilePage() {
        startCapturePageRequest()
        shouldOpenCaptureFiles = true
    }

    private func startCapturePageRequest() {
        clearCrossTabOrigin()
        route = .capture
        activeFavouriteCharacter = nil
        clearBrowsePreview()
    }

    func goToDataEdit(preservingOrigin: Bool = false) {
        if preservingOrigin {
            rememberCrossTabOrigin()
        } else {
            clearCrossTabOrigin()
        }
        route = .search
        homeTab = .dataEdit
        startBlankDataEdit()
    }

    func goToRoots(character: String) {
        if route != .lineage {
            rootsReturnContext = currentRootsReturnContext()
        }
        route = .lineage
        select(character: character, announce: false)
        showComponentHelp = true
        if RadixPlatform.isPhone { showiPhoneDetail = false }
    }

    func goToAILink(character: String) {
        if route != .aiLink {
            rememberCrossTabOrigin()
        }
        select(character: character, announce: false)
        route = .aiLink
        if RadixPlatform.isPhone { showiPhoneDetail = false }
    }

    func sentenceAITaskID(preferredTaskID: String = PromptConfig.defaultSentenceTaskID) -> String {
        let normalizedTasks = promptConfig.normalized().tasks
        let taskID = normalizedTasks.first { $0.id == preferredTaskID }?.id ??
            normalizedTasks.first { $0.id == PromptConfig.defaultSentenceTaskID }?.id ??
            normalizedTasks.first { $0.subjectType == .sentence }?.id ??
            PromptConfig.defaultSentenceTaskID
        if promptConfig.tasks.allSatisfy({ $0.id != taskID }),
           let defaultTask = PromptConfig.streamlitDefault.tasks.first(where: { $0.id == taskID }) {
            promptConfig.tasks.append(defaultTask)
        }
        return taskID
    }

    @MainActor
    func triggerSentenceAI(_ sentence: ConversationPracticeItem) {
        triggerSentenceAI(sentence, taskID: sentenceAITaskID())
    }

    @MainActor
    func triggerSentenceAI(_ sentence: ConversationPracticeItem, taskID preferredTaskID: String) {
        let taskID = sentenceAITaskID(preferredTaskID: preferredTaskID)
        let prompt = promptText(for: .sentence(sentence), selectedTaskIDs: [taskID])
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        activePracticeSentenceItem = sentence
        selectedPromptTaskID = taskID
        promptSelectedTaskIDs = [taskID]
        shouldAutoOpenAILinkPrompt = false
        shouldAutoRunGeminiPhraseAPI = false
        persistPromptSettings()
        RadixPlatform.copyToPasteboard(prompt)
        guard let url = defaultAIURL(prompt: prompt) else { return }
        RadixPlatform.open(url, after: 0.1)
        scheduleMacClipboardPasteIfPossible()
    }

    @MainActor
    func goToAILinkSentenceTask(_ sentence: ConversationPracticeItem, taskID preferredTaskID: String) {
        if route != .aiLink {
            rememberCrossTabOrigin()
        }
        let taskID = sentenceAITaskID(preferredTaskID: preferredTaskID)
        activePracticeSentenceItem = sentence
        selectedPromptTaskID = taskID
        promptSelectedTaskIDs = [taskID]
        shouldAutoOpenAILinkPrompt = true
        shouldAutoRunGeminiPhraseAPI = false
        route = .aiLink
        if RadixPlatform.isPhone { showiPhoneDetail = false }
        persistPromptSettings()
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
        if rootsReturnContext.route == .search,
           rootsReturnContext.homeTab == .filter,
           let browseCollectionID = rootsReturnContext.browseCollectionID {
            selectBrowseCollection(id: browseCollectionID)
            shouldCloseBrowseSource = true
        }
        self.rootsReturnContext = nil
        if RadixPlatform.isPhone { showiPhoneDetail = false }
    }

    var showsCrossTabReturn: Bool {
        CrossTabReturnVisibilityPolicy.shouldShow(
            current: CrossTabReturnVisibilityContext(
                route: route,
                homeTab: route == .search ? homeTab : nil,
                isStudyPages: currentStudyNavigationTargetForReturn() == .savedPages,
                hasSelectedBrowsePage: selectedBrowseCollectionID != nil
            ),
            origin: rootsReturnContext?.returnVisibilityContext
        )
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
            case .favourites: return "Back to Study"
            case .dataEdit:   return "Back to My Data"
            }
        case .lineage:    return "Back to Components"
        case .aiLink:     return "Back to AI Link"
        case .favourites: return "Back to Study"
        case .settings:   return "Back to Settings"
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

    func openNewPhraseEditor(word: String = "") {
        let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        quickEditDestination = .newPhrase(simplifiedText(trimmedWord))
    }

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
        if let collection = createCollection(
            name: "Apple Vision Image",
            sourceText: validText,
            sourceType: .ocr,
            originalOCRText: validText
        ) {
            goToAILinkTask4(collection: collection)
            return
        }
        if let target = characters.first ?? previewCharacter { select(character: target, announce: false) }
        promptSelectedTaskIDs = ["task4"]
        shouldAutoOpenAILinkPrompt = true
        route = .aiLink
        if RadixPlatform.isPhone { showiPhoneDetail = false }
        persistPromptSettings()
    }

    func goToAILinkTask4(collection: CharacterCollection) {
        goToAILinkCollectionTask(collection: collection, taskID: "task4")
    }

    func goToAILinkCollectionTask(collection: CharacterCollection, taskID: String) {
        if route != .aiLink {
            rememberCrossTabOrigin()
        }
        selectedAICollectionID = collection.id
        selectedBrowseCollectionID = collection.id
        selectedBrowseCollectionCharacters = Set(collection.characters)
        promptSelectedTaskIDs = [taskID]
        shouldAutoOpenAILinkPrompt = true
        shouldAutoRunGeminiPhraseAPI = false
        route = .aiLink
        if RadixPlatform.isPhone { showiPhoneDetail = false }
        persistPromptSettings()
    }

    func goToAILinkPracticeGenerator(topic: ConversationPracticeTopic) {
        if route != .aiLink {
            rememberCrossTabOrigin()
        }
        selectedConversationPracticeTopicID = topic.id
        promptSelectedTaskIDs = ["task9"]
        shouldAutoOpenAILinkPrompt = false
        shouldAutoRunGeminiPhraseAPI = false
        route = .aiLink
        if RadixPlatform.isPhone { showiPhoneDetail = false }
        persistPromptSettings()
    }

    // MARK: - Phrase sidebar/preview

    var activeSidebarPhrasePreview: PhraseItem? { sidebarPhrasePreview ?? imageBrowsePhrasePreview }

    func presentPhraseInSidebar(
        _ phrase: PhraseItem,
        lookupDepth: PhraseLookupDepth = .topLevel
    ) {
        sidebarPhrasePreview = phrase
        imageBrowsePhrasePreview = nil
        sidebarPhraseLookupOverride = nil
        sidebarPhraseLookupDepth = lookupDepth
        activePracticeSentenceItem = nil
        sidebarSentenceReturnPhrase = nil
        sidebarSentenceReturnLookupOverride = nil
        sidebarSentenceReturnPracticeItem = nil
        pushPhraseBreadcrumb(phrase)
    }

    func presentPhraseFromPracticeSentenceInSidebar(_ phrase: PhraseItem) {
        sidebarSentenceReturnPhrase = sidebarPhrasePreview
        sidebarSentenceReturnLookupOverride = sidebarPhraseLookupOverride
        sidebarSentenceReturnPracticeItem = activePracticeSentenceItem
        sidebarPhrasePreview = phrase
        imageBrowsePhrasePreview = nil
        sidebarPhraseLookupOverride = nil
        sidebarPhraseLookupDepth = .terminal
        activePracticeSentenceItem = nil
        pushPhraseBreadcrumb(phrase)
    }

    func returnToPracticeSentenceInSidebar() {
        guard let phrase = sidebarSentenceReturnPhrase else { return }
        let lookupOverride = sidebarSentenceReturnLookupOverride ?? []
        let practiceItem = sidebarSentenceReturnPracticeItem
        presentPracticeSentenceInSidebar(
            phrase,
            sentencePhrases: lookupOverride,
            practiceItem: practiceItem
        )
    }

    func presentPracticeSentenceInSidebar(
        _ phrase: PhraseItem,
        sentencePhrases: [PhraseItem],
        practiceItem: ConversationPracticeItem? = nil
    ) {
        sidebarPhrasePreview = phrase
        imageBrowsePhrasePreview = nil
        sidebarPhraseLookupOverride = sentencePhrases
        sidebarPhraseLookupDepth = .topLevel
        activePracticeSentenceItem = practiceItem
        sidebarSentenceReturnPhrase = nil
        sidebarSentenceReturnLookupOverride = nil
        sidebarSentenceReturnPracticeItem = nil
    }

    func dismissSidebarPhrasePreview() {
        sidebarPhrasePreview = nil
        imageBrowsePhrasePreview = nil
        sidebarPhraseLookupOverride = nil
        sidebarPhraseLookupDepth = .topLevel
        activePracticeSentenceItem = nil
        sidebarSentenceReturnPhrase = nil
        sidebarSentenceReturnLookupOverride = nil
        sidebarSentenceReturnPracticeItem = nil
    }

    func dismissImagePhrasePreview() {
        imageBrowsePhrasePreview = nil
        sidebarPhrasePreview = nil
        sidebarPhraseLookupOverride = nil
        sidebarPhraseLookupDepth = .topLevel
        activePracticeSentenceItem = nil
        sidebarSentenceReturnPhrase = nil
        sidebarSentenceReturnLookupOverride = nil
        sidebarSentenceReturnPracticeItem = nil
    }

    func clearInformationCardFocus() {
        dismissSidebarPhrasePreview()
        previewCharacter = nil
        showiPhoneDetail = false
    }

    // MARK: - Highlight helpers

    func highlightBrowseDictionaryCharacter(_ character: String?) {
        browseHighlightedCharacter = character
    }
}
