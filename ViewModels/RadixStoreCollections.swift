import Foundation
import SwiftUI

/*
 RADIX STORE — COLLECTIONS
 ==========================
 Manages CharacterCollection CRUD, persistence, and selection state.
 Extracted from RadixStore for maintainability; all @Published properties
 remain declared in RadixStore.swift so SwiftUI observation is unaffected.
*/

extension RadixStore {

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

    // MARK: - CRUD

    @discardableResult
    func createCollection(
        name: String,
        sourceText: String,
        sourceType: CollectionSourceType,
        thumbnailJPEGData: Data? = nil
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
        let collection = CharacterCollection(
            id: UUID(),
            name: cleanName.isEmpty ? fallbackName : cleanName,
            characters: characters,
            createdAt: Date(),
            sourceType: sourceType,
            isFavorite: false,
            thumbnailJPEGData: thumbnailJPEGData
        )
        saveCollection(collection)
        return collection
    }

    func saveCollection(_ collection: CharacterCollection) {
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

    func collection(id: UUID) -> CharacterCollection? {
        allCollections.first { $0.id == id }
    }

    // MARK: - Selection

    func selectBrowseCollection(id: UUID?) {
        selectedBrowseCollectionID = id
        if let id {
            selectedAICollectionID = id
            gridSortMode = .readingOrder
            restoreImagePhraseHighlight(for: id)
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
        guard let data = UserDefaults.standard.data(forKey: collectionsKey),
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
        if let saved = UserDefaults.standard.string(forKey: selectedAICollectionKey),
           let id = UUID(uuidString: saved),
           collection(id: id) != nil {
            selectedAICollectionID = id
        } else {
            selectedAICollectionID = nil
        }
    }

    func persistCollections() {
        if let data = try? JSONEncoder().encode(allCollections) {
            UserDefaults.standard.set(data, forKey: collectionsKey)
        }
    }

    func persistSelectedAICollection() {
        if let selectedAICollectionID {
            UserDefaults.standard.set(selectedAICollectionID.uuidString, forKey: selectedAICollectionKey)
        } else {
            UserDefaults.standard.removeObject(forKey: selectedAICollectionKey)
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

    func collectionDisplayName(_ name: String) -> String {
        String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(11))
    }
}
