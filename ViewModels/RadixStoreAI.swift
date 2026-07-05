import Foundation
import CoreGraphics

/*
 RADIX STORE - AI HELPERS
 ========================
 AI task selection for character launch, URL construction for AI presets,
 prompt settings persistence, and Mac clipboard paste automation.
 Extracted from RadixStore Private Utilities.
*/

enum AIResultTaskID {
    static let extractPhrases = "task4"
    static let translatePage = "task5"
    static let checkOCR = "task7"
    static let createQuiz = "task8"
    static let generatePracticePack = "task9"
    static let extractSentences = "task10"
    static let createPagePractice = "task11"

    static let importableTasks: Set<String> = [
        extractPhrases,
        translatePage,
        checkOCR,
        generatePracticePack,
        extractSentences,
        createPagePractice
    ]
}

enum AIResultApplicationError: LocalizedError {
    case missingCollection
    case invalidOCRReview
    case emptyCorrectedOCR
    case unsupportedTask

    var errorDescription: String? {
        switch self {
        case .missingCollection:
            return "Choose a saved page first."
        case .invalidOCRReview:
            return "Radix could not read the AI answer. Ask it to keep the required [[CORRECTED TEXT]], [[CHANGES]], and [[UNCERTAIN]] headings."
        case .emptyCorrectedOCR:
            return "The corrected text does not contain a Chinese character recognized by Radix."
        case .unsupportedTask:
            return "This AI task does not import data back into Radix."
        }
    }
}

enum AIResultApplicationOutcome {
    case phraseExtraction(PhraseDiscoveryImportSummary)
    case translation(CharacterCollection)
    case correctedOCR(CharacterCollection)
    case conversationPractice(ConversationPracticePack)

    func message(defaultAIName: String) -> String {
        switch self {
        case .phraseExtraction(let summary):
            return summary.message(defaultAIName: defaultAIName)
        case .translation(let collection):
            return "Translation saved to \(collection.name)."
        case .correctedOCR(let collection):
            return "Corrected page created: \(collection.name)."
        case .conversationPractice(let pack):
            return "Imported \(pack.title) - \(pack.entries.count) sentences."
        }
    }
}

extension RadixStore {

    // MARK: - Task selection

    func selectedPromptTaskIDsForCharacterLaunch() -> [String] {
        let availableTaskIDs = Set(promptConfig.normalized().tasks.map(\.id))
        let characterTaskIDs = promptSelectedTaskIDs.filter {
            !PromptConfig.collectionTaskIDs.contains($0) &&
                !PromptConfig.practiceTopicTaskIDs.contains($0) &&
                availableTaskIDs.contains($0)
        }
        if !characterTaskIDs.isEmpty { return characterTaskIDs }
        if availableTaskIDs.contains("task1") { return ["task1"] }
        return promptConfig.normalized().tasks
            .map(\.id)
            .filter { !PromptConfig.collectionTaskIDs.contains($0) && !PromptConfig.practiceTopicTaskIDs.contains($0) }
            .prefix(1)
            .map { $0 }
    }

    func runGeminiPhraseExtraction(for collection: CharacterCollection) async throws -> PhraseDiscoveryImportSummary {
        let text = collection.characters.joined()
        let responseText = try await GeminiPhraseExtractionService().extractPhrases(
            apiKey: geminiAPIKey,
            modelID: geminiModelID,
            collectionName: collection.name,
            characters: text,
            knownPhrases: phraseDiscoveryKnownPhrases(in: text)
        )
        return importPhraseDiscoveryResponse(responseText, sourceCollection: collection)
    }

    func importPhraseDiscoveryResponse(_ responseText: String, sourceCollection: CharacterCollection? = nil) -> PhraseDiscoveryImportSummary {
        let parsed = PhraseDiscoveryParser.parse(responseText)
        let candidates = PhraseDiscoveryCandidateTools.selectingAll(parsed.candidates, isSelected: true)
        let prepared = PhraseDiscoveryCandidateTools.preparingForImport(candidates)
        var added = 0
        var addedWords: [String] = []
        let preExistingNonBaseWords = prepared.candidates
            .map(\.phrase)
            .filter { !isPhraseInBase($0) && isPhraseInAdd($0) }
        var skippedExisting = 0
        var errors: [String] = []

        for item in prepared.candidates {
            do {
                let wasAdded = try addAIPastedPhraseIfNew(
                    word: item.phrase,
                    pinyin: item.candidate.pinyin,
                    meanings: item.candidate.meaning,
                    refreshViews: false
                )
                if wasAdded {
                    added += 1
                    addedWords.append(item.phrase)
                } else {
                    skippedExisting += 1
                }
            } catch {
                errors.append("\(item.phrase): \(error.localizedDescription)")
            }
        }

        refreshPhraseOverlayViews()
        let linkedPhraseWords = PagePhraseExtractionRecord.deduplicated(preExistingNonBaseWords + addedWords)
        if let sourceCollection, !linkedPhraseWords.isEmpty {
            RadixStudyPreferences.recordPagePhraseExtraction(
                pageID: sourceCollection.id,
                title: sourceCollection.name,
                words: linkedPhraseWords
            )
        }
        return PhraseDiscoveryImportSummary(
            selectedCount: candidates.count,
            addedCount: added,
            addedWords: addedWords,
            skippedCount: prepared.skippedCount + skippedExisting,
            skippedExistingCount: skippedExisting,
            errors: errors
        )
    }

    func supportsAIResultImport(taskID: String) -> Bool {
        AIResultTaskID.importableTasks.contains(taskID)
    }

    func createCorrectedOCRCollection(fromAIResponse responseText: String, original collection: CharacterCollection) throws -> CharacterCollection {
        guard let proposal = OCRReviewParser.parse(responseText) else {
            throw AIResultApplicationError.invalidOCRReview
        }
        guard let corrected = createCorrectedOCRCollection(
            from: collection.id,
            correctedText: proposal.correctedText
        ) else {
            throw AIResultApplicationError.emptyCorrectedOCR
        }
        RadixStudyPreferences.recordSentenceExamples(
            fromOCRText: proposal.correctedText,
            sourcePageID: collection.id,
            sourceTitle: collection.name
        )
        return corrected
    }

    @discardableResult
    func saveTranslationReport(fromAIResponse responseText: String, for collection: CharacterCollection) -> CharacterCollection {
        updateCollectionTranslationReport(id: collection.id, report: responseText)
        return self.collection(id: collection.id) ?? collection
    }

    @discardableResult
    func importConversationPracticePack(
        fromAIResponse responseText: String,
        sourceName: String,
        sourceCollection: CharacterCollection? = nil
    ) throws -> ConversationPracticePack {
        var pack = try ConversationPracticeService().loadPack(
            fromPastedText: responseText,
            sourceName: sourceName
        )
        if let sourceCollection {
            pack = pack.withSourceLink(conversationPracticeSourceLink(for: sourceCollection))
        }
        saveImportedConversationPracticePack(pack)
        selectedConversationPracticeTopicID = pack.packID
        persistPromptSettings()
        return pack
    }

    func applyAIResult(taskID: String, responseText: String, collection: CharacterCollection?, sourceName: String) throws -> AIResultApplicationOutcome {
        switch taskID {
        case AIResultTaskID.extractPhrases:
            return .phraseExtraction(importPhraseDiscoveryResponse(responseText, sourceCollection: collection))
        case AIResultTaskID.translatePage:
            guard let collection else { throw AIResultApplicationError.missingCollection }
            return .translation(saveTranslationReport(fromAIResponse: responseText, for: collection))
        case AIResultTaskID.checkOCR:
            guard let collection else { throw AIResultApplicationError.missingCollection }
            return .correctedOCR(try createCorrectedOCRCollection(fromAIResponse: responseText, original: collection))
        case AIResultTaskID.generatePracticePack:
            return .conversationPractice(try importConversationPracticePack(fromAIResponse: responseText, sourceName: sourceName))
        case AIResultTaskID.extractSentences, AIResultTaskID.createPagePractice:
            guard let collection else { throw AIResultApplicationError.missingCollection }
            return .conversationPractice(try importConversationPracticePack(
                fromAIResponse: responseText,
                sourceName: sourceName,
                sourceCollection: collection
            ))
        default:
            throw AIResultApplicationError.unsupportedTask
        }
    }

    func runGeminiTranslationReport(for collection: CharacterCollection) async throws -> String {
        let prompt = promptText(for: .collection(collection), selectedTaskIDs: ["task5"])
        let report = try await GeminiTextGenerationService().generateText(
            apiKey: geminiAPIKey,
            modelID: geminiModelID,
            prompt: prompt,
            systemInstruction: """
            You are an expert bilingual Chinese editor and translator. Return a polished translation only, with no preface about being an AI and no follow-up questions.
            """
        )
        saveTranslationReport(fromAIResponse: report, for: collection)
        return report
    }

    func runGeminiPageSentenceExtraction(for collection: CharacterCollection) async throws -> ConversationPracticePack {
        let prompt = promptText(for: .collection(collection), selectedTaskIDs: ["task10"])
        let response = try await GeminiTextGenerationService().generateText(
            apiKey: geminiAPIKey,
            modelID: geminiModelID,
            prompt: prompt,
            systemInstruction: """
            You create validated JSON import packs for a Chinese learning app. Return valid JSON only, with no Markdown and no explanatory text.
            """
        )
        return try importConversationPracticePack(
            fromAIResponse: response,
            sourceName: collection.name,
            sourceCollection: collection
        )
    }

    func runGeminiPagePracticeGeneration(for collection: CharacterCollection) async throws -> ConversationPracticePack {
        let prompt = promptText(for: .collection(collection), selectedTaskIDs: [AIResultTaskID.createPagePractice])
        let response = try await GeminiTextGenerationService().generateText(
            apiKey: geminiAPIKey,
            modelID: geminiModelID,
            prompt: prompt,
            systemInstruction: """
            You create validated JSON import packs for a Chinese learning app. Return valid JSON only, with no Markdown and no explanatory text.
            """
        )
        return try importConversationPracticePack(
            fromAIResponse: response,
            sourceName: collection.name,
            sourceCollection: collection
        )
    }

    func runGeminiOCRReview(for collection: CharacterCollection) async throws -> String {
        try await GeminiTextGenerationService().generateText(
            apiKey: geminiAPIKey,
            modelID: geminiModelID,
            prompt: ocrReviewPrompt(for: collection),
            systemInstruction: """
            You are a meticulous Chinese OCR editor. Follow the requested output headings exactly. Preserve Chinese source text, write all explanations in English, and clearly mark uncertainty.
            """,
            imageJPEGData: collection.sourceImageJPEGData ?? collection.thumbnailJPEGData
        )
    }

    // MARK: - Mac clipboard paste

    func scheduleMacClipboardPasteIfPossible() {
        #if targetEnvironment(macCatalyst)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.performMacPasteShortcut()
        }
        #endif
    }

    #if targetEnvironment(macCatalyst)
    func performMacPasteShortcut() {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let commandDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true),
              let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
              let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false),
              let commandUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false) else {
            return
        }
        vDown.flags = .maskCommand
        vUp.flags = .maskCommand
        commandDown.post(tap: .cghidEventTap)
        vDown.post(tap: .cghidEventTap)
        vUp.post(tap: .cghidEventTap)
        commandUp.post(tap: .cghidEventTap)
    }
    #endif

    // MARK: - AI preset name / URL helpers

    var defaultAIName: String { aiName(for: defaultAIPreset) }
    var defaultAIBaseURLString: String { aiBaseURLString(for: defaultAIPreset) }
    var defaultAIPrefillsPrompt: Bool { aiPrefillsPrompt(for: defaultAIPreset) }

    func aiName(for preset: DefaultAIPreset) -> String {
        switch preset {
        case .custom:
            if let host = normalizedCustomAIURL?.host, !host.isEmpty { return host }
            return preset.displayName
        default:
            return preset.displayName
        }
    }

    func aiBaseURLString(for preset: DefaultAIPreset) -> String {
        switch preset {
        case .custom: return normalizedCustomAIURL?.absoluteString ?? ""
        default:      return preset.baseURLString
        }
    }

    func aiPrefillsPrompt(for preset: DefaultAIPreset) -> Bool {
        switch preset {
        case .chatGPT: return false
        case .custom:  return normalizedCustomAIURL?.absoluteString.contains("{prompt}") == true
        default:       return false
        }
    }

    func defaultAIURL(prompt: String) -> URL? { aiURL(for: defaultAIPreset, prompt: prompt) }

    func aiURL(for preset: DefaultAIPreset, prompt: String) -> URL? {
        switch preset {
        case .chatGPT:
            return URL(string: preset.baseURLString)
        case .custom:
            guard let custom = normalizedCustomAIURL else { return nil }
            let urlString = custom.absoluteString
            if urlString.contains("{prompt}") {
                let encoded = prompt.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? prompt
                return URL(string: urlString.replacingOccurrences(of: "{prompt}", with: encoded))
            }
            return custom
        default:
            return URL(string: preset.baseURLString)
        }
    }

    var normalizedCustomAIURL: URL? {
        let trimmed = customAIURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let direct = URL(string: trimmed), direct.scheme != nil { return direct }
        return URL(string: "https://\(trimmed)")
    }
}
