import Foundation
import SwiftUI

/*
 RADIX STORE — COLLECTIONS
 ==========================
 Manages CharacterCollection CRUD, persistence, and selection state.
 Saved pages and their selection IDs are owned by RadixCollectionState and
 exposed through compatibility properties on RadixStore.
*/

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

    func deleteCollection(id: UUID) {
        allCollections.removeAll { $0.id == id }
        browsePagePhraseTileCache.removeValue(forKey: id)
        browsePagePhraseCandidateCache.removeValue(forKey: id)
        if selectedBrowseCollectionID == id {
            selectedBrowseCollectionID = nil
            selectedBrowseCollectionCharacters = nil
        }
        if selectedAICollectionID == id {
            selectedAICollectionID = nil
        }
        persistCollections()
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

}
