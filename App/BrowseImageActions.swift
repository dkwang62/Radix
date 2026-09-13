import SwiftUI

extension FilterGridTab {
    func browsePageAITasks(for collection: CharacterCollection) -> [CollectionPageAITask] {
        CollectionPageAITaskKind.pageTasks(
            for: collection,
            manualAction: { taskID in beginAILinkPageTask(collection, taskID: taskID) },
            automaticAction: { kind in runBrowsePageAIAction(kind, for: collection) }
        )
    }

    func runAutomaticBrowsePageAIAction(_ action: () -> Void) {
        guard !!store.hasAutomaticAIConfiguration else {
            store.goToSettingsForAPIKeySetup()
            return
        }
        action()
    }

    func beginAILinkPageTask(_ collection: CharacterCollection, taskID: String) {
        imageActionMessage = nil
        store.goToAILinkCollectionTask(collection: collection, taskID: taskID)
    }

    func runBrowsePageAIAction(_ kind: CollectionPageAITaskKind, for collection: CharacterCollection) {
        if kind == .createQuiz {
            beginAILinkPageTask(collection, taskID: kind.id)
            return
        }
        runAutomaticBrowsePageAIAction {
            switch kind {
            case .checkOCR:
                runAutomaticOCRReview(collection)
            case .createAICleanedPage:
                runBrowseGeminiAICleanedPage(collection)
            case .extractPhrases:
                runBrowseGeminiPhraseExtraction(collection)
            case .translate:
                runBrowseGeminiTranslationAndSave(collection)
            case .extractSentences:
                runBrowseGeminiSentenceExtraction(collection)
            case .createPagePractice:
                runBrowseGeminiPagePracticeGeneration(collection)
            case .createQuiz:
                break
            }
        }
    }

    func runAutomaticOCRReview(_ collection: CharacterCollection) {
        isRunningImageAction = true
        imageActionMessage = "Checking captured text with \(store.automaticAIName)..."
        Task {
            do {
                let response = try await store.runAutomaticOCRReview(for: collection)
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
        imageActionMessage = "Extracting sentences with \(store.automaticAIName)..."
        Task {
            do {
                let pack = try await store.runAutomaticPageSentenceExtraction(for: collection)
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
        imageActionMessage = "Creating page-inspired practice with \(store.automaticAIName)..."
        Task {
            do {
                let pack = try await store.runAutomaticPagePracticeGeneration(for: collection)
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
        imageActionMessage = "Explaining page with \(store.automaticAIName)..."
        Task {
            do {
                _ = try await store.runAutomaticTranslationReport(for: collection)
                await MainActor.run {
                    imageActionMessage = "Page explanation saved."
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

    func clearTranslationReport() {
        translationReportDraft = ""
    }

    func runBrowseGeminiPhraseExtraction(_ collection: CharacterCollection) {
        isRunningImageAction = true
        imageActionMessage = "Extracting phrases with \(store.automaticAIName)..."
        Task {
            do {
                let summary = try await store.runAutomaticPhraseExtraction(for: collection)
                await MainActor.run {
                    imageActionMessage = summary.message(defaultAIName: store.automaticAIName)
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
        imageActionMessage = "Extracting sentences with \(store.automaticAIName)..."
        Task {
            do {
                let record = try await store.runAutomaticAICleanedPage(for: collection)
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
        imageActionMessage = "Automatic AI is unavailable. You can still copy the prompt to an AI chat."
        presentedBrowseAlert = .automaticAIFailure(task)
    }

    func useManualFallback(_ task: BrowseAIFallbackTask) {
        beginAILinkPageTask(task.collection, taskID: task.taskID)
    }

}
