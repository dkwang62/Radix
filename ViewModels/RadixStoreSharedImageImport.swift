import Foundation

extension RadixStore {
    @MainActor
    func importPendingSharedImagesFromShareExtension() async {
        let pendingURLs = RadixSharedImageImport.pendingImageURLs()
        guard !pendingURLs.isEmpty else {
            goToBrowsePages(selectLatest: false)
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
                    thumbnailJPEGData: CaptureImageThumbnailer.makeJPEGData(from: image),
                    sourceImageJPEGData: CaptureImageThumbnailer.makeJPEGData(from: image, maxDimension: 1600),
                    originalOCRText: recognizedText
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
            goToBrowsePages(selectLatest: false)
        }
    }

    @MainActor
    func importPendingSharedTextFromShareExtension() {
        let pendingURLs = RadixSharedImageImport.pendingTextURLs()
        guard !pendingURLs.isEmpty else { return }

        var lastImportedCollectionID: UUID?
        for url in pendingURLs {
            defer { try? FileManager.default.removeItem(at: url) }
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let simplified = ScriptTextConverter.simplified(trimmed)
            let sourceCandidates = simplified == trimmed ? [trimmed] : [trimmed, simplified]
            for sourceText in sourceCandidates {
                if let collection = createCollection(
                    name: "",
                    sourceText: sourceText,
                    sourceType: .imported
                ) {
                    lastImportedCollectionID = collection.id
                    break
                }
            }
        }

        if let lastImportedCollectionID {
            goToBrowse()
            selectBrowseCollection(id: lastImportedCollectionID)
            if RadixPlatform.isPhone {
                clearBrowsePreview()
                showiPhoneDetail = false
            }
        }
    }
}
