import Foundation

/*
 RADIX STORE — CHARACTER STUDIO (DATA EDIT) OPERATIONS
 =======================================================
 All CRUD and import/export operations for the Character Studio editor.
 Handles dictionary entries, custom phrases, auto-save, and data import.
 All @Published properties remain declared in RadixStore.swift.
*/

private struct SentencePhraseLinkCandidate: Sendable {
    let word: String
    let key: String
}

private func storagePhraseWord(_ word: String) -> String {
    let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
    let simplified = ScriptTextConverter.simplified(trimmed).trimmingCharacters(in: .whitespacesAndNewlines)
    return simplified.isEmpty ? trimmed : simplified
}

private func sentencePhraseLinkCandidates(from phraseWords: [String]) -> [SentencePhraseLinkCandidate] {
    var seen = Set<String>()
    return phraseWords.compactMap { phrase in
        let word = storagePhraseWord(phrase)
        let key = SentenceExampleRecord.normalizedChineseKey(word)
        guard word.count >= 2, !key.isEmpty, seen.insert(word).inserted else { return nil }
        return SentencePhraseLinkCandidate(word: word, key: key)
    }
}

private func orderedSentencePhraseLinksForCandidates(in sentence: String, candidates: [SentencePhraseLinkCandidate]) -> [String] {
    let sentenceKey = SentenceExampleRecord.normalizedChineseKey(storagePhraseWord(sentence))
    var seen = Set<String>()
    return candidates.compactMap { candidate -> SentencePhraseLinkCandidate? in
        guard sentenceKey.contains(candidate.key), seen.insert(candidate.word).inserted else { return nil }
        return candidate
    }
    .sorted {
        let lhsPosition = sentenceKey.range(of: $0.key)?.lowerBound
        let rhsPosition = sentenceKey.range(of: $1.key)?.lowerBound
        if lhsPosition != rhsPosition {
            if lhsPosition == nil { return false }
            if rhsPosition == nil { return true }
            return lhsPosition! < rhsPosition!
        }
        if $0.key.count != $1.key.count { return $0.key.count > $1.key.count }
        return $0.key < $1.key
    }
    .map(\.word)
}

private func refreshingAICleanedPagePhraseLinks(
    in records: [AICleanedPageRecord],
    candidates: [SentencePhraseLinkCandidate]
) -> (records: [AICleanedPageRecord], changedPageCount: Int) {
    var updatedRecords = records
    var changedPageCount = 0
    for pageIndex in updatedRecords.indices {
        let original = updatedRecords[pageIndex]
        updatedRecords[pageIndex].sentences = original.sentences.map { sentence in
            var updated = sentence
            updated.phraseHints = orderedSentencePhraseLinksForCandidates(in: sentence.chinese, candidates: candidates)
            return updated
        }
        if updatedRecords[pageIndex] != original {
            changedPageCount += 1
        }
    }
    return (updatedRecords, changedPageCount)
}

extension RadixStore {

    func loadDictionaryRepository() throws {
        try componentRepo.loadFromBundle()
        if FileManager.default.fileExists(atPath: dictionaryOverlayFileURL.path) {
            let data = try Data(contentsOf: dictionaryOverlayFileURL)
            componentRepo.applyOverlay(try JSONDecoder().decode(DictionaryOverlayPackage.self, from: data))
        } else if FileManager.default.fileExists(atPath: legacyEditableDictionaryFileURL.path) {
            let data = try Data(contentsOf: legacyEditableDictionaryFileURL)
            let legacyMap = try JSONDecoder().decode([String: RawComponentEntry].self, from: data)
            componentRepo.applyOverlay(ComponentRepository.makeOverlay(base: componentRepo.baseRawMap, effective: legacyMap))
            try persistDictionaryOverlay()
            try? FileManager.default.removeItem(at: legacyEditableDictionaryFileURL)
        }
    }

    func persistDictionaryOverlay() throws {
        dataEditSavePath = dictionaryOverlayFileURL.path
        if componentRepo.hasOverlayChanges {
            try componentRepo.saveOverlay(to: dictionaryOverlayFileURL)
        } else if FileManager.default.fileExists(atPath: dictionaryOverlayFileURL.path) {
            try FileManager.default.removeItem(at: dictionaryOverlayFileURL)
        }
    }

    func removeDictionaryOverlayFiles() throws {
        for url in [dictionaryOverlayFileURL, legacyEditableDictionaryFileURL]
        where FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    var dictionaryOverlayFileURL: URL {
        if let projectURL = ProjectLiveDataLocator.file(named: "component_map_changes.json") {
            return projectURL
        }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("component_map_changes.json")
    }

    var legacyEditableDictionaryFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("component_map_editable.json")
    }

    func emptyEntryTemplate() -> RawComponentEntry {
        RawComponentEntry(
            relatedCharacters: [],
            meta: RawMeta(
                variant: nil, additionalVariants: nil, pinyin: .single(""), definition: "",
                decomposition: "", idc: "", radical: "", strokes: .string(""), compounds: .many([]),
                etymology: RawEtymology(type: "", hint: .single(""), details: .single("")), notes: .many([])
            )
        )
    }

    func persistOverlayAddedDates() {
        let encoded = overlayAddedDates.mapValues { $0.timeIntervalSince1970 }
        preferences.set(encoded, forKey: RadixPreferenceKey.overlayAddedDates)
    }

    // MARK: - Load

    func loadDataEditEntry(for character: String) {
        let key = character.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.count == 1 else { return }

        if let cached = dataEditCache[key] {
            let currentPhrases = phraseRepo.fetchAddedPhrases()
            dataEditCache[key] = (entry: cached.entry, phrases: currentPhrases, isFav: cached.isFav)
            dataEditCharacter = key
            dataEditPhrases = currentPhrases
            applyDataEditEntryToForm(cached.entry, currentPhrases, cached.isFav)
            dataEditAutoSaveStatus = "Ready to edit \(key)"
            return
        }

        dataEditLoadTask?.cancel()
        isApplyingDatasetEntry = true
        dataEditAutoSaveStatus = "Loading \(key)..."

        dataEditLoadTask = Task { [weak self] in
            guard let self else { return }
            let entry = componentRepo.entry(for: key) ?? emptyEntryTemplate()
            let currentPhrases = phraseRepo.fetchAddedPhrases()
            let isFav = favorites.contains(key)

            if Task.isCancelled { return }
            dataEditCache[key] = (entry: entry, phrases: currentPhrases, isFav: isFav)
            if Task.isCancelled { return }

            await MainActor.run { [weak self] in
                guard let self else { return }
                dataEditCharacter = key
                dataEditPhrases = currentPhrases
                applyDataEditEntryToForm(entry, currentPhrases, isFav)
                isApplyingDatasetEntry = false
                dataEditAutoSaveStatus = "Ready to edit \(key)"
            }
        }
    }

    // MARK: - Restore / revert

    struct ChineseStorageNormalizationResult {
        let phraseCount: Int
        let sentenceCount: Int
    }

    struct SentencePhraseLinkRefreshResult {
        let sentenceCount: Int
        let extractedPageCount: Int
    }

    func restoreFromLibrary() {
        let key = dataEditCharacter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.count == 1 else { return }
        restoreDictionaryCharacterFromLibrary(key)
    }

    func restoreDictionaryCharacterFromLibrary(_ character: String, preserveNotes: Bool = true) {
        let key = character.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.count == 1 else { return }
        pendingDatasetAutosaveWorkItem?.cancel()
        pendingDatasetAutosaveWorkItem = nil

        guard let baseEntry = componentRepo.baseEntry(for: key) else {
            dataEditAutoSaveStatus = "Only built-in characters can be reverted."
            return
        }

        do {
            if preserveNotes,
               let currentNotes = componentRepo.entry(for: key)?.meta.notes,
               !(currentNotes.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty),
               currentNotes != baseEntry.meta.notes {
                componentRepo.replaceEntry(character: key, entry: entryByReplacingNotes(in: baseEntry, with: currentNotes))
            } else {
                componentRepo.restoreEntryFromBase(character: key)
            }
            try persistDictionaryOverlay()
            try persistDataEditAndRefresh()

            if let restoredEntry = componentRepo.entry(for: key) {
                dataEditCharacter = key
                dataEditPhrases = phraseRepo.fetchAddedPhrases()
                applyDataEditEntryToForm(restoredEntry, dataEditPhrases, favorites.contains(key))
                dataEditCache[key] = (entry: restoredEntry, phrases: dataEditPhrases, isFav: favorites.contains(key))
            }

            dataEditAutoSaveStatus = preserveNotes ? "Reverted to main dictionary. Notes kept." : "Reverted to main dictionary."
        } catch {
            dataEditAutoSaveStatus = "Library error: \(error.localizedDescription)"
        }
    }

    // MARK: - Create / discard

    func createCustomDictionaryEntry(character: String) throws {
        let key = character.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.count == 1 else {
            throw NSError(domain: "Radix", code: 2, userInfo: [NSLocalizedDescriptionKey: "Enter exactly one Chinese character."])
        }

        if let existing = componentRepo.entry(for: key) {
            dataEditCharacter = key
            applyDataEditEntryToForm(existing, phraseRepo.fetchAddedPhrases(), favorites.contains(key))
            dataEditAutoSaveStatus = componentRepo.baseEntry(for: key) == nil
                ? "Custom character already exists."
                : "That character is already in the built-in dictionary, so it was opened for editing instead."
            return
        }

        dataEditCharacter = key
        dataEditPhrases = phraseRepo.fetchAddedPhrases()
        let entry = emptyEntryTemplate()
        applyDataEditEntryToForm(entry, dataEditPhrases, favorites.contains(key))
        pendingDatasetAutosaveWorkItem?.cancel()
        pendingDatasetAutosaveWorkItem = nil
        dataEditAutoSaveStatus = "New character loaded into the editor."
    }

    func discardCurrentDataEditDraft() {
        pendingDatasetAutosaveWorkItem?.cancel()
        pendingDatasetAutosaveWorkItem = nil

        let key = dataEditCharacter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.count == 1 else {
            clearDataEditForm()
            dataEditAutoSaveStatus = "Draft cleared."
            return
        }

        if componentRepo.entry(for: key) != nil {
            loadDataEditEntry(for: key)
        } else {
            clearDataEditForm()
            dataEditAutoSaveStatus = "Draft cleared."
        }
    }

    func startBlankDataEdit() {
        pendingDatasetAutosaveWorkItem?.cancel()
        pendingDatasetAutosaveWorkItem = nil
        clearDataEditForm()
        dataEditPhrases = phraseRepo.fetchAddedPhrases()
        dataEditAutoSaveStatus = "Open a character to start editing."
    }

    // MARK: - Save

    func saveCurrentDictionaryDraft() throws {
        pendingDatasetAutosaveWorkItem?.cancel()
        pendingDatasetAutosaveWorkItem = nil
        try saveDataEdit(reloadCaches: true)
    }

    func resetStudioToMaster() throws {
        try componentRepo.loadFromBundle()
        try removeDictionaryOverlayFiles()
        try persistDataEditAndRefresh()
        if !dataEditCharacter.isEmpty {
            loadDataEditEntry(for: dataEditCharacter)
        }
        dataEditAutoSaveStatus = "Dictionary changes reset to Master copy."
    }

    func saveDataEdit(reloadCaches: Bool = true) throws {
        let key = dataEditCharacter.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasDictionaryTarget = key.count == 1

        if hasDictionaryTarget {
            componentRepo.replaceEntry(character: key, entry: buildDataEditEntryFromForm())
            if overlayAddedDates[key] == nil {
                overlayAddedDates[key] = Date()
                persistOverlayAddedDates()
            }
        }

        var blockedBuiltInWords: [String] = []
        for p in dataEditPhrases {
            let originalWord = p.word.trimmingCharacters(in: .whitespacesAndNewlines)
            let storedWord = phraseStorageWord(originalWord)
            if !storedWord.isEmpty {
                if phraseRepo.isInBase(word: storedWord) && !phraseRepo.isInAdd(word: storedWord) {
                    blockedBuiltInWords.append(storedWord)
                    continue
                }
                try phraseRepo.addOrUpdatePhrase(word: storedWord, pinyin: p.pinyin, meanings: p.meanings, notes: p.notes)
                try removeLegacyPhraseIfNeeded(originalWord: originalWord, storedWord: storedWord)
                refreshSentencePhraseLinksAfterAddingPhrase(storedWord)
            }
        }

        if hasDictionaryTarget {
            dataEditCache[key] = (entry: buildDataEditEntryFromForm(), phrases: dataEditPhrases, isFav: dataEditIsFavourite)
            setFavorite(character: key, isFavorite: dataEditIsFavourite)
        }

        if reloadCaches {
            if hasDictionaryTarget {
                try persistDictionaryOverlay()
                try persistDataEditAndRefresh()
                refreshPhraseBackedViews(for: key)
            } else {
                refreshPhraseBackedViews(for: nil)
            }
            if blockedBuiltInWords.isEmpty {
                dataEditAutoSaveStatus = hasDictionaryTarget ? "All changes saved." : "Custom phrases saved."
            } else {
                dataEditAutoSaveStatus = "Some entries match built-in phrases and were not saved: \(blockedBuiltInWords.joined(separator: ", "))"
            }
        } else {
            if hasDictionaryTarget {
                try persistDictionaryOverlay()
                refreshAddedDictionaryCharacters()
            }
            dataEditAutoSaveStatus = blockedBuiltInWords.isEmpty
                ? (hasDictionaryTarget ? "Auto-saved." : "Custom phrases auto-saved.")
                : "Built-in phrase matches were skipped during auto-save."
        }
    }

    func scheduleDataEditAutoSave() {
        guard !isApplyingDatasetEntry else { return }
        pendingDatasetAutosaveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            do {
                try self.saveDataEdit(reloadCaches: false)
            } catch {
                self.dataEditAutoSaveStatus = "Auto-save failed: \(error.localizedDescription)"
            }
        }
        pendingDatasetAutosaveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2), execute: work)
    }

    func flushPendingDataEditAutoSave() {
        pendingDatasetAutosaveWorkItem?.cancel()
        pendingDatasetAutosaveWorkItem = nil
        guard !isApplyingDatasetEntry else { return }
        do {
            try saveDataEdit(reloadCaches: false)
        } catch {
            dataEditAutoSaveStatus = "Auto-save failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Delete

    func deleteCurrentDataEditEntry() throws {
        let key = dataEditCharacter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.count == 1 else { return }
        guard componentRepo.baseEntry(for: key) == nil else {
            throw NSError(domain: "Radix", code: 3, userInfo: [NSLocalizedDescriptionKey: "Only custom added characters can be deleted. Use Restore for built-in characters."])
        }
        componentRepo.deleteEntry(character: key)
        try persistDictionaryOverlay()
        try persistDataEditAndRefresh()
        dataEditCharacter = ""
        dataEditDefinition = ""
        dataEditPinyin = ""
        dataEditDecomposition = ""
        dataEditRadical = ""
        dataEditStrokes = ""
        dataEditCompounds = ""
        dataEditEtymHint = ""
        dataEditEtymDetails = ""
        dataEditNotes = ""
        dataEditRelatedCharacters = ""
        dataEditIsFavourite = false
        dataEditAutoSaveStatus = "Custom character deleted."
    }

    // MARK: - Phrase editing

    func removeDataEditPhrase(word: String) {
        let storedWord = phraseStorageWord(word)
        guard phraseRepo.isInAdd(word: storedWord) else {
            dataEditAutoSaveStatus = "Only custom phrases can be edited here."
            return
        }
        dataEditPhrases.removeAll(where: { phraseStorageWord($0.word) == storedWord })
        addedPhrases.removeAll(where: { phraseStorageWord($0.word) == storedWord })
        refreshAddedPhraseReviewPhrases()
        do {
            try phraseRepo.deletePhrase(word: storedWord)
            refreshSentencePhraseLinksAfterRemovingPhrases([storedWord])
            refreshPhraseBackedViews(for: dataEditCharacter)
            dataEditAutoSaveStatus = "Phrase removed from your custom list."
        } catch {
            dataEditAutoSaveStatus = "Delete failed: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func removeAddedPhrases(words: [String]) throws -> Int {
        let storedWords = Array(Set(words.map(phraseStorageWord(_:)).filter { !$0.isEmpty && phraseRepo.isInAdd(word: $0) && !phraseRepo.isInBase(word: $0) }))
        guard !storedWords.isEmpty else {
            dataEditAutoSaveStatus = "No added phrases to delete."
            return 0
        }

        try createDatabaseSafetySnapshots(reason: "Before deleting added phrases")
        for word in storedWords {
            try phraseRepo.deletePhrase(word: word)
        }
        refreshSentencePhraseLinksAfterRemovingPhrases(storedWords)

        let deletedSet = Set(storedWords)
        dataEditPhrases.removeAll { deletedSet.contains(phraseStorageWord($0.word)) }
        addedPhrases.removeAll { deletedSet.contains(phraseStorageWord($0.word)) }
        refreshAddedPhraseReviewPhrases()
        refreshPhraseBackedViews(for: dataEditCharacter.trimmingCharacters(in: .whitespacesAndNewlines))
        dataEditAutoSaveStatus = "Deleted \(storedWords.count) added phrase\(storedWords.count == 1 ? "" : "s")."
        return storedWords.count
    }

    func updateAddedPhraseReviewStatus(word: String, status: PhraseReviewStatus?) throws {
        let reviewedAt = Date()
        let storedWord = phraseStorageWord(word)
        guard !storedWord.isEmpty else { return }
        applyAddedPhraseReviewStatusLocally(word: storedWord, status: status, reviewedAt: reviewedAt)
        try persistAddedPhraseReviewStatus(word: storedWord, status: status)
    }

    @discardableResult
    func applyAddedPhraseReviewStatusLocally(
        word: String,
        status: PhraseReviewStatus?,
        reviewedAt: Date = Date()
    ) -> PhraseItem? {
        let storedWord = phraseStorageWord(word)
        guard !storedWord.isEmpty else { return nil }
        var updatedPhrase: PhraseItem?

        func updated(_ phrase: PhraseItem) -> PhraseItem {
            guard phraseStorageWord(phrase.word) == storedWord else { return phrase }
            let replacement = PhraseItem(
                word: phrase.word,
                pinyin: phrase.pinyin,
                meanings: phrase.meanings,
                notes: phrase.notes,
                addedAt: phrase.addedAt,
                reviewStatus: status,
                lastReviewedAt: reviewedAt
            )
            updatedPhrase = replacement
            return replacement
        }

        addedPhrases = addedPhrases.map(updated(_:))
        if let updatedPhrase {
            addedPhraseReviewPhrases = addedPhraseReviewPhrases.map(updated(_:))
            if !addedPhraseReviewPhrases.contains(where: { phraseStorageWord($0.word) == storedWord }),
               updatedPhrase.word.count >= 2,
               !isPhraseInBase(updatedPhrase.word) {
                addedPhraseReviewPhrases = AddedPhraseReviewRules.sortedByPinyin(
                    addedPhraseReviewPhrases + [updatedPhrase]
                )
            }
        }
        dataEditPhrases = dataEditPhrases.map(updated(_:))
        for (key, value) in dataEditCache {
            dataEditCache[key] = (
                entry: value.entry,
                phrases: value.phrases.map(updated(_:)),
                isFav: value.isFav
            )
        }
        phraseCache.removeAll()
        browsePagePhraseTileCache.removeAll()
        browsePagePhraseCandidateCache.removeAll()
        invalidateConversationPracticeHintCache()
        return updatedPhrase
    }

    func persistAddedPhraseReviewStatus(word: String, status: PhraseReviewStatus?) throws {
        let storedWord = phraseStorageWord(word)
        guard !storedWord.isEmpty else { return }
        try phraseRepo.updateReviewStatus(for: storedWord, status: status)
        if status == .hidden || status == .removed {
            refreshSentencePhraseLinksAfterRemovingPhrases([storedWord])
        } else {
            refreshSentencePhraseLinksAfterAddingPhrase(storedWord)
        }
        let statusText = status?.title ?? "New"
        dataEditAutoSaveStatus = "\(storedWord) marked \(statusText)."
    }

    @discardableResult
    func removeAllUnnotedAddedPhrases() throws -> [String] {
        let removableWords = PhraseEditService(repository: phraseRepo, normalizeWord: phraseStorageWord(_:))
            .unnotedBasePhraseEditWords()

        guard !removableWords.isEmpty else {
            dataEditAutoSaveStatus = "No edited phrases without notes to revert."
            return []
        }

        try createDatabaseSafetySnapshots(reason: "Before reverting edited phrases")
        for word in removableWords {
            try phraseRepo.deletePhrase(word: phraseStorageWord(word))
        }
        refreshSentencePhraseLinksAfterRemovingPhrases(removableWords)

        let removableSet = Set(removableWords.map(phraseStorageWord(_:)))
        dataEditPhrases.removeAll { removableSet.contains(phraseStorageWord($0.word)) }
        addedPhrases.removeAll { removableSet.contains(phraseStorageWord($0.word)) }
        refreshAddedPhraseReviewPhrases()
        refreshPhraseBackedViews(for: dataEditCharacter.trimmingCharacters(in: .whitespacesAndNewlines))
        dataEditAutoSaveStatus = "Reverted \(removableWords.count) edited phrase\(removableWords.count == 1 ? "" : "s") without notes."
        return removableWords
    }

    @discardableResult
    func convertAddedPhrasesToSimplified() throws -> Int {
        let existingPhrases = phraseRepo.fetchAddedPhrases()
        let canonicalPhrases = uniquePhrases(existingPhrases)
        try phraseRepo.replaceAllPhrases(canonicalPhrases)
        normalizeFavoritePhraseStorage()
        refreshPhraseBackedViews(for: dataEditCharacter.trimmingCharacters(in: .whitespacesAndNewlines))
        dataEditAutoSaveStatus = "Converted \(canonicalPhrases.count) added phrase\(canonicalPhrases.count == 1 ? "" : "s") to Simplified."
        return canonicalPhrases.count
    }

    @discardableResult
    func normalizeChineseStorageToSimplified() throws -> ChineseStorageNormalizationResult {
        try createDatabaseSafetySnapshots(reason: "Before normalizing Chinese storage")
        let phraseCount = try convertAddedPhrasesToSimplified()
        let sentenceCount = convertStudySentencesToSimplified()
        _ = refreshSentencePhraseLinks()
        dataEditAutoSaveStatus = "Normalized Chinese storage to Simplified."
        return ChineseStorageNormalizationResult(phraseCount: phraseCount, sentenceCount: sentenceCount)
    }

    @discardableResult
    func normalizeChineseStorageToSimplifiedForSettings() async throws -> ChineseStorageNormalizationResult {
        try await createDatabaseSafetySnapshotsForSettings(reason: "Before normalizing Chinese storage")
        let phraseCount = try convertAddedPhrasesToSimplified()
        let sentenceCount = await Task.detached(priority: .userInitiated) {
            RadixStudyPreferences.convertStoredSentenceExamplesToSimplified()
        }.value

        let convertedPageCount = convertAICleanedPagesToSimplified()
        favoriteSentenceRevision += 1
        if convertedPageCount > 0 {
            RadixStudyPreferences.recordSentenceExamples(
                RadixStudyPreferences.aiCleanedPages.flatMap(SentenceExampleRecord.fromAICleanedPage(_:))
            )
        }

        _ = await refreshSentencePhraseLinksForSettings(createSafetySnapshot: false)
        dataEditAutoSaveStatus = "Normalized Chinese storage to Simplified."
        return ChineseStorageNormalizationResult(phraseCount: phraseCount, sentenceCount: sentenceCount)
    }

    @discardableResult
    func refreshSentencePhraseLinks() -> SentencePhraseLinkRefreshResult {
        _ = try? createSentenceDatabaseSafetySnapshot(reason: "Before refreshing sentence phrase links")
        let phraseWords = activeSentencePhraseLinkWords()
        let extractedPageCount = refreshAICleanedPagePhraseLinks(availablePhraseWords: phraseWords)
        if extractedPageCount > 0 {
            RadixStudyPreferences.recordSentenceExamples(
                RadixStudyPreferences.aiCleanedPages.flatMap(SentenceExampleRecord.fromAICleanedPage(_:))
            )
        }
        let sentenceCount = RadixStudyPreferences.refreshSentencePhraseLinks(availablePhraseWords: phraseWords)
        favoriteSentenceRevision += 1
        return SentencePhraseLinkRefreshResult(sentenceCount: sentenceCount, extractedPageCount: extractedPageCount)
    }

    @discardableResult
    func refreshSentencePhraseLinksForSettings(createSafetySnapshot: Bool = true) async -> SentencePhraseLinkRefreshResult {
        if createSafetySnapshot {
            _ = try? await createSentenceDatabaseSafetySnapshotForSettings(reason: "Before refreshing sentence phrase links")
        }
        let phraseWords = activeSentencePhraseLinkWords()
        let extractedPageCount = await refreshAICleanedPagePhraseLinksForOptimization(availablePhraseWords: phraseWords)
        if extractedPageCount > 0 {
            RadixStudyPreferences.recordSentenceExamples(
                RadixStudyPreferences.aiCleanedPages.flatMap(SentenceExampleRecord.fromAICleanedPage(_:))
            )
        }
        let sentenceCount = await Task.detached(priority: .userInitiated) {
            RadixStudyPreferences.refreshSentencePhraseLinks(availablePhraseWords: phraseWords)
        }.value
        favoriteSentenceRevision += 1
        return SentencePhraseLinkRefreshResult(sentenceCount: sentenceCount, extractedPageCount: extractedPageCount)
    }

    func startDatabaseOptimization(reason: String = "Optimizing database") {
        if databaseOptimizationInProgress {
            databaseOptimizationMessage = "Optimizing database… Radix is still usable."
            return
        }

        databaseOptimizationTask?.cancel()
        databaseOptimizationInProgress = true
        databaseOptimizationMessage = "Optimizing database… Radix is still usable."

        databaseOptimizationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let result = await self.refreshSentencePhraseLinksForSettings(createSafetySnapshot: false)
            guard !Task.isCancelled else { return }
            self.databaseOptimizationMessage = "Database optimization complete."
            self.databaseOptimizationInProgress = false
            self.databaseOptimizationTask = nil
            self.dataEditAutoSaveStatus = "\(reason) complete: optimized \(result.sentenceCount) sentence\(result.sentenceCount == 1 ? "" : "s")."
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled, !self.databaseOptimizationInProgress else { return }
            self.databaseOptimizationMessage = nil
        }
    }

    private func refreshSentencePhraseLinksAfterAddingPhrase(_ word: String) {
        let storedWord = phraseStorageWord(word)
        guard !storedWord.isEmpty, phraseRepo.fetchPhrase(for: storedWord) != nil else { return }
        _ = RadixStudyPreferences.addSentencePhraseLink(storedWord)
        _ = addAICleanedPagePhraseLink(storedWord)
        favoriteSentenceRevision += 1
    }

    private func refreshSentencePhraseLinksAfterRemovingPhrases(_ words: [String]) {
        let storedWords = words.map(phraseStorageWord(_:)).filter { !$0.isEmpty }
        guard !storedWords.isEmpty else { return }
        _ = RadixStudyPreferences.removeSentencePhraseLinks(storedWords)
        _ = removeAICleanedPagePhraseLinks(storedWords)
        favoriteSentenceRevision += 1
    }

    private func activeSentencePhraseLinkWords() -> [String] {
        var seen = Set<String>()
        return phraseRepo.fetchAllPhrases().compactMap { phrase in
            let word = phraseStorageWord(phrase.word)
            guard word.count >= 2, seen.insert(word).inserted else { return nil }
            return word
        }
    }

    private func refreshAICleanedPagePhraseLinks(availablePhraseWords words: [String]) -> Int {
        var records = RadixStudyPreferences.aiCleanedPages
        guard !records.isEmpty else { return 0 }
        let candidates = sentencePhraseLinkCandidates(from: words)
        let result = refreshingAICleanedPagePhraseLinks(in: records, candidates: candidates)
        records = result.records
        let changedPageCount = result.changedPageCount
        if changedPageCount > 0 {
            RadixStudyPreferences.aiCleanedPages = records
        }
        return changedPageCount
    }

    private func refreshAICleanedPagePhraseLinksForOptimization(availablePhraseWords words: [String]) async -> Int {
        let records = RadixStudyPreferences.aiCleanedPages
        guard !records.isEmpty else { return 0 }
        let candidates = sentencePhraseLinkCandidates(from: words)
        let result = await Task.detached(priority: .utility) {
            refreshingAICleanedPagePhraseLinks(in: records, candidates: candidates)
        }.value
        if result.changedPageCount > 0 {
            RadixStudyPreferences.aiCleanedPages = result.records
        }
        return result.changedPageCount
    }

    private func addAICleanedPagePhraseLink(_ word: String) -> Int {
        let storedWord = phraseStorageWord(word)
        guard storedWord.count >= 2 else { return 0 }
        var records = RadixStudyPreferences.aiCleanedPages
        guard !records.isEmpty else { return 0 }
        var changedPageCount = 0
        for pageIndex in records.indices {
            let original = records[pageIndex]
            records[pageIndex].sentences = original.sentences.map { sentence in
                let sentenceKey = SentenceExampleRecord.normalizedChineseKey(phraseStorageWord(sentence.chinese))
                let phraseKey = SentenceExampleRecord.normalizedChineseKey(storedWord)
                guard sentenceKey.contains(phraseKey), !sentence.phraseHints.map(phraseStorageWord(_:)).contains(storedWord) else {
                    return sentence
                }
                var updated = sentence
                updated.phraseHints = orderedSentencePhraseLinks(in: sentence.chinese, phraseWords: sentence.phraseHints + [storedWord])
                return updated
            }
            if records[pageIndex] != original {
                changedPageCount += 1
            }
        }
        if changedPageCount > 0 {
            RadixStudyPreferences.aiCleanedPages = records
        }
        return changedPageCount
    }

    private func removeAICleanedPagePhraseLinks(_ words: [String]) -> Int {
        let removedWords = Set(words.map(phraseStorageWord(_:)).filter { !$0.isEmpty })
        guard !removedWords.isEmpty else { return 0 }
        var records = RadixStudyPreferences.aiCleanedPages
        guard !records.isEmpty else { return 0 }
        var changedPageCount = 0
        for pageIndex in records.indices {
            let original = records[pageIndex]
            records[pageIndex].sentences = original.sentences.map { sentence in
                var updated = sentence
                updated.phraseHints = sentence.phraseHints.filter {
                    !removedWords.contains(phraseStorageWord($0))
                }
                return updated
            }
            if records[pageIndex] != original {
                changedPageCount += 1
            }
        }
        if changedPageCount > 0 {
            RadixStudyPreferences.aiCleanedPages = records
        }
        return changedPageCount
    }

    private func orderedSentencePhraseLinks(in sentence: String, phraseWords: [String]) -> [String] {
        orderedSentencePhraseLinksForCandidates(in: sentence, candidates: sentencePhraseLinkCandidates(from: phraseWords))
    }

    private func normalizeFavoritePhraseStorage() {
        var normalizedPhrases = Set<String>()
        var normalizedDates: [String: Date] = [:]
        for phrase in favoritePhrases {
            let storedWord = phraseStorageWord(phrase)
            guard !storedWord.isEmpty else { continue }
            normalizedPhrases.insert(storedWord)
            let existingDate = normalizedDates[storedWord]
            let candidateDate = favoritePhraseDates[phrase]
            normalizedDates[storedWord] = [existingDate, candidateDate].compactMap { $0 }.min()
        }
        favoritePhrases = normalizedPhrases
        favoritePhraseDates = normalizedDates
        persistFavoritePhrases()
    }

    func addCustomPhrase(word: String, pinyin: String, meanings: String, notes: String? = nil, refreshViews: Bool = true) throws {
        let originalWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        let storedWord = phraseStorageWord(originalWord)
        guard !storedWord.isEmpty else { return }
        guard storedWord.count >= 2 else {
            throw NSError(domain: "Radix", code: 17, userInfo: [NSLocalizedDescriptionKey: "Phrases need two or more characters. Add single characters as characters instead."])
        }

        try phraseRepo.addOrUpdatePhrase(
            word: storedWord,
            pinyin: pinyin.trimmingCharacters(in: .whitespacesAndNewlines),
            meanings: meanings.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        try removeLegacyPhraseIfNeeded(originalWord: originalWord, storedWord: storedWord)
        refreshSentencePhraseLinksAfterAddingPhrase(storedWord)

        if refreshViews {
            refreshPhraseBackedViews(for: dataEditCharacter.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        dataEditAutoSaveStatus = "Phrase notes saved."
    }

    @discardableResult
    func addAIPastedPhraseIfNew(word: String, pinyin: String, meanings: String, refreshViews: Bool = true) throws -> Bool {
        let originalWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        let storedWord = phraseStorageWord(originalWord)
        guard !storedWord.isEmpty else { return false }
        guard storedWord.count >= 2 else { return false }
        guard phraseRepo.existingWords(in: [storedWord]).isEmpty else { return false }

        try phraseRepo.addOrUpdatePhrase(
            word: storedWord,
            pinyin: pinyin.trimmingCharacters(in: .whitespacesAndNewlines),
            meanings: meanings.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: nil
        )
        try removeLegacyPhraseIfNeeded(originalWord: originalWord, storedWord: storedWord)
        refreshSentencePhraseLinksAfterAddingPhrase(storedWord)

        if refreshViews {
            refreshPhraseBackedViews(for: dataEditCharacter.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        dataEditAutoSaveStatus = "Phrase added."
        return true
    }

    func refreshPhraseOverlayViews() {
        refreshPhraseBackedViews(for: dataEditCharacter.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    // MARK: - Export / snapshot

    func currentDataEditSnapshotJSON() -> String? {
        let key = dataEditCharacter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.count == 1, let entry = componentRepo.entry(for: key) else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(entry) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func portableBackupPackage() -> UnifiedPackage {
        RadixStudyPreferences.prepareSentenceExamplesForBackup()
        return UnifiedPackage(
            schemaVersion: PortableBackupCodec.currentSchemaVersion,
            exportedAt: Date(),
            backupID: UUID(),
            baseDictionaryFingerprint: componentRepo.baseDictionaryFingerprint,
            dictionary: nil,
            dictionaryOverlay: nil,
            dictionaryPatchOverlay: componentRepo.overlayPatchPackage(),
            phrases: phraseRepo.fetchAddedPhrases(),
            profile: currentUserProfile(),
            collections: allCollections,
            selectedAICollectionID: selectedAICollectionID,
            conversationPracticePacks: RadixStudyPreferences.importedConversationPracticePacks,
            conversationPracticeProgress: RadixStudyPreferences.conversationPracticeProgress,
            favoriteSentences: RadixStudyPreferences.favoriteSentences,
            sentenceExamples: RadixStudyPreferences.sentenceExamples,
            pagePhraseExtractions: RadixStudyPreferences.pagePhraseExtractions,
            aiCleanedPages: RadixStudyPreferences.aiCleanedPages,
            apiKeys: currentAPIKeyBackup()
        )
    }

    func fullDatasetExportPackage() -> FullDatasetExportPackage {
        FullDatasetExportPackage(
            schemaVersion: 1,
            exportedAt: Date(),
            dictionary: componentRepo.rawMap,
            phrases: phraseRepo.fetchAllPhrases()
        )
    }

    func mergedDictionaryExportRecords() -> [DictionaryExportRecord] {
        componentRepo.rawMap.keys.sorted().compactMap { character in
            guard let entry = componentRepo.rawMap[character] else { return nil }
            let item = componentRepo.byCharacter[character]
            return DictionaryExportRecord(
                character: character,
                entry: entry,
                pinyin: item?.pinyinText ?? "",
                definition: item?.definition ?? "",
                decomposition: item?.decomposition ?? "",
                radical: item?.radical ?? "",
                strokes: item?.strokes
            )
        }
    }

    func mergedPhrasesForExport() -> [PhraseItem] {
        phraseRepo.fetchAllPhrases()
    }

    func databaseSnapshots(kind: RadixDatabaseSnapshotKind? = nil) -> [RadixDatabaseSnapshotMetadata] {
        RadixDatabaseSnapshotStore.snapshots(kind: kind)
    }

    func latestDatabaseSnapshot(kind: RadixDatabaseSnapshotKind) -> RadixDatabaseSnapshotMetadata? {
        RadixDatabaseSnapshotStore.latest(kind: kind)
    }

    @discardableResult
    func createDatabaseSafetySnapshots(reason: String) throws -> [RadixDatabaseSnapshotMetadata] {
        var snapshots: [RadixDatabaseSnapshotMetadata] = []
        var firstError: Error?

        do {
            snapshots.append(try createSentenceDatabaseSafetySnapshot(reason: reason))
        } catch {
            firstError = firstError ?? error
        }

        do {
            snapshots.append(try phraseRepo.createAddDatabaseSnapshot(reason: reason))
        } catch {
            firstError = firstError ?? error
        }

        if snapshots.isEmpty, let firstError {
            throw firstError
        }
        return snapshots
    }

    @discardableResult
    func createDatabaseSafetySnapshotsForSettings(reason: String) async throws -> [RadixDatabaseSnapshotMetadata] {
        var snapshots: [RadixDatabaseSnapshotMetadata] = []
        var firstError: Error?

        do {
            snapshots.append(try await createSentenceDatabaseSafetySnapshotForSettings(reason: reason))
        } catch {
            firstError = firstError ?? error
        }

        do {
            snapshots.append(try phraseRepo.createAddDatabaseSnapshot(reason: reason))
        } catch {
            firstError = firstError ?? error
        }

        if snapshots.isEmpty, let firstError {
            throw firstError
        }
        return snapshots
    }

    @discardableResult
    func createSentenceDatabaseSafetySnapshot(reason: String) throws -> RadixDatabaseSnapshotMetadata {
        try RadixStudyPreferences.createSentenceDatabaseSnapshot(reason: reason)
    }

    @discardableResult
    func createSentenceDatabaseSafetySnapshotForSettings(reason: String) async throws -> RadixDatabaseSnapshotMetadata {
        try await Task.detached(priority: .userInitiated) {
            try RadixStudyPreferences.createSentenceDatabaseSnapshot(reason: reason)
        }.value
    }

    func restoreDatabaseSnapshot(_ snapshot: RadixDatabaseSnapshotMetadata) throws {
        switch snapshot.kind {
        case .sentenceExamples:
            _ = try createSentenceDatabaseSafetySnapshot(reason: "Before restoring sentence snapshot")
            try RadixStudyPreferences.restoreSentenceDatabaseSnapshot(snapshot)
            favoriteSentenceRevision += 1
            dismissSidebarPhrasePreview()
        case .addedPhrases:
            _ = try phraseRepo.createAddDatabaseSnapshot(reason: "Before restoring added-phrases snapshot")
            try phraseRepo.restoreAddDatabaseSnapshot(snapshot)
            refreshAddedPhrases()
            syncDataEditPhraseCaches()
            dataEditPhrases = addedPhrases
            refreshAddedPhraseReviewPhrases()
            phraseCache.removeAll()
            browsePagePhraseTileCache.removeAll()
            browsePagePhraseCandidateCache.removeAll()
            invalidateConversationPracticeHintCache()
            favoriteSentenceRevision += 1
        }
    }

    // MARK: - Import

    func importDataEditData(_ data: Data, mode: RestoreMode = .additive) throws {
        let payload = try PortableBackupCodec().decode(data)
        try importDataEditPayload(payload, mode: mode)
    }

    func importDataEditPayload(
        _ payload: PortableBackupPayload,
        mode: RestoreMode = .additive,
        createSafetySnapshots: Bool = true,
        refreshSentenceLinks: Bool = true
    ) throws {
        pendingDatasetAutosaveWorkItem?.cancel()
        pendingDatasetAutosaveWorkItem = nil
        if createSafetySnapshots {
            try createDatabaseSafetySnapshots(reason: "Before importing data")
        }

        switch payload {
        case .unified(let package):
            let backupOverlay: DictionaryOverlayPackage
            if let patchOverlay = package.dictionaryPatchOverlay {
                backupOverlay = componentRepo.overlayPackage(from: patchOverlay)
            } else {
                backupOverlay = package.dictionaryOverlay
                    ?? ComponentRepository.makeOverlay(base: componentRepo.baseRawMap, effective: package.dictionary ?? [:])
            }

            switch mode {
            case .additive:
                let now = Date()
                let localOverlay = componentRepo.overlayPackage()
                var mergedUpserts = localOverlay.upserts
                var mergedDeletions = Set(localOverlay.deletions)
                for (char, entry) in backupOverlay.upserts where char.count == 1 {
                    if let localOverlay = componentRepo.overlayUpserts[char] {
                        guard let baseEntry = componentRepo.baseEntry(for: char) else { continue }
                        let merged = mergeNonConflictingEntry(
                            local: localOverlay, backup: entry, base: baseEntry,
                            restoredAt: package.exportedAt ?? now
                        )
                        if merged == baseEntry {
                            mergedUpserts.removeValue(forKey: char)
                        } else {
                            mergedUpserts[char] = merged
                        }
                        if overlayAddedDates[char] == nil { overlayAddedDates[char] = now }
                    } else {
                        mergedUpserts[char] = entry
                        if overlayAddedDates[char] == nil { overlayAddedDates[char] = now }
                    }
                    mergedDeletions.remove(char)
                }
                // Rebuild the dictionary indexes once after the entire merge. Rebuilding
                // for every restored character made larger iPad backups appear to hang
                // indefinitely when restored on an iPhone.
                componentRepo.applyOverlay(DictionaryOverlayPackage(
                    schemaVersion: max(backupOverlay.schemaVersion, 2),
                    upserts: mergedUpserts,
                    deletions: mergedDeletions.sorted()
                ))
                persistOverlayAddedDates()
                try phraseRepo.addPhrasesAdditively(uniquePhrases(package.phrases))
                mergeImportedCollections(package.collections, selectedAICollectionID: package.selectedAICollectionID)
                applyImportedConversationPracticePacks(package.conversationPracticePacks, mode: .additive)
                RadixStudyPreferences.conversationPracticeProgress =
                    RadixStudyPreferences.conversationPracticeProgress.merging(package.conversationPracticeProgress)
                RadixStudyPreferences.applyImportedSentenceExamples(package.sentenceExamples, mode: .additive)
                applyImportedFavoriteSentences(package.favoriteSentences, mode: .additive)
                applyImportedPagePhraseExtractions(package.pagePhraseExtractions, mode: .additive)
                RadixStudyPreferences.applyImportedAICleanedPages(
                    preprocessedAICleanedPages(package.aiCleanedPages),
                    mode: .additive
                )
                applyImportedAPIKeys(package.apiKeys)
                applyImportedProfile(package.profile, mode: .additive)
                if refreshSentenceLinks {
                    _ = refreshSentencePhraseLinks()
                }

            case .complete:
                componentRepo.applyOverlay(backupOverlay)
                overlayAddedDates = [:]
                let now = Date()
                for char in backupOverlay.upserts.keys where overlayAddedDates[char] == nil {
                    overlayAddedDates[char] = now
                }
                persistOverlayAddedDates()
                try phraseRepo.replaceAllPhrases(uniquePhrases(package.phrases))
                replaceCollections(with: package.collections, selectedAICollectionID: package.selectedAICollectionID)
                applyImportedConversationPracticePacks(package.conversationPracticePacks, mode: .complete)
                RadixStudyPreferences.conversationPracticeProgress =
                    package.conversationPracticeProgress ?? ConversationPracticeProgressSnapshot()
                RadixStudyPreferences.applyImportedSentenceExamples(package.sentenceExamples, mode: .complete)
                applyImportedFavoriteSentences(package.favoriteSentences, mode: .complete)
                applyImportedPagePhraseExtractions(package.pagePhraseExtractions, mode: .complete)
                RadixStudyPreferences.applyImportedAICleanedPages(
                    preprocessedAICleanedPages(package.aiCleanedPages),
                    mode: .complete
                )
                applyImportedAPIKeys(package.apiKeys)
                applyImportedProfile(package.profile, mode: .complete)
                if refreshSentenceLinks {
                    _ = refreshSentencePhraseLinks()
                }
            }

            try persistDictionaryOverlay()
            try persistDataEditAndRefresh()
        case .legacyDictionary(let map):
            try componentRepo.loadFromBundle()
            let overlay = ComponentRepository.makeOverlay(base: componentRepo.baseRawMap, effective: map)
            componentRepo.applyOverlay(overlay)
            try persistDictionaryOverlay()
            try persistDataEditAndRefresh()
        }

        if !dataEditCharacter.isEmpty {
            if componentRepo.hasCharacter(dataEditCharacter) {
                loadDataEditEntry(for: dataEditCharacter)
            } else {
                dataEditCharacter = ""
                dataEditDefinition = ""
                dataEditPinyin = ""
                dataEditDecomposition = ""
                dataEditRadical = ""
                dataEditStrokes = ""
                dataEditCompounds = ""
                dataEditEtymHint = ""
                dataEditEtymDetails = ""
                dataEditNotes = ""
                dataEditRelatedCharacters = ""
                dataEditIsFavourite = false
            }
        }
        refreshAddedPhrases()
        syncDataEditPhraseCaches()
        dataEditPhrases = addedPhrases
        dataImportRevision += 1
    }

    func importDataEditPayloadForRestore(_ payload: PortableBackupPayload, mode: RestoreMode = .additive) async throws {
        try await createDatabaseSafetySnapshotsForSettings(reason: "Before importing data")
        try importDataEditPayload(
            payload,
            mode: mode,
            createSafetySnapshots: false,
            refreshSentenceLinks: false
        )
        startDatabaseOptimization(reason: "Restore database optimization")
    }

    // MARK: - Variance check

    func calculateDictionaryVariances() {
        do {
            self.dictionaryVariances = currentDictionaryVariances()

            let masterPhrases = try cachedVarianceMasterPhraseWords()
            let studioPhrases = phraseRepo.phraseWordSet()

            var phVars: [DictionaryVariance] = []
            for word in studioPhrases where !masterPhrases.contains(word) {
                phVars.append(DictionaryVariance(character: word, type: .added))
            }
            for word in masterPhrases where !studioPhrases.contains(word) {
                phVars.append(DictionaryVariance(character: word, type: .missing))
            }
            self.phraseVariances = phVars.sorted { $0.character < $1.character }
        } catch {
            dataEditAutoSaveStatus = "Variance check failed: \(error.localizedDescription)"
        }
    }

    private func currentDictionaryVariances() -> [DictionaryVariance] {
        let added = componentRepo.overlayUpserts.keys
            .filter { componentRepo.baseEntry(for: $0) == nil }
            .map { DictionaryVariance(character: $0, type: .added) }
        let missing = componentRepo.overlayDeletions
            .map { DictionaryVariance(character: $0, type: .missing) }
        return (added + missing).sorted { $0.character < $1.character }
    }

    private func cachedVarianceMasterPhraseWords() throws -> Set<String> {
        if let cached = varianceMasterPhraseWords {
            return cached
        }
        let masterPhraseRepo = PhraseRepository()
        try masterPhraseRepo.openMasterBundleOnly()
        let baseline = masterPhraseRepo.phraseWordSet()
        varianceMasterPhraseWords = baseline
        return baseline
    }
}
