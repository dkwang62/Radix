import SwiftUI

extension FilterGridTab {
    func beginOCRReview(_ collection: CharacterCollection) {
        imageActionMessage = nil
        ocrReviewCollection = collection
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

    func openOCRReviewInDefaultAI(_ collection: CharacterCollection) {
        let prompt = store.ocrReviewPrompt(for: collection)
        RadixPlatform.copyToPasteboard(prompt)
        let preset = store.defaultAIPreset
        if let url = store.aiURL(for: preset, prompt: prompt) {
            openURL(url)
        }
        if preset == .chatGPT {
            imageActionMessage = "Opening ChatGPT. The AI prompt is copied; paste it into the message box manually so Chinese text is preserved."
        } else {
            imageActionMessage = "Opening \(store.aiName(for: preset)). The AI prompt is also copied."
        }
    }

    func pasteAndCreateCorrectedOCRPage(from collection: CharacterCollection) {
        createCorrectedOCRPage(from: clipboardText(), original: collection)
    }

    private func createCorrectedOCRPage(from response: String, original collection: CharacterCollection) {
        guard let proposal = OCRReviewParser.parse(response) else {
            imageActionMessage = "Radix could not read the AI answer. Ask it to keep the required [[CORRECTED TEXT]], [[CHANGES]], and [[UNCERTAIN]] headings."
            return
        }
        guard let corrected = store.createCorrectedOCRCollection(
            from: collection.id,
            correctedText: proposal.correctedText
        ) else {
            imageActionMessage = "The proposed text does not contain a Chinese character recognized by Radix."
            return
        }
        ocrReviewCollection = nil
        store.selectBrowseCollection(id: corrected.id)
        imageActionMessage = "Corrected page created and opened. The original OCR page remains available in Browse."
    }

    func beginTranslationReport(_ collection: CharacterCollection) {
        translationReportDraft = collection.translationReport ?? ""
        translationReportCollection = collection
    }

    func beginBrowseTranslation(_ collection: CharacterCollection) {
        copyImageActionPrompt(collection: collection, taskID: "task5")
        openImageActionPrompt(collection: collection, taskID: "task5")
        beginTranslationReport(collection)
        imageActionMessage = "Translation AI prompt copied. Paste the AI result into the report sheet and save it."
    }

    func beginManualPageQuiz(_ collection: CharacterCollection) {
        openImageActionPrompt(collection: collection, taskID: "task8")
        imageActionMessage = "Quiz AI prompt copied. Use it in ChatGPT, Gemini, or another AI app to quiz yourself without an API key."
    }

    func beginPageSentenceExtraction(_ collection: CharacterCollection) {
        openImageActionPrompt(collection: collection, taskID: "task10")
        imageActionMessage = "Sentence extraction prompt copied. Paste the AI JSON in Study > Conversation Practices > Paste Practice JSON."
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
                    offerManualAIFallback(.extractPhrases(collection), error: error)
                    isRunningImageAction = false
                }
            }
        }
    }

    func copyImageActionPrompt(collection: CharacterCollection, taskID: String) {
        let prompt = store.promptText(for: .collection(collection), selectedTaskIDs: [taskID])
        RadixPlatform.copyToPasteboard(prompt)
        imageActionMessage = "AI prompt copied."
    }

    func offerManualAIFallback(_ task: BrowseAIFallbackTask, error: Error) {
        automaticAIError = error.localizedDescription
        imageActionMessage = "Automatic AI is unavailable. You can still use another AI app."
        aiFallbackTask = task
    }

    func useManualFallback(_ task: BrowseAIFallbackTask) {
        switch task {
        case .checkOCR(let collection):
            beginOCRReview(collection)
        case .extractPhrases(let collection):
            beginManualPhraseExtraction(collection)
        case .translate(let collection):
            beginBrowseTranslation(collection)
        }
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
