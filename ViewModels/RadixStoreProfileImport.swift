import Foundation

/*
 RADIX STORE — PROFILE IMPORT
 ============================
 Coordinates restoration of a portable user profile across the domain-specific
 stores. File decoding and transactional restore remain in the backup service.
*/

extension RadixStore {
    func applyImportedProfile(_ profile: UserProfile, mode: RestoreMode) {
        let isCompleteRestore = mode == .complete

        if let entries = profile.favouriteEntries, !entries.isEmpty {
            applyFavoriteEntries(entries)
        } else {
            applyFavoriteCharacters(profile.favouritesList)
        }
        persistFavorites()

        if let phraseEntries = profile.favouritePhraseEntries, !phraseEntries.isEmpty {
            applyFavoritePhraseEntries(phraseEntries)
            persistFavoritePhrases()
        } else if let phraseWords = profile.favouritePhrasesList {
            applyFavoritePhraseWords(phraseWords)
            persistFavoritePhrases()
        } else if isCompleteRestore {
            applyFavoritePhraseWords([])
            persistFavoritePhrases()
        }

        if let rememberedList = profile.rememberedList {
            applyRootBreadcrumb(rememberedList)
        } else if isCompleteRestore {
            applyRootBreadcrumb([])
        }
        if let history = profile.searchHistory {
            applySearchHistory(history)
        } else if isCompleteRestore {
            applySearchHistory([])
        }

        searchMode = SearchMode(rawValue: profile.searchMode ?? "") ?? .smart
        scriptFilter = ScriptFilter(rawValue: profile.scriptFilter ?? "") ?? .any
        if let importedRoute = AppRoute(rawValue: profile.route ?? "") {
            route = importedRoute
        } else if isCompleteRestore {
            route = .search
        }
        if let importedHomeTab = HomeTab(rawValue: profile.homeTab ?? "") {
            homeTab = importedHomeTab
        } else if isCompleteRestore {
            homeTab = .filter
        }
        if let style = SidebarNavigationStyle.fromStoredValue(profile.sidebarNavigationStyle ?? "") {
            sidebarNavigationStyle = style
        } else if isCompleteRestore {
            sidebarNavigationStyle = .descriptive
        }
        if let length = profile.phraseLength, (2...7).contains(length) {
            phraseLength = length
        } else if isCompleteRestore {
            phraseLength = nil
        }

        if let config = profile.promptConfig {
            promptConfig = config.normalized()
        } else if isCompleteRestore {
            promptConfig = .streamlitDefault
        }
        if let taskIDs = profile.promptSelectedTaskIDs {
            promptSelectedTaskIDs = taskIDs
        } else if isCompleteRestore {
            promptSelectedTaskIDs = PromptConfig.defaultSelectedTaskIDs
        }
        if let detail = profile.aiSentenceExtractionDetail {
            aiSentenceExtractionDetail = SentenceExtractionDetail.normalized(detail)
        } else if isCompleteRestore {
            aiSentenceExtractionDetail = .brief
        }
        if let settings = profile.defaultAISettings {
            defaultAIPreset = settings.preset
            customAIURLString = settings.customURLString
        } else if isCompleteRestore {
            defaultAIPreset = .chatGPT
            customAIURLString = ""
        }
        persistPromptSettings()

        restoreImportedPreview(profile.previewCharacter, complete: isCompleteRestore)

        let restoredQuery = profile.lastSearchQuery?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let restoredQuery, !restoredQuery.isEmpty {
            query = profile.currentSearchQuery?.trimmingCharacters(in: .whitespacesAndNewlines) ?? restoredQuery
            performSearch(customQuery: restoredQuery, recordHistory: false)
        } else {
            clearSearch()
            query = profile.currentSearchQuery?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
    }

    private func restoreImportedPreview(_ candidate: String?, complete: Bool) {
        if let candidate, componentRepo.hasCharacter(candidate) {
            previewCharacter = candidate
            preferences.set(candidate, forKey: RadixPreferenceKey.lastPreviewCharacter)
            refreshPhrases(for: candidate)
            loadSharedComponentPeers(for: candidate)
            loadSharedPeersByComponent(for: candidate)
            loadRootDerivatives(for: candidate)
        } else if complete {
            previewCharacter = nil
            preferences.removeObject(forKey: RadixPreferenceKey.lastPreviewCharacter)
            phrases = []
            sharedComponentPeers = []
            sharedPeersByComponent = [:]
            rootDerivatives = []
            rootDerivativesTotal = 0
        }
    }
}
