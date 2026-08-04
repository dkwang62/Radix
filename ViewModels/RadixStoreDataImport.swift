import Foundation

extension RadixStore {
    // MARK: - Import

    func importDataEditData(_ data: Data, mode: RestoreMode = .additive) throws {
        let payload = try PortableBackupCodec().decode(data)
        try importDataEditPayload(payload, mode: mode)
    }

    func importDataEditPayload(
        _ payload: PortableBackupPayload,
        mode: RestoreMode = .additive,
        createSafetySnapshots: Bool = true,
        refreshSentenceLinks: Bool = false
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
                applyImportedPagePhraseExtractions(package.pagePhraseExtractions, mode: .additive)
                applyImportedAPIKeys(package.apiKeys)
                applyImportedProfile(package.profile, mode: .additive)
                if refreshSentenceLinks {
                    _ = refreshSentencePhraseLinks()
                    recordDatabaseOptimizationFingerprint(databaseOptimizationFingerprint())
                } else {
                    markDatabaseOptimizationNeeded()
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
                applyImportedPagePhraseExtractions(package.pagePhraseExtractions, mode: .complete)
                applyImportedAPIKeys(package.apiKeys)
                applyImportedProfile(package.profile, mode: .complete)
                if refreshSentenceLinks {
                    _ = refreshSentencePhraseLinks()
                    recordDatabaseOptimizationFingerprint(databaseOptimizationFingerprint())
                } else {
                    markDatabaseOptimizationNeeded()
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
        markDatabaseOptimizationNeeded()
        databaseOptimizationMessage = "Database optimization is recommended. Run Optimize Database from Settings when convenient."
    }

    func importSentenceLibraryPackage(_ package: SentenceLibraryExportPackage, mode: RestoreMode = .additive) async throws -> SentenceLibraryImportResult {
        _ = try? await createSentenceDatabaseSafetySnapshotForSettings(reason: "Before importing sentence library")
        let sentenceExamples = package.sentenceExamples
        let favoriteSentences = package.favoriteSentences
        let cleanedPages = preprocessedAICleanedPages(package.aiCleanedPages) ?? []
        let importedSentenceKeys = Set(
            sentenceExamples.map(\.normalizedChineseKey) +
            favoriteSentences.map { SentenceExampleRecord.normalizedChineseKey($0.simplified) }
        ).filter { !$0.isEmpty }
        RadixStudyPreferences.applyImportedSentenceExamples(sentenceExamples, mode: mode)
        applyImportedFavoriteSentences(favoriteSentences, mode: mode)
        RadixStudyPreferences.applyImportedAICleanedPages(cleanedPages, mode: mode)
        favoriteSentenceRevision += 1
        markDatabaseOptimizationNeeded()
        databaseOptimizationMessage = "Database optimization is recommended. Run Optimize Database from Settings when convenient."
        return SentenceLibraryImportResult(
            sentenceCount: importedSentenceKeys.count,
            extractedPageCount: cleanedPages.count
        )
    }

    func exportSentenceDatabaseData() async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            try RadixStudyPreferences.exportSentenceDatabaseData()
        }.value
    }

    func importSentenceDatabase(from sourceURL: URL, mode: RestoreMode) async throws -> Int {
        _ = try? await createSentenceDatabaseSafetySnapshotForSettings(reason: "Before importing sentence database")
        let importedCount = try await Task.detached(priority: .userInitiated) {
            try RadixStudyPreferences.importSentenceDatabase(from: sourceURL, mode: mode)
        }.value
        favoriteSentenceRevision += 1
        markDatabaseOptimizationNeeded()
        databaseOptimizationMessage = "Database optimization is recommended. Run Optimize Database from Settings when convenient."
        return importedCount
    }

    func clearSentenceDatabase() async throws {
        _ = try await createSentenceDatabaseSafetySnapshotForSettings(reason: "Before clearing sentence database")
        await Task.detached(priority: .userInitiated) {
            RadixStudyPreferences.clearSentenceDatabase()
        }.value
        favoriteSentenceRevision += 1
        dismissSidebarPhrasePreview()
    }
}
