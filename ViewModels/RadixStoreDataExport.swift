import Foundation

extension RadixStore {
    // MARK: - Export / snapshot

    func currentDataEditSnapshotJSON() -> String? {
        let key = dataEditCharacter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.count == 1, let entry = componentRepo.entry(for: key) else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(entry) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func portableBackupPackage(exportedAt: Date = Date(), backupID: UUID = UUID()) -> UnifiedPackage {
        RadixStudyPreferences.prepareExtractedPageSentenceExamplesForBackup()
        return UnifiedPackage(
            schemaVersion: PortableBackupCodec.currentSchemaVersion,
            exportedAt: exportedAt,
            backupID: backupID,
            baseDictionaryFingerprint: componentRepo.baseDictionaryFingerprint,
            dictionary: nil,
            dictionaryOverlay: nil,
            dictionaryPatchOverlay: componentRepo.overlayPatchPackage(),
            phrases: phraseRepo.fetchAddedPhrases(),
            profile: currentUserProfile(),
            collections: allCollections.map(collectionForPortableBackup),
            selectedAICollectionID: selectedAICollectionID,
            conversationPracticePacks: RadixStudyPreferences.importedConversationPracticePacks,
            conversationPracticeProgress: RadixStudyPreferences.conversationPracticeProgress,
            favoriteSentences: nil,
            sentenceExamples: nil,
            pagePhraseExtractions: RadixStudyPreferences.pagePhraseExtractions,
            aiCleanedPages: nil,
            extractedSentencePageReferences: extractedSentenceReferencePackage(),
            apiKeys: currentAPIKeyBackup()
        )
    }

    func sentenceLibraryExportPackage(exportedAt: Date = Date()) -> SentenceLibraryExportPackage {
        RadixStudyPreferences.prepareSentenceExamplesForBackup()
        return SentenceLibraryExportPackage(
            exportedAt: exportedAt,
            sentenceExamples: RadixStudyPreferences.sentenceExamples,
            favoriteSentences: RadixStudyPreferences.favoriteSentences,
            aiCleanedPages: RadixStudyPreferences.aiCleanedPages
        )
    }

    func fullDatasetExportPackage() -> FullDatasetExportPackage {
        let exportedAt = Date()
        return FullDatasetExportPackage(
            schemaVersion: 2,
            exportedAt: exportedAt,
            dictionary: componentRepo.rawMap,
            phrases: phraseRepo.fetchAllPhrases(),
            portableBackup: portableBackupPackage(exportedAt: exportedAt)
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
        try pageDeletionJournal.requireNoPendingDeletion()
        try restoreRollbackJournal.requireNoPendingRestore()
        guard !isRestoreTransactionActive else {
            throw NSError(domain: "Radix.RestoreRollback", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Wait for the current backup restore to finish."])
        }
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

    private func extractedSentenceReferencePackage() -> ExtractedSentenceReferencePackage? {
        let pages = RadixStudyPreferences.aiCleanedPages
        guard !pages.isEmpty else { return nil }

        let sentenceKeys = pages.flatMap { page in
            page.sentences.enumerated().compactMap { _, sentence in
                let key = SentenceExampleRecord.normalizedChineseKey(sentence.chinese)
                return key.isEmpty ? nil : key
            }
        }
        guard !sentenceKeys.isEmpty else { return nil }

        let recordsByKey = RadixStudyPreferences.sentenceExamples(normalizedKeys: Array(Set(sentenceKeys)))
        let referencedPages = pages.compactMap { page -> ExtractedSentencePageReference? in
            let pointers = page.sentences.enumerated().compactMap { index, sentence -> ExtractedSentencePointer? in
                let key = SentenceExampleRecord.normalizedChineseKey(sentence.chinese)
                guard !key.isEmpty, let record = recordsByKey[key] else { return nil }
                return ExtractedSentencePointer(
                    pageSentenceID: sentence.id,
                    sentenceExampleID: record.id,
                    sentenceKey: key,
                    ordinal: index
                )
            }
            guard !pointers.isEmpty else { return nil }
            return ExtractedSentencePageReference(
                sourcePageID: page.sourcePageID,
                sourceTitle: page.sourceTitle,
                cleanedTitle: page.cleanedTitle,
                sentenceReferences: pointers,
                createdAt: page.createdAt
            )
        }
        guard !referencedPages.isEmpty else { return nil }

        let stats = RadixStudyPreferences.sentenceOptimizationStats()
        return ExtractedSentenceReferencePackage(
            sentenceDatabaseFingerprint: SentenceDatabasePointerFingerprint(
                sentenceCount: stats.count,
                latestCreatedAt: stats.latestCreatedAt,
                latestUpdatedAt: stats.latestUpdatedAt,
                normalizedKeyHash: stats.normalizedKeyHash
            ),
            pages: referencedPages
        )
    }
}
