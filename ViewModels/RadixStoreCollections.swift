import Foundation
import SwiftUI

/*
 RADIX STORE — COLLECTIONS
 ==========================
 Manages CharacterCollection CRUD, persistence, and selection state.
 Saved pages and their selection IDs are owned by RadixCollectionState and
 exposed through compatibility properties on RadixStore.
*/

struct PageDeletionImpact {
    let pageName: String
    let ownedArtifacts: [PageArtifactDescriptor]
    let linkedArtifacts: [PageArtifactDescriptor]

    var alertMessage: String {
        [
            "Delete \"\(pageName)\" from saved pages?",
            "Page-owned work removed: \(Self.summaryList(ownedArtifacts.map(\.displayTitle))).",
            "Learning memory kept: \(Self.summaryList(linkedArtifacts.map(\.displayTitle)))."
        ].joined(separator: "\n\n")
    }

    private static func summaryList(_ values: [String]) -> String {
        let uniqueValues = Array(NSOrderedSet(array: values)).compactMap { $0 as? String }
        guard !uniqueValues.isEmpty else { return "none" }
        if uniqueValues.count <= 3 {
            return uniqueValues.joined(separator: ", ")
        }
        return uniqueValues.prefix(3).joined(separator: ", ") + ", and \(uniqueValues.count - 3) more"
    }
}

extension RadixStore {

    func validateImportedCollectionMerge(_ importedCollections: [CharacterCollection]?) throws {
        guard let importedCollections else { return }
        var localByID: [UUID: CharacterCollection] = [:]
        for collection in allCollections where localByID[collection.id] == nil {
            localByID[collection.id] = collection
        }
        for incoming in sanitizeCollections(importedCollections) {
            guard let local = localByID[incoming.id],
                  SavedPageMergeRules.decision(local: local, incoming: incoming) == .conflict
            else { continue }
            throw NSError(
                domain: "Radix",
                code: 3157,
                userInfo: [NSLocalizedDescriptionKey: "Merge stopped because saved page \"\(local.name)\" has conflicting edits that cannot be ordered safely. This device and the backup were left unchanged."]
            )
        }
    }

    func mergeImportedCollections(_ importedCollections: [CharacterCollection]?, selectedAICollectionID importedSelectedID: UUID?) throws {
        guard let importedCollections else { return }
        var mergedByID: [UUID: CharacterCollection] = [:]
        for collection in allCollections where mergedByID[collection.id] == nil {
            mergedByID[collection.id] = collection
        }
        for incoming in sanitizeCollections(importedCollections) {
            if let local = mergedByID[incoming.id] {
                switch SavedPageMergeRules.decision(local: local, incoming: incoming) {
                case .keepLocal, .conflict:
                    continue
                case .useIncoming:
                    break
                }
            }
            mergedByID[incoming.id] = prepareCollectionForLiveStorage(incoming)
        }
        allCollections = Array(mergedByID.values)
        sortCollections()
        persistCollections()

        if let importedSelectedID, collection(id: importedSelectedID) != nil {
            selectedAICollectionID = importedSelectedID
        }
        if let selectedBrowseCollectionID, collection(id: selectedBrowseCollectionID) == nil {
            self.selectedBrowseCollectionID = nil
        }
    }

    func replaceCollections(with importedCollections: [CharacterCollection]?, selectedAICollectionID importedSelectedID: UUID?) throws {
        try savedPageImageStore.removeAllImagesForRestore()
        allCollections = sanitizeCollections(importedCollections ?? []).map(prepareCollectionForLiveStorage)
        sortCollections()
        try persistCollectionsForRestore()
        selectedAICollectionID = importedSelectedID.flatMap { collection(id: $0) == nil ? nil : $0 }
        if let selectedBrowseCollectionID, collection(id: selectedBrowseCollectionID) == nil {
            self.selectedBrowseCollectionID = nil
        }
    }

    func sanitizeCollections(_ collections: [CharacterCollection]) -> [CharacterCollection] {
        let validCollections = collections.compactMap { collection in
            var copy = collection
            copy.characters = CaptureTextExtractor.allCharactersInOrder(in: collection.characters.joined())
            return copy.characters.isEmpty ? nil : copy
        }
        return CharacterCollectionIdentityRules.keepingFirstUniqueID(in: validCollections)
    }

    // MARK: - Computed accessors

    var favoriteCollections: [CharacterCollection] {
        allCollections.filter(\.isFavorite)
    }

    var selectedBrowseCollection: CharacterCollection? {
        selectedBrowseCollectionID.flatMap { collection(id: $0) }
    }

    var selectedAICollection: CharacterCollection? {
        selectedAICollectionID.flatMap { collection(id: $0) }
    }

    var mostRecentlyViewedCollection: CharacterCollection? {
        SavedPageRules.mostRecentID(in: allCollections).flatMap { collection(id: $0) }
    }

    func selectMostRecentBrowsePage() {
        selectBrowseCollection(id: mostRecentlyViewedCollection?.id)
    }

    // MARK: - CRUD

    @discardableResult
    func createCollection(
        id: UUID = UUID(),
        name: String,
        sourceText: String,
        sourceType: CollectionSourceType,
        sourceImageJPEGData: Data? = nil,
        originalOCRText: String? = nil
    ) -> CharacterCollection? {
        guard !isRestoreTransactionActive, !restoreRollbackJournal.isPending else { return nil }
        if let existing = collection(id: id) {
            return existing
        }
        let validation = collectionCharacterValidation(for: sourceText)
        guard validation.hasChineseCharacters else { return nil }
        let characters = validation.charactersInReadingOrder
        let fallbackName: String = {
            switch sourceType {
            case .ocr: return "OCR Image"
            case .manual: return "Manual Image"
            case .imported: return "Imported Image"
            case .other: return "Image"
        }
        }()
        let cleanName = collectionDisplayName(name)
        let sourceName = collectionNameFromSourceCharacters(characters)
        let collection = CharacterCollection(
            id: id,
            name: cleanName.isEmpty ? (sourceName.isEmpty ? fallbackName : sourceName) : cleanName,
            characters: characters,
            createdAt: Date(),
            lastViewedAt: Date(),
            sourceType: sourceType,
            isFavorite: false,
            sourceImageJPEGData: sourceImageJPEGData,
            originalOCRText: originalOCRText?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        saveCollection(collection)
        return self.collection(id: collection.id) ?? collection
    }

    func saveCollection(_ collection: CharacterCollection) {
        var collection = prepareCollectionForLiveStorage(collection)
        collection.contentModifiedAt = Date()
        browsePagePhraseTileCache.removeValue(forKey: collection.id)
        browsePagePhraseCandidateCache.removeValue(forKey: collection.id)
        if let index = allCollections.firstIndex(where: { $0.id == collection.id }) {
            allCollections[index] = collection
        } else {
            allCollections.append(collection)
        }
        sortCollections()
        if selectedBrowseCollectionID == collection.id {
            selectedBrowseCollectionCharacters = Set(collection.characters)
            activeSubject = .collection(collection)
        }
        persistCollections()
    }

    func collectionCharacterValidation(for sourceText: String) -> CaptureCharacterValidation {
        CaptureTextExtractor.characterValidation(in: sourceText, dictionaryContains: componentRepo.hasCharacter)
    }

    func deletionImpact(for collection: CharacterCollection) -> PageDeletionImpact {
        let correctedPages = correctedCollectionDescendants(of: collection.id)
        let removedCollectionIDs = Set(correctedPages.map(\.id)).union([collection.id])
        let linkedPracticePacks = RadixStudyPreferences.importedConversationPracticePacks
            .filter { $0.sourceLink?.isLinked(toAnyPageID: removedCollectionIDs) == true }
        let linkedPracticePackIDs = Set(linkedPracticePacks.map(\.packID))
        let favoriteSentences = RadixStudyPreferences.favoriteSentences
            .filter { linkedPracticePackIDs.contains($0.sourceSetID) }
        let progressPackIDs = Set(RadixStudyPreferences.conversationPracticeProgress.records.map(\.packID))
            .intersection(linkedPracticePackIDs)
        let pagePhraseExtraction = RadixStudyPreferences.pagePhraseExtractions
            .first { $0.sourcePageID == collection.id }
        let aiCleanedPage = RadixStudyPreferences.aiCleanedPage(for: collection.id)

        var ownedArtifacts: [PageArtifactDescriptor] = []
        if let aiCleanedPage {
            ownedArtifacts.append(aiCleanedPage.artifactDescriptor)
        }
        ownedArtifacts.append(contentsOf: correctedPages.map {
            PageArtifactDescriptor(
                sourcePageID: collection.id,
                artifactType: .correctedOCRPage,
                artifactID: $0.id.uuidString,
                displayTitle: "corrected page \"\($0.name)\"",
                createdAt: $0.createdAt
            )
        })
        if collection.translationReport?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            ownedArtifacts.append(PageArtifactDescriptor(
                sourcePageID: collection.id,
                artifactType: .translation,
                artifactID: "translation",
                displayTitle: "page translation",
                createdAt: collection.translationReportUpdatedAt
            ))
        }
        ownedArtifacts.append(contentsOf: linkedPracticePacks.map {
            PageArtifactDescriptor(
                sourcePageID: collection.id,
                artifactType: .pageConversationPractice,
                artifactID: $0.packID,
                displayTitle: "practice pack \"\($0.title)\"",
                createdAt: $0.sourceLink?.sourceCreatedAt
            )
        })
        if let pagePhraseExtraction {
            ownedArtifacts.append(PageArtifactDescriptor(
                sourcePageID: collection.id,
                artifactType: .pageAIResult,
                artifactID: "extracted-phrases",
                displayTitle: "page phrase list (\(pagePhraseExtraction.phraseWords.count) phrase\(pagePhraseExtraction.phraseWords.count == 1 ? "" : "s"))",
                createdAt: pagePhraseExtraction.extractedAt
            ))
        }

        var linkedArtifacts: [PageArtifactDescriptor] = favoriteSentences.map {
            PageArtifactDescriptor(
                sourcePageID: collection.id,
                artifactType: .favoriteSentence,
                artifactID: $0.id,
                displayTitle: "favorite sentence",
                createdAt: $0.favoritedAt
            )
        }
        linkedArtifacts.append(contentsOf: progressPackIDs.map {
            PageArtifactDescriptor(
                sourcePageID: collection.id,
                artifactType: .reusablePracticeProgress,
                artifactID: $0,
                displayTitle: "practice progress",
                createdAt: nil
            )
        })
        if let pagePhraseExtraction {
            let addedPhraseCount = pagePhraseExtraction.phraseWords
                .filter { !isPhraseInBase($0) && isPhraseInAdd($0) }
                .count
            if addedPhraseCount > 0 {
                linkedArtifacts.append(PageArtifactDescriptor(
                    sourcePageID: collection.id,
                    artifactType: .addedPhrase,
                    artifactID: "added-phrases",
                    displayTitle: "\(addedPhraseCount) added phrase\(addedPhraseCount == 1 ? "" : "s")",
                    createdAt: pagePhraseExtraction.extractedAt
                ))
            }
        }

        return PageDeletionImpact(
            pageName: collection.name,
            ownedArtifacts: ownedArtifacts,
            linkedArtifacts: linkedArtifacts
        )
    }

    private func requirePageDeletionAvailable() throws {
        guard pageDeletionDeferralCount == 0, !databaseOptimizationInProgress else {
            throw NSError(domain: "Radix.PageDeletion", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Wait for the current data operation to finish before deleting a page."
            ])
        }
        try pageDeletionJournal.requireNoPendingDeletion()
        try restoreRollbackJournal.requireNoPendingRestore()
    }

    func deleteCollection(id: UUID) async throws {
        guard !isPreparingPageDeletion else {
            throw NSError(domain: "Radix.PageDeletion", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "A page deletion is already being prepared."
            ])
        }
        try requirePageDeletionAvailable()
        guard collection(id: id) != nil else { return }
        isPreparingPageDeletion = true
        defer { isPreparingPageDeletion = false }
        let descendantIDs = Set(correctedCollectionDescendants(of: id).map(\.id))
        let removedCollectionIDs = descendantIDs.union([id])
        let journal = pageDeletionJournal
        let snapshot = try journal.captureSnapshot()
        let importRevision = dataImportRevision
        let prepared = try await Task.detached(priority: .userInitiated) {
            try PageDeletionJournal.prepare(pageIDs: removedCollectionIDs, snapshot: snapshot)
        }.value
        try Task.checkCancellation()
        try requirePageDeletionAvailable()
        guard dataImportRevision == importRevision else {
            throw NSError(domain: "Radix.PageDeletion", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Data changed while preparing deletion. Your changes were kept. Please retry."
            ])
        }

        do {
            try journal.commit(prepared)
        } catch {
            if pageDeletionJournal.isPending {
                pageDeletionRecoveryError = error.localizedDescription
            }
            throw error
        }

        allCollections.removeAll { removedCollectionIDs.contains($0.id) }
        for removedID in removedCollectionIDs {
            browsePagePhraseTileCache.removeValue(forKey: removedID)
            browsePagePhraseCandidateCache.removeValue(forKey: removedID)
        }
        if selectedBrowseCollectionID.map(removedCollectionIDs.contains) == true {
            selectedBrowseCollectionID = nil
            selectedBrowseCollectionCharacters = nil
        }
        if selectedAICollectionID.map(removedCollectionIDs.contains) == true {
            selectedAICollectionID = nil
        }
        if prepared.removedPracticePackIDs.contains(selectedConversationPracticeTopicID) {
            selectedConversationPracticeTopicID = ConversationPracticeTopic.generalGreetings.id
            activePracticeSentenceItem = nil
            pendingConversationPracticeTopicID = nil
            dismissSidebarPhrasePreview()
            persistPromptSettings()
        }
        favoriteSentenceRevision += 1
        dataImportRevision += 1
    }

    var pageDeletionJournal: PageDeletionJournal {
        PageDeletionJournal(
            url: savedPageImageStore.deletionJournalURL,
            preferences: preferences,
            studyPreferences: RadixPreferences.standard,
            reconcileSentences: { ids in
                _ = try RadixStudyPreferences.reconcileSentenceSourcesAfterDeletingPages(ids)
            },
            flushPreferences: {
                try self.preferences.flushPageDeletion()
                try RadixPreferences.standard.flushPageDeletion()
            },
            removeImage: { try self.savedPageImageStore.removeImageForConfirmedDeletion(for: $0) }
        )
    }

    func recoverPendingPageDeletion() throws {
        do {
            let wasPending = pageDeletionJournal.isPending
            try pageDeletionJournal.recover()
            if wasPending {
                activePracticeSentenceItem = nil
                pendingConversationPracticeTopicID = nil
                dismissSidebarPhrasePreview()
                browsePagePhraseTileCache.removeAll()
                browsePagePhraseCandidateCache.removeAll()
                favoriteSentenceRevision += 1
                dataImportRevision += 1
            }
        } catch {
            pageDeletionRecoveryError = error.localizedDescription
            throw error
        }
    }

    @discardableResult
    func promoteCorrectedOCRCollection(
        correctedID: UUID,
        keepOriginalAsArchive: Bool
    ) -> CharacterCollection? {
        guard let correctedIndex = allCollections.firstIndex(where: { $0.id == correctedID }),
              let originalID = allCollections[correctedIndex].correctedFromCollectionID,
              let originalIndex = allCollections.firstIndex(where: { $0.id == originalID })
        else { return nil }

        let original = allCollections[originalIndex]
        let corrected = allCollections[correctedIndex]
        let now = Date()

        var promoted = original
        promoted.name = original.name
        promoted.characters = corrected.characters
        promoted.sourceType = corrected.sourceType
        promoted.thumbnailJPEGData = nil
        promoted.sourceImageJPEGData = sourceImageJPEGData(for: corrected) ?? sourceImageJPEGData(for: original)
        promoted.originalOCRText = original.originalOCRText ?? corrected.originalOCRText ?? original.characters.joined()
        promoted.reviewedOCRText = corrected.reviewedOCRText ?? corrected.characters.joined()
        promoted.ocrReviewedAt = corrected.ocrReviewedAt ?? now
        promoted.correctedFromCollectionID = nil
        promoted.hiddenPhraseWords = corrected.hiddenPhraseWords ?? original.hiddenPhraseWords
        promoted.lastViewedAt = now
        promoted.contentModifiedAt = now

        var replacementCollections = allCollections.filter { $0.id != correctedID }
        if let index = replacementCollections.firstIndex(where: { $0.id == originalID }) {
            replacementCollections[index] = promoted
        }

        if keepOriginalAsArchive {
            let archive = archivedOriginalCollection(from: original, promotedAt: now)
            replacementCollections.append(archive)
        }

        replacementCollections = replacementCollections.map { collection in
            guard collection.correctedFromCollectionID == correctedID else { return collection }
            var copy = collection
            copy.correctedFromCollectionID = originalID
            copy.contentModifiedAt = now
            return copy
        }

        allCollections = replacementCollections.map(prepareCollectionForLiveStorage)
        savedPageImageStore.removeImage(for: correctedID)
        sortCollections()
        browsePagePhraseTileCache.removeValue(forKey: originalID)
        browsePagePhraseCandidateCache.removeValue(forKey: originalID)
        browsePagePhraseTileCache.removeValue(forKey: correctedID)
        browsePagePhraseCandidateCache.removeValue(forKey: correctedID)

        if selectedBrowseCollectionID == correctedID {
            selectedBrowseCollectionID = originalID
        }
        if selectedAICollectionID == correctedID {
            selectedAICollectionID = originalID
        }
        let storedPromoted = collection(id: originalID) ?? promoted
        if selectedBrowseCollectionID == originalID {
            selectedBrowseCollectionCharacters = Set(storedPromoted.characters)
            activeSubject = .collection(storedPromoted)
        }
        persistCollections()
        return storedPromoted
    }

    func renameCollection(id: UUID, newName: String) {
        guard let index = allCollections.firstIndex(where: { $0.id == id }) else { return }
        let cleanName = collectionDisplayName(newName)
        guard !cleanName.isEmpty else { return }
        allCollections[index].name = cleanName
        saveCollection(allCollections[index])
    }

    func updateCollectionTranslationReport(id: UUID, report: String?) {
        guard let index = allCollections.firstIndex(where: { $0.id == id }) else { return }
        let cleanReport = report?.trimmingCharacters(in: .whitespacesAndNewlines)
        allCollections[index].translationReport = cleanReport?.isEmpty == true ? nil : cleanReport
        allCollections[index].translationReportUpdatedAt = allCollections[index].translationReport == nil ? nil : Date()
        saveCollection(allCollections[index])
    }

    @discardableResult
    func createCorrectedOCRCollection(from id: UUID, correctedText: String) -> CharacterCollection? {
        guard let original = allCollections.first(where: { $0.id == id }) else { return nil }
        let cleanText = correctedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let characters = CaptureTextExtractor.allCharactersInOrder(in: cleanText)
        guard !characters.isEmpty else { return nil }

        let correctedName = SavedPageRules.correctedName(
            originalName: original.name,
            existingNames: Set(allCollections.map(\.name))
        )
        let corrected = CharacterCollection(
            id: UUID(),
            name: correctedName.isEmpty ? "Corrected" : correctedName,
            characters: characters,
            createdAt: Date(),
            lastViewedAt: Date(),
            sourceType: .ocr,
            isFavorite: false,
            sourceImageJPEGData: sourceImageJPEGData(for: original),
            originalOCRText: original.originalOCRText ?? original.characters.joined(),
            reviewedOCRText: cleanText,
            ocrReviewedAt: Date(),
            correctedFromCollectionID: original.id
        )
        saveCollection(corrected)
        return collection(id: corrected.id) ?? corrected
    }

    @discardableResult
    func createUnreviewedPhraseReviewCollection() -> CharacterCollection? {
        guard let sourceText = AddedPhraseReviewRules.aiReviewPageText(
            from: phraseRepo.fetchAddedPhrases(),
            isBasePhrase: isPhraseInBase
        ) else { return nil }

        return createCollection(
            name: AddedPhraseReviewRules.aiReviewPageName,
            sourceText: sourceText,
            sourceType: .manual
        )
    }

    @discardableResult
    func updateCollection(id: UUID, newName: String, sourceText: String) -> CharacterCollection? {
        guard let index = allCollections.firstIndex(where: { $0.id == id }) else { return nil }
        let cleanName = collectionDisplayName(newName)
        guard !cleanName.isEmpty else { return nil }

        let characters = CaptureTextExtractor.allCharactersInOrder(in: sourceText)
        guard !characters.isEmpty else { return nil }

        var updated = allCollections[index]
        updated.name = cleanName
        updated.characters = characters
        saveCollection(updated)
        return updated
    }

    func toggleFavoriteCollection(id: UUID) {
        guard let index = allCollections.firstIndex(where: { $0.id == id }) else { return }
        allCollections[index].isFavorite.toggle()
        saveCollection(allCollections[index])
    }

    func setCollectionPhraseHidden(collectionID: UUID, phraseWord: String, hidden: Bool) {
        guard let index = allCollections.firstIndex(where: { $0.id == collectionID }) else { return }
        var hiddenWords = allCollections[index].hiddenPhraseWords ?? []
        if hidden {
            hiddenWords.insert(phraseStorageWord(phraseWord))
        } else {
            hiddenWords.remove(phraseStorageWord(phraseWord))
        }
        allCollections[index].hiddenPhraseWords = hiddenWords.isEmpty ? nil : hiddenWords
        saveCollection(allCollections[index])
        imagePhraseHighlightRevision += 1
    }

    func collection(id: UUID) -> CharacterCollection? {
        allCollections.first { $0.id == id }
    }

    // MARK: - Selection

    func selectBrowseCollection(id: UUID?) {
        if let id, let index = allCollections.firstIndex(where: { $0.id == id }) {
            allCollections[index].lastViewedAt = Date()
            persistCollections()
        }
        selectedBrowseCollectionID = id
        if let id {
            selectedAICollectionID = id
            gridSortMode = .readingOrder
        } else {
            gridSortMode = .characterFrequency
            imagePhraseContext = nil
            imagePhraseHighlightOffsets = []
            clearAnchoredImagePhraseHighlight()
            imageBrowsePhrasePreview = nil
            sidebarPhrasePreview = nil
            imagePhraseHighlightRevision += 1
        }
    }

    func selectAICollection(id: UUID?) {
        selectedAICollectionID = id
    }

    // MARK: - Persistence

    func loadCollections() {
        guard let data = preferences.data(forKey: RadixPreferenceKey.collections),
              let decoded = try? JSONDecoder().decode([CharacterCollection].self, from: data) else {
            allCollections = []
            return
        }
        let sanitized = sanitizeCollections(decoded)
        allCollections = sanitized.map(prepareCollectionForLiveStorage)
        savedPageImageStore.pruneImages(keeping: Set(allCollections.map(\.id)))
        if allCollections != decoded {
            persistCollections()
        }
        sortCollections()
        if let saved = preferences.string(forKey: RadixPreferenceKey.selectedAICollection),
           let id = UUID(uuidString: saved),
           collection(id: id) != nil {
            selectedAICollectionID = id
        } else {
            selectedAICollectionID = nil
        }
    }

    func persistCollections() {
        if let data = try? JSONEncoder().encode(allCollections) {
            preferences.set(data, forKey: RadixPreferenceKey.collections)
        }
    }

    private func persistCollectionsForRestore() throws {
        preferences.set(try JSONEncoder().encode(allCollections), forKey: RadixPreferenceKey.collections)
    }

    func sourceImageJPEGData(for collection: CharacterCollection) -> Data? {
        collection.sourceImageJPEGData
            ?? collection.thumbnailJPEGData
            ?? savedPageImageStore.imageData(for: collection.id)
    }

    func collectionForPortableBackup(_ collection: CharacterCollection) -> CharacterCollection {
        var copy = collection
        copy.thumbnailJPEGData = nil
        copy.sourceImageJPEGData = sourceImageJPEGData(for: collection)
        return copy
    }

    func persistSelectedAICollection() {
        if let selectedAICollectionID {
            preferences.set(selectedAICollectionID.uuidString, forKey: RadixPreferenceKey.selectedAICollection)
        } else {
            preferences.removeObject(forKey: RadixPreferenceKey.selectedAICollection)
        }
    }

    // MARK: - Private helpers

    func sortCollections() {
        allCollections.sort {
            if $0.isFavorite != $1.isFavorite { return $0.isFavorite && !$1.isFavorite }
            if $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    func sortedCollections(order: PageCollectionSortOrder) -> [CharacterCollection] {
        allCollections.sorted {
            if $0.isFavorite != $1.isFavorite { return $0.isFavorite && !$1.isFavorite }
            switch order {
            case .lastViewed:
                let lhsDate = $0.lastViewedAt ?? $0.createdAt
                let rhsDate = $1.lastViewedAt ?? $1.createdAt
                if lhsDate != rhsDate { return lhsDate > rhsDate }
            case .scanned:
                if $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
            }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    func collectionDisplayName(_ name: String) -> String {
        SavedPageRules.normalizedName(name)
    }

    func collectionNameFromSourceCharacters(_ characters: [String]) -> String {
        String(characters.prefix(11).joined())
    }

    private func archivedOriginalCollection(from collection: CharacterCollection, promotedAt: Date) -> CharacterCollection {
        CharacterCollection(
            id: UUID(),
            name: archivedOriginalName(for: collection.name),
            characters: collection.characters,
            createdAt: promotedAt,
            lastViewedAt: nil,
            contentModifiedAt: promotedAt,
            sourceType: collection.sourceType,
            isFavorite: false,
            sourceImageJPEGData: sourceImageJPEGData(for: collection),
            originalOCRText: collection.originalOCRText,
            reviewedOCRText: collection.reviewedOCRText,
            ocrReviewedAt: collection.ocrReviewedAt,
            correctedFromCollectionID: nil,
            translationReport: nil,
            translationReportUpdatedAt: nil,
            hiddenPhraseWords: collection.hiddenPhraseWords
        )
    }

    private func prepareCollectionForLiveStorage(_ collection: CharacterCollection) -> CharacterCollection {
        var copy = collection
        guard let embeddedImage = collection.sourceImageJPEGData ?? collection.thumbnailJPEGData else {
            copy.thumbnailJPEGData = nil
            return copy
        }

        do {
            try savedPageImageStore.store(embeddedImage, for: collection.id)
            copy.thumbnailJPEGData = nil
            copy.sourceImageJPEGData = nil
        } catch {
            // Retain one inline copy if file persistence fails so the user's source is not lost.
            copy.thumbnailJPEGData = nil
            copy.sourceImageJPEGData = embeddedImage
        }
        return copy
    }

    private func archivedOriginalName(for name: String) -> String {
        let existingNames = Set(allCollections.map(\.name))
        let stem = collectionDisplayName(name)
        for suffix in 1...99 {
            let prefix = "Old"
            let suffixText = String(suffix)
            let available = max(0, SavedPageRules.maximumGeneratedNameLength - prefix.count - suffixText.count)
            let candidate = prefix + String(stem.prefix(available)) + suffixText
            if !existingNames.contains(candidate) {
                return candidate
            }
        }
        return String(UUID().uuidString.prefix(SavedPageRules.maximumGeneratedNameLength))
    }

    private func correctedCollectionDescendants(of id: UUID) -> [CharacterCollection] {
        var descendants: [CharacterCollection] = []
        var pending = [id]
        var seen: Set<UUID> = [id]
        while let sourceID = pending.popLast() {
            let children = allCollections.filter { $0.correctedFromCollectionID == sourceID && !seen.contains($0.id) }
            for child in children {
                seen.insert(child.id)
                descendants.append(child)
                pending.append(child.id)
            }
        }
        return descendants
    }

}
