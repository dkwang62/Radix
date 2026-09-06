import SwiftUI

extension FilterGridTab {
    func browseAlert(_ presentedAlert: BrowsePresentedAlert) -> Alert {
        switch presentedAlert {
        case .automaticAIFailure(let task):
            Alert(
                title: Text(PageAIMethodCopy.unavailableTitle),
                message: Text("\(automaticAIError)\n\n\(PageAIMethodCopy.unavailableMessage)"),
                primaryButton: .default(Text(PageAIMethodCopy.fallbackTitle)) {
                    useManualFallback(task)
                },
                secondaryButton: .cancel(Text("Not Now"))
            )
        case .cloudOCR(let request):
            Alert(
                title: Text("Try Cloud OCR?"),
                message: Text("\(request.localResult.userMessage)\n\nTrying Gemini sends this image to Google's Gemini service. It requires a Gemini key in Settings."),
                primaryButton: .default(Text("Try Gemini")) {
                    Task { await recognizeBrowseImage(request.image, method: .gemini) }
                },
                secondaryButton: .cancel(Text("Not Now"))
            )
        }
    }

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
            collectionEditorError = "Enter a name and at least one Chinese character."
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

    func consumeBrowseSourceCloseRequests() {
        if store.shouldCloseBrowseSource {
            store.shouldCloseBrowseSource = false
            withAnimation(.easeInOut(duration: 0.16)) {
                showBrowseSource = false
            }
        }
    }

    @MainActor
    func recognizeBrowseImage(
        _ image: CapturedImage,
        method: CaptureImageRecognitionMethod = .appleVision
    ) async {
        guard !entitlement.requiresPro(.datedCopies) else {
            store.showPaywall(for: .datedCopies)
            return
        }

        isProcessingBrowseImageImport = true
        imageActionMessage = nil
        presentedBrowseAlert = nil
        defer { isProcessingBrowseImageImport = false }

        do {
            let result: CaptureImageRecognitionResult
            switch method {
            case .appleVision:
                let localResult = try await store.recognizeImageTextLocally(in: image)
                switch localResult {
                case .recognized(let text):
                    result = CaptureImageRecognitionResult(text: text, method: .appleVision)
                case .noText, .nonChineseText, .failed:
                    imageActionMessage = localResult.userMessage
                    presentedBrowseAlert = .cloudOCR(PendingBrowseCloudOCR(
                        image: image,
                        localResult: localResult
                    ))
                    return
                }
            case .gemini:
                result = try await store.recognizeImageTextWithGemini(in: image)
            }
            let foundCharacters = CaptureTextExtractor.allCharactersInOrder(in: result.text)
            guard !foundCharacters.isEmpty else {
                imageActionMessage = CaptureStatusText.noChineseCharactersFound
                return
            }

            guard let collection = store.createCollection(
                name: "",
                sourceText: foundCharacters.joined(separator: " "),
                sourceType: .ocr,
                sourceImageJPEGData: CaptureImageThumbnailer.makeJPEGData(from: image, maxDimension: 1600),
                originalOCRText: result.text
            ) else {
                imageActionMessage = CaptureStatusText.noChineseCharactersFound
                return
            }

            if !hasUnlimitedFreePages {
                freePageUseCount = RadixCaptureUsage.incrementFreeScanCount(limit: freePageLimit)
            }

            store.goToBrowseCollection(id: collection.id, preservingOrigin: true)
            store.clearBrowsePreview()
            showBrowseSource = false
            imageActionMessage = CaptureStatusText.savedCollection(
                name: collection.name.isEmpty ? "page" : collection.name,
                characterCount: collection.characters.count
            ) + (result.usedAIFallback ? " Gemini read the image after you requested cloud OCR." : "")
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
        store.goToBrowseCollection(id: collection.id, preservingOrigin: true)
        manualCollectionName = ""
        manualCollectionText = ""
        showManualCollectionSheet = false
    }

    func clipboardText() -> String {
        RadixPlatform.pasteboardString
    }
}
