import Foundation

/*
 RADIX STORE — CHARACTER STUDIO (DATA EDIT) OPERATIONS
 =======================================================
 All CRUD and import/export operations for the Character Studio editor.
 Handles dictionary entries, custom phrases, auto-save, and data import.
 All @Published properties remain declared in RadixStore.swift.
*/

struct RadixStorageHealth: Equatable {
    var sentenceCount: Int
    var sentenceDatabaseByteCount: Int64
    var addedPhraseCount: Int
    var addedPhraseDatabaseByteCount: Int64
    var extractedPageCount: Int
    var largestExtractedPageSentenceCount: Int
    var optimizationMayBeNeeded: Bool
    var lastOptimizedAt: Date?

    var hasLargeSentenceLibrary: Bool { sentenceCount >= 20_000 }
    var hasLargeAddedPhraseLibrary: Bool { addedPhraseCount >= 10_000 }
    var hasLargeExtractedPage: Bool { largestExtractedPageSentenceCount >= 300 }
    var hasLargeDatabaseFiles: Bool {
        sentenceDatabaseByteCount + addedPhraseDatabaseByteCount >= 50 * 1_024 * 1_024
    }
    var hasWarnings: Bool {
        hasLargeSentenceLibrary || hasLargeAddedPhraseLibrary || hasLargeExtractedPage || hasLargeDatabaseFiles || optimizationMayBeNeeded
    }
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
        // Scene transitions call this for both inactive and background. An idle
        // editor must not start a full save during iOS's short snapshot window.
        guard pendingDatasetAutosaveWorkItem != nil else { return }
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
               updatedPhrase.word.count >= 2 {
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

        recordDatabaseOptimizationFingerprint(await databaseOptimizationFingerprintForSettings())
        dataEditAutoSaveStatus = "Normalized Chinese storage to Simplified."
        return ChineseStorageNormalizationResult(phraseCount: phraseCount, sentenceCount: sentenceCount)
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
}
