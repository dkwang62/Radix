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

    func mergeImportedCollections(_ importedCollections: [CharacterCollection]?, selectedAICollectionID importedSelectedID: UUID?) {
        guard let importedCollections else { return }
        var mergedByID = Dictionary(uniqueKeysWithValues: allCollections.map { ($0.id, $0) })
        for collection in sanitizeCollections(importedCollections) {
            mergedByID[collection.id] = collection
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

    func replaceCollections(with importedCollections: [CharacterCollection]?, selectedAICollectionID importedSelectedID: UUID?) {
        allCollections = sanitizeCollections(importedCollections ?? [])
        sortCollections()
        persistCollections()
        selectedAICollectionID = importedSelectedID.flatMap { collection(id: $0) == nil ? nil : $0 }
        if let selectedBrowseCollectionID, collection(id: selectedBrowseCollectionID) == nil {
            self.selectedBrowseCollectionID = nil
        }
    }

    func sanitizeCollections(_ collections: [CharacterCollection]) -> [CharacterCollection] {
        collections.compactMap { collection in
            var copy = collection
            copy.characters = collection.characters.filter { componentRepo.hasCharacter($0) }
            return copy.characters.isEmpty ? nil : copy
        }
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
        name: String,
        sourceText: String,
        sourceType: CollectionSourceType,
        thumbnailJPEGData: Data? = nil,
        sourceImageJPEGData: Data? = nil,
        originalOCRText: String? = nil
    ) -> CharacterCollection? {
        let characters = CaptureTextExtractor.allCharactersInOrder(in: sourceText).filter { componentRepo.hasCharacter($0) }
        guard !characters.isEmpty else { return nil }
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
            id: UUID(),
            name: cleanName.isEmpty ? (sourceName.isEmpty ? fallbackName : sourceName) : cleanName,
            characters: characters,
            createdAt: Date(),
            lastViewedAt: Date(),
            sourceType: sourceType,
            isFavorite: false,
            thumbnailJPEGData: thumbnailJPEGData,
            sourceImageJPEGData: sourceImageJPEGData,
            originalOCRText: originalOCRText?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        saveCollection(collection)
        return collection
    }

    func saveCollection(_ collection: CharacterCollection) {
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

    func deletionImpact(for collection: CharacterCollection) -> PageDeletionImpact {
        let correctedPages = correctedCollectionDescendants(of: collection.id)
        let linkedPracticePacks = RadixStudyPreferences.importedConversationPracticePacks
            .filter { $0.sourceLink?.sourcePageID == collection.id }
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

    func deleteCollection(id: UUID) {
        let descendantIDs = Set(correctedCollectionDescendants(of: id).map(\.id))
        let removedCollectionIDs = descendantIDs.union([id])
        let removedPracticePackIDs = Set(RadixStudyPreferences.importedConversationPracticePacks
            .filter { $0.sourceLink?.sourcePageID == id }
            .map(\.packID))

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
        if !removedPracticePackIDs.isEmpty {
            var packs = RadixStudyPreferences.importedConversationPracticePacks
            packs.removeAll { removedPracticePackIDs.contains($0.packID) }
            RadixStudyPreferences.importedConversationPracticePacks = packs
            if removedPracticePackIDs.contains(selectedConversationPracticeTopicID) {
                selectedConversationPracticeTopicID = ConversationPracticeTopic.generalGreetings.id
                persistPromptSettings()
            }
        }
        var phraseExtractions = RadixStudyPreferences.pagePhraseExtractions
        phraseExtractions.removeAll { removedCollectionIDs.contains($0.sourcePageID) }
        RadixStudyPreferences.pagePhraseExtractions = phraseExtractions
        var cleanedPages = RadixStudyPreferences.aiCleanedPages
        cleanedPages.removeAll { removedCollectionIDs.contains($0.sourcePageID) }
        RadixStudyPreferences.aiCleanedPages = cleanedPages
        persistCollections()
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
        promoted.thumbnailJPEGData = corrected.thumbnailJPEGData ?? original.thumbnailJPEGData
        promoted.sourceImageJPEGData = corrected.sourceImageJPEGData ?? original.sourceImageJPEGData
        promoted.originalOCRText = original.originalOCRText ?? corrected.originalOCRText ?? original.characters.joined()
        promoted.reviewedOCRText = corrected.reviewedOCRText ?? corrected.characters.joined()
        promoted.ocrReviewedAt = corrected.ocrReviewedAt ?? now
        promoted.correctedFromCollectionID = nil
        promoted.hiddenPhraseWords = corrected.hiddenPhraseWords ?? original.hiddenPhraseWords
        promoted.lastViewedAt = now

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
            return copy
        }

        allCollections = replacementCollections
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
        if selectedBrowseCollectionID == originalID {
            selectedBrowseCollectionCharacters = Set(promoted.characters)
            activeSubject = .collection(promoted)
        }
        persistCollections()
        return promoted
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
            .filter { componentRepo.hasCharacter($0) }
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
            thumbnailJPEGData: original.thumbnailJPEGData,
            sourceImageJPEGData: original.sourceImageJPEGData,
            originalOCRText: original.originalOCRText ?? original.characters.joined(),
            reviewedOCRText: cleanText,
            ocrReviewedAt: Date(),
            correctedFromCollectionID: original.id
        )
        saveCollection(corrected)
        return corrected
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

        let characters = CaptureTextExtractor.allCharactersInOrder(in: sourceText).filter { componentRepo.hasCharacter($0) }
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
        allCollections = decoded.map { collection in
            var copy = collection
            copy.characters = collection.characters.filter { componentRepo.hasCharacter($0) }
            return copy
        }.filter { !$0.characters.isEmpty }
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
        SavedPageRules.displayName(name)
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
            sourceType: collection.sourceType,
            isFavorite: false,
            thumbnailJPEGData: collection.thumbnailJPEGData,
            sourceImageJPEGData: collection.sourceImageJPEGData,
            originalOCRText: collection.originalOCRText,
            reviewedOCRText: collection.reviewedOCRText,
            ocrReviewedAt: collection.ocrReviewedAt,
            correctedFromCollectionID: nil,
            translationReport: nil,
            translationReportUpdatedAt: nil,
            hiddenPhraseWords: collection.hiddenPhraseWords
        )
    }

    private func archivedOriginalName(for name: String) -> String {
        let existingNames = Set(allCollections.map(\.name))
        let stem = collectionDisplayName(name)
        for suffix in 1...99 {
            let prefix = "Old"
            let suffixText = String(suffix)
            let available = max(0, SavedPageRules.maximumNameLength - prefix.count - suffixText.count)
            let candidate = prefix + String(stem.prefix(available)) + suffixText
            if !existingNames.contains(candidate) {
                return candidate
            }
        }
        return String(UUID().uuidString.prefix(SavedPageRules.maximumNameLength))
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
