import Foundation

extension RadixStore {
    // MARK: - Import

    func importDataEditData(_ data: Data, mode: RestoreMode = .additive) throws {
        try requireNoRestoreTransaction()
        let payload = try PortableBackupCodec().decode(data)
        try importDataEditPayload(payload, mode: mode)
    }

    func importDataEditPayload(
        _ payload: PortableBackupPayload,
        mode: RestoreMode = .additive,
        createSafetySnapshots: Bool = true,
        refreshSentenceLinks: Bool = false,
        importPhrases: Bool = true
    ) throws {
        try pageDeletionJournal.requireNoPendingDeletion()
        try PortableBackupCodec().validate(payload)
        if mode == .additive, case .unified(let package) = payload {
            try validateImportedCollectionMerge(package.collections)
        }
        pendingDatasetAutosaveWorkItem?.cancel()
        pendingDatasetAutosaveWorkItem = nil
        if createSafetySnapshots {
            try createDatabaseSafetySnapshots(reason: "Before importing data")
        }

        switch payload {
        case .unified(let package):
            let importedExtractedPages = try ExtractedSentenceRestoreRules.resolvedPages(
                from: package.extractedSentencePageReferences,
                sourceSchemaVersion: package.schemaVersion,
                mode: mode
            ) { pointer in
                RadixStudyPreferences.sentenceExample(id: pointer.sentenceExampleID)
                    ?? RadixStudyPreferences.sentenceExample(normalizedKey: pointer.sentenceKey)
            }
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
                if importPhrases {
                    try phraseRepo.addPhrasesAdditively(uniquePhrases(package.phrases))
                }
                try mergeImportedCollections(package.collections, selectedAICollectionID: package.selectedAICollectionID)
                try applyImportedConversationPracticePacks(package.conversationPracticePacks, mode: .additive)
                RadixStudyPreferences.conversationPracticeProgress =
                    RadixStudyPreferences.conversationPracticeProgress.merging(package.conversationPracticeProgress)
                applyImportedPagePhraseExtractions(package.pagePhraseExtractions, mode: .additive)
                try applyImportedExtractedSentencePages(importedExtractedPages, mode: .additive)
                applyImportedAPIKeys(package.apiKeys)
                applyImportedProfile(package.profile, mode: .additive)
                if refreshSentenceLinks {
                    _ = try refreshSentencePhraseLinks()
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
                if importPhrases {
                    try phraseRepo.replaceAllPhrases(uniquePhrases(package.phrases))
                }
                try replaceCollections(with: package.collections, selectedAICollectionID: package.selectedAICollectionID)
                try applyImportedConversationPracticePacks(package.conversationPracticePacks, mode: .complete)
                RadixStudyPreferences.conversationPracticeProgress =
                    package.conversationPracticeProgress ?? ConversationPracticeProgressSnapshot()
                applyImportedPagePhraseExtractions(package.pagePhraseExtractions, mode: .complete)
                try applyImportedExtractedSentencePages(importedExtractedPages, mode: .complete)
                applyImportedAPIKeys(package.apiKeys)
                applyImportedProfile(package.profile, mode: .complete)
                if refreshSentenceLinks {
                    _ = try refreshSentencePhraseLinks()
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
        try pageDeletionJournal.requireNoPendingDeletion()
        try requireNoRestoreTransaction()
        pageDeletionDeferralCount += 1
        defer { pageDeletionDeferralCount -= 1 }
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

    func importPortableBackupDocumentForRestore(_ document: PortableBackupDocument, mode: RestoreMode = .additive) async throws {
        try pageDeletionJournal.requireNoPendingDeletion()
        try restoreRollbackJournal.requireNoPendingRestore()
        guard !isRestoreTransactionActive, !databaseOptimizationInProgress, sharedImportTask == nil else {
            throw restoreFailure("Wait for the current data operation to finish before restoring a backup.")
        }
        pendingDatasetAutosaveWorkItem?.cancel()
        pendingDatasetAutosaveWorkItem = nil
        dataEditLoadTask?.cancel()
        dataEditLoadTask = nil
        isRestoreTransactionActive = true
        defer { isRestoreTransactionActive = false }
        pageDeletionDeferralCount += 1
        defer { pageDeletionDeferralCount -= 1 }
        try PortableBackupCodec().validate(document.payload)
        if mode == .additive, case .unified(let package) = document.payload {
            try validateImportedCollectionMerge(package.collections)
        }
        try validatePortableBackupDocumentDatabases(document)
        try await createDatabaseSafetySnapshotsForSettings(reason: "Before importing data")
        let rollbackDocument = PortableBackupDocument(
            payload: .unified(portableBackupPackage()),
            sentenceDatabaseData: try await exportSentenceDatabaseData(),
            addedPhrasesDatabaseData: try exportAddPhrasesDB()
        )
        let rollbackData = try DataExportService().exportPortableBackupBundle(
            package: try rollbackDocument.unifiedPackage(),
            sentenceDatabaseData: rollbackDocument.sentenceDatabaseData,
            addedPhrasesDatabaseData: rollbackDocument.addedPhrasesDatabaseData
        )
        try restoreRollbackJournal.begin(snapshotData: rollbackData) { data in
            let decoded = try DataExportService().decodePortableBackupDocument(data)
            try validatePortableBackupDocumentDatabases(decoded)
        }

        do {
            try await applyPortableBackupDocument(document, mode: mode)
            try flushRestorePersistence()
            try restoreRollbackJournal.finish()
        } catch {
            do {
                try await recoverPendingRestoreRollback()
            } catch let rollbackError {
                throw NSError(
                    domain: "Radix",
                    code: 3155,
                    userInfo: [NSLocalizedDescriptionKey: "Restore failed and Radix could not recover the previous data automatically: \(rollbackError.localizedDescription)"]
                )
            }
            throw error
        }
        markDatabaseOptimizationNeeded()
        databaseOptimizationMessage = "Database optimization is recommended. Run Optimize Database from Settings when convenient."
    }

    var restoreRollbackJournal: RestoreRollbackJournal {
        RestoreRollbackJournal(directoryURL: savedPageImageStore.restoreRollbackDirectoryURL)
    }

    func recoverPendingRestoreRollback() async throws {
        guard restoreRollbackJournal.isPending else { return }
        isRestoreTransactionActive = true
        defer { isRestoreTransactionActive = false }
        let data = try restoreRollbackJournal.rollbackData()
        let document = try DataExportService().decodePortableBackupDocument(data)
        try validatePortableBackupDocumentDatabases(document)
        try await applyPortableBackupDocument(document, mode: .complete)
        try flushRestorePersistence()
        try restoreRollbackJournal.finish()
    }

    private func flushRestorePersistence() throws {
        try preferences.flushPageDeletion()
        try RadixPreferences.standard.flushPageDeletion()
    }

    private func restoreFailure(_ message: String) -> NSError {
        NSError(domain: "Radix.RestoreRollback", code: 1,
                userInfo: [NSLocalizedDescriptionKey: message])
    }

    private func requireNoRestoreTransaction() throws {
        try restoreRollbackJournal.requireNoPendingRestore()
        guard !isRestoreTransactionActive else {
            throw restoreFailure("Wait for the current backup restore to finish before changing data.")
        }
    }

    private func validatePortableBackupDocumentDatabases(_ document: PortableBackupDocument) throws {
        var temporaryURLs: [URL] = []
        defer {
            for url in temporaryURLs {
                try? FileManager.default.removeItem(at: url)
            }
        }
        if let data = document.sentenceDatabaseData {
            let url = try temporaryDatabaseURL(prefix: "radix_sentence_validation", data: data)
            temporaryURLs.append(url)
            try SentenceLibraryStore.validateSentenceDatabase(at: url)
        }
        if let data = document.addedPhrasesDatabaseData {
            let url = try temporaryDatabaseURL(prefix: "radix_added_phrases_validation", data: data)
            temporaryURLs.append(url)
            try PhraseRepository.validateAddDatabase(at: url)
        }
    }

    private func applyPortableBackupDocument(_ document: PortableBackupDocument, mode: RestoreMode) async throws {
        var sentenceURL: URL?
        var phrasesURL: URL?
        defer {
            if let sentenceURL { try? FileManager.default.removeItem(at: sentenceURL) }
            if let phrasesURL { try? FileManager.default.removeItem(at: phrasesURL) }
        }

        if let sentenceDatabaseData = document.sentenceDatabaseData {
            let url = try temporaryDatabaseURL(prefix: "radix_sentence_restore", data: sentenceDatabaseData)
            try SentenceLibraryStore.validateSentenceDatabase(at: url)
            sentenceURL = url
        }
        if let addedPhrasesDatabaseData = document.addedPhrasesDatabaseData {
            let url = try temporaryDatabaseURL(prefix: "radix_added_phrases_restore", data: addedPhrasesDatabaseData)
            try PhraseRepository.validateAddDatabase(at: url)
            phrasesURL = url
        }

        if let sentenceURL {
            _ = try await Task.detached(priority: .userInitiated) {
                try RadixStudyPreferences.importSentenceDatabase(from: sentenceURL, mode: mode)
            }.value
            favoriteSentenceRevision += 1
        }
        if let phrasesURL {
            try importAddPhrasesDatabase(from: phrasesURL, mode: mode)
        }
        try importDataEditPayload(
            document.payload,
            mode: mode,
            createSafetySnapshots: false,
            refreshSentenceLinks: false,
            importPhrases: document.addedPhrasesDatabaseData == nil
        )
    }

    func importSentenceLibraryPackage(_ package: SentenceLibraryExportPackage, mode: RestoreMode = .additive) async throws -> SentenceLibraryImportResult {
        try pageDeletionJournal.requireNoPendingDeletion()
        try requireNoRestoreTransaction()
        pageDeletionDeferralCount += 1
        defer { pageDeletionDeferralCount -= 1 }
        _ = try? await createSentenceDatabaseSafetySnapshotForSettings(reason: "Before importing sentence library")
        let sentenceExamples = package.sentenceExamples
        let favoriteSentences = package.favoriteSentences
        let cleanedPages = preprocessedAICleanedPages(package.aiCleanedPages) ?? []
        let importedSentenceKeys = Set(
            sentenceExamples.map(\.normalizedChineseKey) +
            favoriteSentences.map { SentenceExampleRecord.normalizedChineseKey($0.simplified) }
        ).filter { !$0.isEmpty }
        try RadixStudyPreferences.applyImportedSentenceExamples(sentenceExamples, mode: mode)
        applyImportedFavoriteSentences(favoriteSentences, mode: mode)
        try RadixStudyPreferences.applyImportedAICleanedPages(cleanedPages, mode: mode)
        favoriteSentenceRevision += 1
        markDatabaseOptimizationNeeded()
        databaseOptimizationMessage = "Database optimization is recommended. Run Optimize Database from Settings when convenient."
        return SentenceLibraryImportResult(
            sentenceCount: importedSentenceKeys.count,
            extractedPageCount: cleanedPages.count
        )
    }

    private func temporaryDatabaseURL(prefix: String, data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)_\(UUID().uuidString)")
            .appendingPathExtension("sqlite")
        try data.write(to: url, options: .atomic)
        return url
    }

    private func applyImportedExtractedSentencePages(
        _ pages: [AICleanedPageRecord]?,
        mode: RestoreMode
    ) throws {
        guard let pages else { return }
        try RadixStudyPreferences.applyImportedAICleanedPages(pages, mode: mode)
        favoriteSentenceRevision += 1
    }

    func exportSentenceDatabaseData() async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            try RadixStudyPreferences.exportSentenceDatabaseData()
        }.value
    }

    func importSentenceDatabase(from sourceURL: URL, mode: RestoreMode) async throws -> Int {
        try pageDeletionJournal.requireNoPendingDeletion()
        try requireNoRestoreTransaction()
        pageDeletionDeferralCount += 1
        defer { pageDeletionDeferralCount -= 1 }
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
        try pageDeletionJournal.requireNoPendingDeletion()
        try requireNoRestoreTransaction()
        pageDeletionDeferralCount += 1
        defer { pageDeletionDeferralCount -= 1 }
        _ = try await createSentenceDatabaseSafetySnapshotForSettings(reason: "Before clearing sentence database")
        try await Task.detached(priority: .userInitiated) {
            try RadixStudyPreferences.clearSentenceDatabase()
        }.value
        favoriteSentenceRevision += 1
        dismissSidebarPhrasePreview()
    }
}
