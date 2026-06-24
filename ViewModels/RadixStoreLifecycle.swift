import Foundation

/*
 RADIX STORE — LIFECYCLE
 =======================
 Repository loading and persisted-state restoration, kept separate from the
 central state-adapter surface so startup ordering remains explicit.
*/

extension RadixStore {
    func initialize() async {
        do {
            try loadDictionaryRepository()
            try phraseRepo.openFromBundle()
            setupInitialState()
        } catch {
            loadingError = error.localizedDescription
        }
    }

    func initializeForTesting() async {
        do {
            try componentRepo.loadFromBundle()
            try phraseRepo.openForTesting()
            setupInitialState()
        } catch {
            loadingError = error.localizedDescription
        }
    }

    private func setupInitialState() {
        availableRadicalFilters = ["none"] + componentRepo.availableRadicals()
        availableStructureFilters = ["none"] + componentRepo.availableStructures()
        normalizePersistedFilters()

        dataEditSavePath = dictionaryOverlayFileURL.path
        loadSidebarNavigationStyle()
        loadPromptSettings()
        promptConfig = promptConfig.normalized()
        promptSelectedTaskIDs = PromptTaskSelection.normalized(
            promptSelectedTaskIDs,
            availableIDs: promptConfig.tasks.map(\.id),
            defaultIDs: PromptConfig.defaultSelectedTaskIDs
        )

        loadCollections()
        loadFavorites()
        loadSearchHistory()
        loadRootBreadcrumb()
        clearSearch()
        refreshAllCharactersCache()
        recomputeGridItems()
        refreshAddedPhrases()
        refreshAddedDictionaryCharacters()
        calculateDictionaryVariances()

        dataEditPhrases = addedPhrases
        addPhrasesPath = phraseRepo.currentAddDBPath
        sharedComponentPeers = []
        sharedPeersByComponent = [:]

        route = .search
        homeTab = .filter
        showBrowseHelp = true
        showComponentHelp = true
        previewCharacter = nil
        showiPhoneDetail = false
    }

    private func normalizePersistedFilters() {
        if !availableRadicalFilters.contains(selectedRadicalFilter) { selectedRadicalFilter = "none" }
        if !availableRadicalFilters.contains(rootRadicalFilter) { rootRadicalFilter = "none" }
        if !availableStructureFilters.contains(selectedStructureFilter) { selectedStructureFilter = "none" }
        if !availableStructureFilters.contains(rootStructureFilter) { rootStructureFilter = "none" }
    }

    func loadSidebarNavigationStyle() {
        if let saved = preferences.string(forKey: RadixPreferenceKey.sidebarNavigationStyle),
           let style = SidebarNavigationStyle.fromStoredValue(saved) {
            sidebarNavigationStyle = style
        } else {
            sidebarNavigationStyle = .defaultStyle
        }
    }
}
