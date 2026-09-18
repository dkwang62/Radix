import Foundation

/*
 RADIX STORE — LIFECYCLE
 =======================
 Repository loading and persisted-state restoration, kept separate from the
 central state-adapter surface so startup ordering remains explicit.
*/

extension RadixStore {
    func initialize() async {
        loadingError = nil
        do {
            try recoverPendingPageDeletion()
            pageDeletionRecoveryError = nil
            try loadDictionaryRepository()
            try phraseRepo.openFromBundle()
            try await recoverPendingRestoreRollback()
            restoreRollbackRecoveryError = nil
            loadConversationPracticePhraseCache()
            preprocessStoredAICleanedPagesIfNeeded()
            setupInitialState()
        } catch {
            if restoreRollbackJournal.isPending {
                restoreRollbackRecoveryError = error.localizedDescription
            }
            loadingError = error.localizedDescription
        }
    }

    func initializeForTesting() async {
        loadingError = nil
        do {
            try recoverPendingPageDeletion()
            pageDeletionRecoveryError = nil
            try componentRepo.loadFromBundle()
            try phraseRepo.openForTesting()
            try await recoverPendingRestoreRollback()
            restoreRollbackRecoveryError = nil
            loadConversationPracticePhraseCache()
            preprocessStoredAICleanedPagesIfNeeded()
            setupInitialState()
        } catch {
            if restoreRollbackJournal.isPending {
                restoreRollbackRecoveryError = error.localizedDescription
            }
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
        importBundledStandardDataIfNeeded()

        dataEditPhrases = addedPhrases
        addPhrasesPath = phraseRepo.currentAddDBPath
        sharedComponentPeers = []
        sharedPeersByComponent = [:]

        route = .search
        homeTab = .filter
        selectMostRecentBrowsePage()
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
        sidebarNavigationStyle = .defaultStyle
        preferences.set(
            SidebarNavigationStyle.defaultStyle.rawValue,
            forKey: RadixPreferenceKey.sidebarNavigationStyle
        )
    }

    private func importBundledStandardDataIfNeeded() {
        let importID = "radix_unified_backup.1.1.13"
        guard preferences.string(forKey: RadixPreferenceKey.standardDataImportID) != importID else {
            return
        }
        guard let url = Bundle.main.url(forResource: "radix_unified_backup", withExtension: "json") else {
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let payload = try PortableBackupCodec().decode(data)
            try importDataEditPayload(BundledStandardDataRules.sanitizedPayload(payload), mode: .additive)
            preferences.set(importID, forKey: RadixPreferenceKey.standardDataImportID)
        } catch {
            loadingError = error.localizedDescription
        }
    }

}
