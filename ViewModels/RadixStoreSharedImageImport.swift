import Foundation

extension RadixStore {
    @MainActor
    func startPendingSharedImportsFromShareExtension() {
        guard !pageDeletionJournal.isPending, !restoreRollbackJournal.isPending,
              !isRestoreTransactionActive else { return }
        if sharedImportFailure == nil {
            sharedImportFailure = RadixSharedImageImport.firstFailure()
        }
        guard sharedImportTask == nil, RadixSharedImageImport.hasPendingItems() else { return }

        sharedImportTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.importPendingSharedItemsFromShareExtension()
            self.sharedImportTask = nil
            if RadixSharedImageImport.hasPendingItems() {
                self.startPendingSharedImportsFromShareExtension()
            }
        }
    }

    @MainActor
    private func importPendingSharedItemsFromShareExtension() async {
        var lastImportedCollectionID: UUID?
        for item in RadixSharedImageImport.claimPendingItems() {
            do {
                let collection = try await importSharedItem(item)
                lastImportedCollectionID = collection.id
                RadixSharedImageImport.complete(item)
            } catch {
                let failure = RadixSharedImageImport.fail(item, message: error.localizedDescription)
                if sharedImportFailure == nil {
                    sharedImportFailure = failure
                }
            }
        }

        if let lastImportedCollectionID {
            goToBrowseCollection(id: lastImportedCollectionID)
        } else if sharedImportFailure != nil {
            goToPagesWorkspace()
        }
    }

    @MainActor
    private func importSharedItem(_ item: RadixSharedImportQueueItem) async throws -> CharacterCollection {
        switch item.kind {
        case .image:
            try CaptureImageResourceValidator.validateFileSize(at: item.fileURL)
            let data = try Data(contentsOf: item.fileURL, options: .mappedIfSafe)
            try Task.checkCancellation()
            let image = try CapturedImage(data: data)
            let localResult = try await recognizeImageTextLocally(in: image)
            let recognizedText: String
            switch localResult {
            case .recognized(let text):
                recognizedText = text
            case .noText, .nonChineseText, .failed:
                throw sharedImportError(localResult.userMessage)
            }
            let characters = CaptureTextExtractor.allCharactersInOrder(in: recognizedText)
            guard let collection = createCollection(
                id: item.id,
                name: "",
                sourceText: characters.joined(separator: " "),
                sourceType: .ocr,
                sourceImageJPEGData: CaptureImageThumbnailer.makeJPEGData(from: image, maxDimension: 1600),
                originalOCRText: recognizedText
            ) else {
                throw sharedImportError("No Chinese characters were found in this shared image.")
            }
            return collection

        case .text:
            let text = try String(contentsOf: item.fileURL, encoding: .utf8)
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw sharedImportError("The shared text was empty.")
            }

            let simplified = ScriptTextConverter.simplified(trimmed)
            let sourceCandidates = simplified == trimmed ? [trimmed] : [trimmed, simplified]
            for sourceText in sourceCandidates {
                if let collection = createCollection(
                    id: item.id,
                    name: "",
                    sourceText: sourceText,
                    sourceType: .imported
                ) {
                    return collection
                }
            }
            throw sharedImportError("No Chinese characters were found in this shared text.")
        }
    }

    @MainActor
    func retryFailedSharedImport() {
        guard let failure = sharedImportFailure else { return }
        do {
            try RadixSharedImageImport.retry(failure)
            sharedImportFailure = RadixSharedImageImport.firstFailure()
            startPendingSharedImportsFromShareExtension()
        } catch {
            sharedImportFailure = RadixSharedImportFailure(
                item: failure.item,
                message: "Retry failed: \(error.localizedDescription)"
            )
        }
    }

    @MainActor
    func discardFailedSharedImport() {
        guard let failure = sharedImportFailure else { return }
        RadixSharedImageImport.discard(failure)
        sharedImportFailure = RadixSharedImageImport.firstFailure()
    }

    private func sharedImportError(_ message: String) -> NSError {
        NSError(domain: "Radix.SharedImport", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
