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

    func beginBrowseImageFileImport() {
        guard !entitlement.requiresPro(.datedCopies) else {
            store.showPaywall(for: .datedCopies)
            return
        }
        imageActionMessage = nil
        showBrowseImageFileImporter = true
    }

    func beginClipboardImageImport() {
        guard !entitlement.requiresPro(.datedCopies) else {
            store.showPaywall(for: .datedCopies)
            return
        }

        do {
            guard let image = try RadixPlatform.pasteboardImage() else {
                imageActionMessage = "Copy an image with Chinese text first, then choose Image from Clipboard."
                return
            }
            Task { await recognizeBrowseImage(image) }
        } catch {
            imageActionMessage = error.localizedDescription
        }
    }

    func beginBrowseCameraScan() {
        guard hasUnlimitedFreePages || freePagesRemaining > 0 else {
            store.showPaywall(for: .datedCopies)
            return
        }
        imageActionMessage = nil
        showBrowseCamera = true
    }

    func consumeBrowsePageRequests() {
        if store.shouldCloseBrowsePages {
            store.shouldCloseBrowsePages = false
            withAnimation(.easeInOut(duration: 0.16)) {
                showBrowseSource = false
            }
        }

        if store.shouldStartBrowseCamera {
            store.shouldStartBrowseCamera = false
            beginBrowseCameraScan()
        }
    }

    @MainActor
    func recognizeBrowseImage(_ image: CapturedImage) async {
        guard !entitlement.requiresPro(.datedCopies) else {
            store.showPaywall(for: .datedCopies)
            return
        }

        isProcessingBrowseImageImport = true
        imageActionMessage = nil
        defer { isProcessingBrowseImageImport = false }

        do {
            let text = try await CaptureOCRService().recognizeText(in: image)
            let foundCharacters = CaptureTextExtractor.allCharactersInOrder(in: text)
            guard !foundCharacters.isEmpty else {
                imageActionMessage = CaptureStatusText.noChineseCharactersFound
                return
            }

            guard let collection = store.createCollection(
                name: "",
                sourceText: foundCharacters.joined(separator: " "),
                sourceType: .ocr,
                thumbnailJPEGData: CaptureImageThumbnailer.makeJPEGData(from: image),
                sourceImageJPEGData: CaptureImageThumbnailer.makeJPEGData(from: image, maxDimension: 1600),
                originalOCRText: text
            ) else {
                imageActionMessage = CaptureStatusText.noChineseCharactersFound
                return
            }

            if !hasUnlimitedFreePages {
                freePageUseCount = RadixCaptureUsage.incrementFreeScanCount(limit: freePageLimit)
            }

            store.selectBrowseCollection(id: collection.id)
            store.clearBrowsePreview()
            showBrowseSource = false
            imageActionMessage = CaptureStatusText.savedCollection(
                name: collection.name.isEmpty ? "page" : collection.name,
                characterCount: collection.characters.count
            )
        } catch {
            imageActionMessage = error.localizedDescription
        }
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
