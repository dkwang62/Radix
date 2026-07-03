import SwiftUI

extension FilterGridTab {
    func beginAILinkPageTask(_ collection: CharacterCollection, taskID: String) {
        imageActionMessage = nil
        store.goToAILinkCollectionTask(collection: collection, taskID: taskID)
    }

    func runAutomaticOCRReview(_ collection: CharacterCollection) {
        isRunningImageAction = true
        imageActionMessage = "Checking OCR automatically with Gemini..."
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
            store.selectBrowseCollection(id: corrected.id)
            imageActionMessage = "Corrected page created and opened. The original OCR page remains available in Browse."
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
        imageActionMessage = "Extracting sentences automatically..."
        Task {
            do {
                let pack = try await store.runGeminiPageSentenceExtraction(for: collection)
                await MainActor.run {
                    store.goToBrowse()
                    store.selectBrowseCollection(id: collection.id)
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
        imageActionMessage = "Creating page-inspired practice automatically..."
        Task {
            do {
                let pack = try await store.runGeminiPagePracticeGeneration(for: collection)
                await MainActor.run {
                    store.goToBrowse()
                    store.selectBrowseCollection(id: collection.id)
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
                    offerManualAIFallback(.translate(collection), error: error)
                    isRunningImageAction = false
                }
            }
        }
    }

    func beginPageQuiz(_ collection: CharacterCollection) {
        imageActionMessage = nil
        pageQuizQuestions = []
        pageQuizMessage = "Creating quiz with AI..."
        isGeneratingPageQuiz = true
        pageQuizCollection = collection

        let key = store.geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            isGeneratingPageQuiz = false
            pageQuizMessage = "Add a Gemini API key in Settings to generate an AI quiz. You can still use a local Radix quiz."
            return
        }

        Task {
            do {
                let questions = try await store.runGeminiPageQuizQuestions(for: collection)
                await MainActor.run {
                    pageQuizQuestions = questions
                    pageQuizMessage = "AI generated this quiz from the saved page."
                    isGeneratingPageQuiz = false
                }
            } catch {
                await MainActor.run {
                    pageQuizQuestions = []
                    pageQuizMessage = "Gemini could not create the quiz: \(error.localizedDescription). You can use a local Radix quiz instead."
                    isGeneratingPageQuiz = false
                }
            }
        }
    }

    func useLocalPageQuizFallback(_ collection: CharacterCollection) {
        pageQuizQuestions = store.pageQuizQuestions(for: collection)
        pageQuizMessage = "Using a local Radix quiz because AI generation is unavailable."
        isGeneratingPageQuiz = false
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
                    offerManualAIFallback(.extractPhrases(collection), error: error)
                    isRunningImageAction = false
                }
            }
        }
    }

    func offerManualAIFallback(_ task: BrowseAIFallbackTask, error: Error) {
        automaticAIError = error.localizedDescription
        imageActionMessage = "Automatic AI is unavailable. You can still use another AI app."
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
        }
    }

}
