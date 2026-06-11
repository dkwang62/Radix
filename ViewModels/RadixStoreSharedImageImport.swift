import Foundation

extension RadixStore {
    @MainActor
    func importPendingSharedImagesFromShareExtension() async {
        let pendingURLs = RadixSharedImageImport.pendingImageURLs()
        guard !pendingURLs.isEmpty else {
            route = .capture
            return
        }

        var lastImportedCollectionID: UUID?
        for url in pendingURLs {
            do {
                let data = try Data(contentsOf: url)
                let image = try CapturedImage(data: data)
                let recognizedText = try await CaptureOCRService().recognizeText(in: image)
                let characters = CaptureTextExtractor.allCharactersInOrder(in: recognizedText)
                let phrases = CaptureTextExtractor.uniquePhrases(in: recognizedText)
                activeCaptureDraft = CaptureDraft(
                    rawText: recognizedText,
                    charactersText: characters.joined(separator: " "),
                    phrasesText: phrases.joined(separator: "\n")
                )

                if let collection = createCollection(
                    name: "",
                    sourceText: activeCaptureDraft.charactersText,
                    sourceType: .ocr,
                    thumbnailJPEGData: CaptureImageThumbnailer.makeJPEGData(from: image)
                ) {
                    lastImportedCollectionID = collection.id
                }

                try? FileManager.default.removeItem(at: url)
            } catch {
                continue
            }
        }

        if let lastImportedCollectionID {
            activeCaptureDraft = CaptureDraft()
            goToBrowse()
            selectBrowseCollection(id: lastImportedCollectionID)
            if RadixPlatform.isPhone {
                clearBrowsePreview()
                showiPhoneDetail = false
            }
        } else {
            route = .capture
        }
    }
}
