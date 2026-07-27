import SwiftUI

extension FilterGridTab {
    func beginAILinkPageTask(_ collection: CharacterCollection, taskID: String) {
        imageActionMessage = nil
        store.goToAILinkCollectionTask(collection: collection, taskID: taskID)
    }

    func runAutomaticOCRReview(_ collection: CharacterCollection) {
        isRunningImageAction = true
        imageActionMessage = "Checking captured text with Gemini..."
        Task {
            do {
                let response = try await store.runGeminiOCRReview(for: collection)
                await MainActor.run {
                    createCorrectedOCRPage(from: response, original: collection)
                    isRunningImageAction = false
                }
            } catch {
                await MainActor.run {
                    offerManualAIFallback(.checkOCR(collection), error: error)
                    isRunningImageAction = false
                }
            }
        }
    }

    private func createCorrectedOCRPage(from response: String, original collection: CharacterCollection) {
        do {
            let corrected = try store.createCorrectedOCRCollection(fromAIResponse: response, original: collection)
            store.goToPagesWorkspace(id: corrected.id, preservingOrigin: true)
            imageActionMessage = "Corrected text page created in Pages. The original captured page remains available as Source."
        } catch {
            imageActionMessage = error.localizedDescription
        }
    }

    func beginTranslationReport(_ collection: CharacterCollection) {
        translationReportDraft = collection.translationReport ?? ""
        translationReportCollection = collection
    }

    func runBrowseGeminiSentenceExtraction(_ collection: CharacterCollection) {
        let key = store.geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            imageActionMessage = "Add a Gemini API key in Settings first."
            return
        }
        isRunningImageAction = true
        imageActionMessage = "Extracting sentences with Gemini..."
        Task {
            do {
                let pack = try await store.runGeminiPageSentenceExtraction(for: collection)
                await MainActor.run {
                    store.goToPagesWorkspace(id: collection.id, preservingOrigin: true)
                    imageActionMessage = "Loaded \(pack.title) · \(pack.entries.count) sentences"
                    isRunningImageAction = false
                }
            } catch {
                await MainActor.run {
                    offerManualAIFallback(.extractSentences(collection), error: error)
                    isRunningImageAction = false
                }
            }
        }
    }

    func runBrowseGeminiPagePracticeGeneration(_ collection: CharacterCollection) {
        let key = store.geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            imageActionMessage = "Add a Gemini API key in Settings first."
            return
        }
        isRunningImageAction = true
        imageActionMessage = "Creating page-inspired practice with Gemini..."
        Task {
            do {
                let pack = try await store.runGeminiPagePracticeGeneration(for: collection)
                await MainActor.run {
                    store.goToPagesWorkspace(id: collection.id, preservingOrigin: true)
                    imageActionMessage = "Loaded \(pack.title) · \(pack.entries.count) sentences"
                    isRunningImageAction = false
                }
            } catch {
                await MainActor.run {
                    offerManualAIFallback(.createPagePractice(collection), error: error)
                    isRunningImageAction = false
                }
            }
        }
    }

    func runBrowseGeminiTranslationAndSave(_ collection: CharacterCollection) {
        let key = store.geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            imageActionMessage = "Add a Gemini API key in Settings first."
            return
        }
        isRunningImageAction = true
        imageActionMessage = "Translating with Gemini..."
        Task {
            do {
                _ = try await store.runGeminiTranslationReport(for: collection)
                await MainActor.run {
                    imageActionMessage = "Translation report saved."
                    isRunningImageAction = false
                }
            } catch {
                await MainActor.run {
                    offerManualAIFallback(.translate(collection), error: error)
                    isRunningImageAction = false
                }
            }
        }
    }

    func pasteTranslationReport() {
        translationReportDraft = clipboardText()
    }

    func saveTranslationReport(_ collection: CharacterCollection) {
        let updated = store.saveTranslationReport(fromAIResponse: translationReportDraft, for: collection)
        translationReportCollection = updated
        translationReportDraft = updated.translationReport ?? ""
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
        imageActionMessage = "Extracting phrases with Gemini..."
        Task {
            do {
                let summary = try await store.runGeminiPhraseExtraction(for: collection)
                await MainActor.run {
                    store.goToPagesWorkspace(id: collection.id, preservingOrigin: true)
                    imageActionMessage = summary.message(defaultAIName: "Gemini")
                    isRunningImageAction = false
                }
            } catch {
                await MainActor.run {
                    offerManualAIFallback(.extractPhrases(collection), error: error)
                    isRunningImageAction = false
                }
            }
        }
    }

    func offerManualAIFallback(_ task: BrowseAIFallbackTask, error: Error) {
        automaticAIError = error.localizedDescription
        imageActionMessage = "Automatic Gemini is unavailable. You can still copy the prompt to an AI chat."
        aiFallbackTask = task
    }

    func useManualFallback(_ task: BrowseAIFallbackTask) {
        switch task {
        case .checkOCR(let collection):
            beginAILinkPageTask(collection, taskID: AIResultTaskID.checkOCR)
        case .extractPhrases(let collection):
            beginAILinkPageTask(collection, taskID: AIResultTaskID.extractPhrases)
        case .translate(let collection):
            beginAILinkPageTask(collection, taskID: AIResultTaskID.translatePage)
        case .extractSentences(let collection):
            beginAILinkPageTask(collection, taskID: AIResultTaskID.extractSentences)
        case .createPagePractice(let collection):
            beginAILinkPageTask(collection, taskID: AIResultTaskID.createPagePractice)
        case .createAICleanedPage(let collection):
            beginAILinkPageTask(collection, taskID: AIResultTaskID.createAICleanedPage)
        }
    }

}
