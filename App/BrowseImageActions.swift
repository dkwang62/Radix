import SwiftUI

extension FilterGridTab {
    func browsePageAITasks(for collection: CharacterCollection) -> [CollectionPageAITask] {
        var tasks: [CollectionPageAITask] = []

        if collection.sourceType == .ocr && collection.correctedFromCollectionID == nil {
            tasks.append(CollectionPageAITask(
                id: AIResultTaskID.checkOCR,
                title: "Check OCR",
                systemImage: "text.viewfinder",
                manualAction: { beginAILinkPageTask(collection, taskID: AIResultTaskID.checkOCR) },
                automaticAction: { runAutomaticBrowsePageAIAction { runAutomaticOCRReview(collection) } }
            ))
        }

        tasks.append(contentsOf: [
            CollectionPageAITask(
                id: AIResultTaskID.createAICleanedPage,
                title: "Extract Sentences",
                systemImage: "doc.text.magnifyingglass",
                manualAction: { beginAILinkPageTask(collection, taskID: AIResultTaskID.createAICleanedPage) },
                automaticAction: { runAutomaticBrowsePageAIAction { runBrowseGeminiAICleanedPage(collection) } }
            ),
            CollectionPageAITask(
                id: AIResultTaskID.extractPhrases,
                title: "Extract Phrases",
                systemImage: "text.badge.plus",
                manualAction: { beginAILinkPageTask(collection, taskID: AIResultTaskID.extractPhrases) },
                automaticAction: { runAutomaticBrowsePageAIAction { runBrowseGeminiPhraseExtraction(collection) } }
            ),
            CollectionPageAITask(
                id: AIResultTaskID.translatePage,
                title: "Translate Page",
                systemImage: RadixGlossaryIcon.systemImage(for: RadixTerm.translation),
                manualAction: { beginAILinkPageTask(collection, taskID: AIResultTaskID.translatePage) },
                automaticAction: { runAutomaticBrowsePageAIAction { runBrowseGeminiTranslationAndSave(collection) } }
            ),
            CollectionPageAITask(
                id: AIResultTaskID.createQuiz,
                title: "Create Quiz",
                systemImage: "questionmark.circle",
                manualAction: { beginAILinkPageTask(collection, taskID: AIResultTaskID.createQuiz) },
                automaticAction: { beginAILinkPageTask(collection, taskID: AIResultTaskID.createQuiz) }
            ),
            CollectionPageAITask(
                id: AIResultTaskID.extractSentences,
                title: "Sentence Practice",
                systemImage: "bubble.left.and.bubble.right",
                manualAction: { beginAILinkPageTask(collection, taskID: AIResultTaskID.extractSentences) },
                automaticAction: { runAutomaticBrowsePageAIAction { runBrowseGeminiSentenceExtraction(collection) } }
            ),
            CollectionPageAITask(
                id: AIResultTaskID.createPagePractice,
                title: "Create Conversation",
                systemImage: "sparkles",
                manualAction: { beginAILinkPageTask(collection, taskID: AIResultTaskID.createPagePractice) },
                automaticAction: { runAutomaticBrowsePageAIAction { runBrowseGeminiPagePracticeGeneration(collection) } }
            )
        ])

        return tasks
    }

    func runAutomaticBrowsePageAIAction(_ action: () -> Void) {
        guard !store.geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            store.goToSettingsForAPIKeySetup()
            return
        }
        action()
    }

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
            store.goToBrowseCollection(id: corrected.id, preservingOrigin: true)
            imageActionMessage = "Corrected text page created. The original captured page remains available from Actions."
        } catch {
            imageActionMessage = error.localizedDescription
        }
    }

    func beginTranslationReport(_ collection: CharacterCollection) {
        translationReportDraft = collection.translationReport ?? ""
        translationReportCollection = collection
    }

    func runBrowseGeminiSentenceExtraction(_ collection: CharacterCollection) {
        isRunningImageAction = true
        imageActionMessage = "Extracting sentences with Gemini..."
        Task {
            do {
                let pack = try await store.runGeminiPageSentenceExtraction(for: collection)
                await MainActor.run {
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
        isRunningImageAction = true
        imageActionMessage = "Creating page-inspired practice with Gemini..."
        Task {
            do {
                let pack = try await store.runGeminiPagePracticeGeneration(for: collection)
                await MainActor.run {
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
        isRunningImageAction = true
        imageActionMessage = "Extracting phrases with Gemini..."
        Task {
            do {
                let summary = try await store.runGeminiPhraseExtraction(for: collection)
                await MainActor.run {
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

    func runBrowseGeminiAICleanedPage(_ collection: CharacterCollection) {
        isRunningImageAction = true
        imageActionMessage = "Extracting sentences with Gemini..."
        Task {
            do {
                let record = try await store.runGeminiAICleanedPage(for: collection)
                await MainActor.run {
                    imageActionMessage = "AI page saved: \(record.cleanedTitle.isEmpty ? collection.name : record.cleanedTitle)."
                    isRunningImageAction = false
                }
            } catch {
                await MainActor.run {
                    offerManualAIFallback(.createAICleanedPage(collection), error: error)
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
