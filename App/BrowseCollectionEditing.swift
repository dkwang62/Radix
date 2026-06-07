import SwiftUI

extension FilterGridTab {
    func beginEditing(_ collection: CharacterCollection) {
        editingCollectionName = collection.name
        editingCollectionText = collection.characters.joined(separator: " ")
        collectionEditorError = nil
        editingCollection = collection
    }

    func saveEditedCollection(_ collection: CharacterCollection) {
        guard let updated = store.updateCollection(
            id: collection.id,
            newName: editingCollectionName,
            sourceText: editingCollectionText
        ) else {
            collectionEditorError = "Enter a name and at least one Chinese character that exists in Radix."
            return
        }

        editingCollectionName = updated.name
        editingCollectionText = updated.characters.joined(separator: " ")
        collectionEditorError = nil
        editingCollection = nil
    }

    func beginManualCollection() {
        guard hasUnlimitedFreePages || freePagesRemaining > 0 else {
            store.showPaywall(for: .datedCopies)
            return
        }
        manualCollectionName = ""
        manualCollectionText = clipboardText()
        showBrowseSource = false
        showManualCollectionSheet = true
    }

    func saveManualCollection() {
        guard let collection = store.createCollection(
            name: manualCollectionName,
            sourceText: manualCollectionText,
            sourceType: .manual
        ) else { return }
        if !hasUnlimitedFreePages {
            freePageUseCount = RadixCaptureUsage.incrementFreeScanCount(limit: freePageLimit)
        }
        store.selectBrowseCollection(id: collection.id)
        manualCollectionName = ""
        manualCollectionText = ""
        showManualCollectionSheet = false
    }

    func clipboardText() -> String {
        RadixPlatform.pasteboardString
    }
}
