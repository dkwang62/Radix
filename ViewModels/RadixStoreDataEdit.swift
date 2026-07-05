import Foundation

/*
 RADIX STORE — CHARACTER STUDIO (DATA EDIT) OPERATIONS
 =======================================================
 All CRUD and import/export operations for the Character Studio editor.
 Handles dictionary entries, custom phrases, auto-save, and data import.
 All @Published properties remain declared in RadixStore.swift.
*/

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
        do {
            try phraseRepo.deletePhrase(word: storedWord)
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

        for word in storedWords {
            try phraseRepo.deletePhrase(word: word)
        }

        let deletedSet = Set(storedWords)
        dataEditPhrases.removeAll { deletedSet.contains(phraseStorageWord($0.word)) }
        addedPhrases.removeAll { deletedSet.contains(phraseStorageWord($0.word)) }
        refreshPhraseBackedViews(for: dataEditCharacter.trimmingCharacters(in: .whitespacesAndNewlines))
        dataEditAutoSaveStatus = "Deleted \(storedWords.count) added phrase\(storedWords.count == 1 ? "" : "s")."
        return storedWords.count
    }

    func updateAddedPhraseReviewStatus(word: String, status: PhraseReviewStatus?) throws {
        let storedWord = phraseStorageWord(word)
        guard !storedWord.isEmpty else { return }
        try phraseRepo.updateReviewStatus(for: storedWord, status: status)
        dataEditPhrases = phraseRepo.fetchAddedPhrases()
        refreshAddedPhrases()
        syncDataEditPhraseCaches()
        refreshPhraseBackedViews(for: dataEditCharacter.trimmingCharacters(in: .whitespacesAndNewlines))
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

        for word in removableWords {
            try phraseRepo.deletePhrase(word: phraseStorageWord(word))
        }

        let removableSet = Set(removableWords.map(phraseStorageWord(_:)))
        dataEditPhrases.removeAll { removableSet.contains(phraseStorageWord($0.word)) }
        addedPhrases.removeAll { removableSet.contains(phraseStorageWord($0.word)) }
        refreshPhraseBackedViews(for: dataEditCharacter.trimmingCharacters(in: .whitespacesAndNewlines))
        dataEditAutoSaveStatus = "Reverted \(removableWords.count) edited phrase\(removableWords.count == 1 ? "" : "s") without notes."
        return removableWords
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

    // MARK: - Import

    func importDataEditData(_ data: Data, mode: RestoreMode = .additive) throws {
        let payload = try PortableBackupCodec().decode(data)
        try importDataEditPayload(payload, mode: mode)
    }

    func importDataEditPayload(_ payload: PortableBackupPayload, mode: RestoreMode = .additive) throws {
        pendingDatasetAutosaveWorkItem?.cancel()
        pendingDatasetAutosaveWorkItem = nil

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
                applyImportedAPIKeys(package.apiKeys)
                applyImportedProfile(package.profile, mode: .additive)

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
                applyImportedAPIKeys(package.apiKeys)
                applyImportedProfile(package.profile, mode: .complete)
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
