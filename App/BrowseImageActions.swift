import SwiftUI

extension FilterGridTab {
    func beginOCRReview(_ collection: CharacterCollection) {
        ocrReviewResponse = ""
        imageActionMessage = nil
        ocrReviewCollection = collection
    }

    func copyOCRReviewInstruction(_ collection: CharacterCollection) {
        RadixPlatform.copyToPasteboard(store.ocrReviewPrompt(for: collection))
        imageActionMessage = "OCR-check instruction copied."
    }

    func copyOCRReviewImage(_ collection: CharacterCollection) {
        guard let imageData = collection.sourceImageJPEGData ?? collection.thumbnailJPEGData else {
            imageActionMessage = "No source image is available for this page."
            return
        }
        RadixPlatform.copyImageToPasteboard(imageData)
        imageActionMessage = "Image copied. Paste it into the ChatGPT conversation."
    }

    func openOCRReviewInChatGPT(_ collection: CharacterCollection) {
        let prompt = store.ocrReviewPrompt(for: collection)
        RadixPlatform.copyToPasteboard(prompt)
        let preset: DefaultAIPreset = .chatGPT
        if let url = store.aiURL(for: preset, prompt: prompt) {
            openURL(url)
        }
        imageActionMessage = "Opening ChatGPT. The instruction is also copied."
    }

    func applyOCRReview(_ correctedText: String, to collection: CharacterCollection) {
        guard let updated = store.applyOCRCorrection(id: collection.id, correctedText: correctedText) else {
            imageActionMessage = "The proposed text does not contain a Chinese character recognized by Radix."
            return
        }
        ocrReviewCollection = updated
        store.selectBrowseCollection(id: updated.id)
        imageActionMessage = "Corrected text applied. The original OCR remains preserved."
    }

    func beginTranslationReport(_ collection: CharacterCollection) {
        translationReportDraft = collection.translationReport ?? ""
        translationReportCollection = collection
    }

    func beginBrowseTranslation(_ collection: CharacterCollection) {
        copyImageActionPrompt(collection: collection, taskID: "task5")
        openImageActionPrompt(collection: collection, taskID: "task5")
        beginTranslationReport(collection)
        imageActionMessage = "Translation instruction copied. Paste the AI result into the report sheet and save it."
    }

    func runBrowseGeminiTranslationAndSave(_ collection: CharacterCollection) {
        let key = store.geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            imageActionMessage = "Add a Gemini API key in Settings first."
            return
        }
        isRunningImageAction = true
        imageActionMessage = "Translating and saving report..."
        Task {
            do {
                _ = try await store.runGeminiTranslationReport(for: collection)
                await MainActor.run {
                    imageActionMessage = "Translation report saved."
                    isRunningImageAction = false
                }
            } catch {
                await MainActor.run {
                    imageActionMessage = error.localizedDescription
                    isRunningImageAction = false
                }
            }
        }
    }

    func beginManualPhraseExtraction(_ collection: CharacterCollection) {
        phraseExtractionOutput = ""
        imageActionMessage = nil
        phraseExtractionCollection = collection
    }

    func pasteTranslationReport() {
        translationReportDraft = clipboardText()
    }

    func saveTranslationReport(_ collection: CharacterCollection) {
        store.updateCollectionTranslationReport(id: collection.id, report: translationReportDraft)
        if let updated = store.collection(id: collection.id) {
            translationReportCollection = updated
            translationReportDraft = updated.translationReport ?? ""
        }
    }

    func clearTranslationReport(_ collection: CharacterCollection) {
        translationReportDraft = ""
        store.updateCollectionTranslationReport(id: collection.id, report: nil)
        if let updated = store.collection(id: collection.id) {
            translationReportCollection = updated
        }
    }

    func runBrowseGeminiPhraseExtraction(_ collection: CharacterCollection) {
        let key = store.geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            imageActionMessage = "Add a Gemini API key in Settings first."
            return
        }
        isRunningImageAction = true
        imageActionMessage = "Extracting phrases automatically..."
        Task {
            do {
                let summary = try await store.runGeminiPhraseExtraction(for: collection)
                await MainActor.run {
                    store.goToBrowse()
                    store.selectBrowseCollection(id: collection.id)
                    imageActionMessage = summary.message(defaultAIName: "Gemini API")
                    isRunningImageAction = false
                }
            } catch {
                await MainActor.run {
                    imageActionMessage = error.localizedDescription
                    isRunningImageAction = false
                }
            }
        }
    }

    func copyImageActionPrompt(collection: CharacterCollection, taskID: String) {
        let prompt = store.promptText(for: .collection(collection), selectedTaskIDs: [taskID])
        RadixPlatform.copyToPasteboard(prompt)
        imageActionMessage = "Instruction copied."
    }

    func openImageActionPrompt(collection: CharacterCollection, taskID: String) {
        let prompt = store.promptText(for: .collection(collection), selectedTaskIDs: [taskID])
        copyImageActionPrompt(collection: collection, taskID: taskID)
        let preset = store.defaultAIPreset
        if let url = store.aiURL(for: preset, prompt: prompt) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                openURL(url)
            }
        }
    }

    func addManualExtractedPhrases(_ collection: CharacterCollection) {
        let parsed = PhraseDiscoveryParser.parse(phraseExtractionOutput)
        let candidates = PhraseDiscoveryCandidateTools.selectingAll(parsed.candidates, isSelected: true)
        let prepared = PhraseDiscoveryCandidateTools.preparingForImport(candidates)
        var added = 0
        var skippedExisting = 0
        var errors: [String] = []
        for item in prepared.candidates {
            do {
                let wasAdded = try store.addAIPastedPhraseIfNew(
                    word: item.phrase,
                    pinyin: item.candidate.pinyin,
                    meanings: item.candidate.meaning,
                    refreshViews: false
                )
                if wasAdded {
                    added += 1
                } else {
                    skippedExisting += 1
                }
            } catch {
                errors.append("\(item.phrase): \(error.localizedDescription)")
            }
        }
        if added > 0 {
            store.refreshAddedPhrases()
            store.refreshPhrases()
        }
        let summary = PhraseDiscoveryImportSummary(
            selectedCount: prepared.candidates.count,
            addedCount: added,
            skippedCount: prepared.skippedCount + skippedExisting,
            skippedExistingCount: skippedExisting,
            errors: errors
        )
        imageActionMessage = summary.message(defaultAIName: store.defaultAIName)
        if let updated = store.collection(id: collection.id) {
            phraseExtractionCollection = updated
        }
    }
}
