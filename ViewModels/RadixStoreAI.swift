import Foundation
import CoreGraphics

/*
 RADIX STORE - AI HELPERS
 ========================
 AI task selection for character launch, URL construction for AI presets,
 prompt settings persistence, and Mac clipboard paste automation.
 Extracted from RadixStore Private Utilities.
*/

private struct GeminiPageQuizQuestionDTO: Decodable {
    let kind: String?
    let display: String?
    let prompt: String
    let options: [String]
    let correctIndex: Int
    let explanation: String
}

enum AIResultTaskID {
    static let extractPhrases = "task4"
    static let translatePage = "task5"
    static let checkOCR = "task7"
    static let generatePracticePack = "task9"
    static let extractSentences = "task10"

    static let importableTasks: Set<String> = [
        extractPhrases,
        translatePage,
        checkOCR,
        generatePracticePack,
        extractSentences
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
        return importPhraseDiscoveryResponse(responseText)
    }

    func importPhraseDiscoveryResponse(_ responseText: String) -> PhraseDiscoveryImportSummary {
        let parsed = PhraseDiscoveryParser.parse(responseText)
        let candidates = PhraseDiscoveryCandidateTools.selectingAll(parsed.candidates, isSelected: true)
        let prepared = PhraseDiscoveryCandidateTools.preparingForImport(candidates)
        var added = 0
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
                } else {
                    skippedExisting += 1
                }
            } catch {
                errors.append("\(item.phrase): \(error.localizedDescription)")
            }
        }

        refreshPhraseOverlayViews()
        return PhraseDiscoveryImportSummary(
            selectedCount: candidates.count,
            addedCount: added,
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
        return corrected
    }

    @discardableResult
    func saveTranslationReport(fromAIResponse responseText: String, for collection: CharacterCollection) -> CharacterCollection {
        updateCollectionTranslationReport(id: collection.id, report: responseText)
        return self.collection(id: collection.id) ?? collection
    }

    @discardableResult
    func importConversationPracticePack(fromAIResponse responseText: String, sourceName: String) throws -> ConversationPracticePack {
        let pack = try ConversationPracticeService().loadPack(
            fromPastedText: responseText,
            sourceName: sourceName
        )
        saveImportedConversationPracticePack(pack)
        selectedConversationPracticeTopicID = pack.packID
        persistPromptSettings()
        return pack
    }

    func applyAIResult(taskID: String, responseText: String, collection: CharacterCollection?, sourceName: String) throws -> AIResultApplicationOutcome {
        switch taskID {
        case AIResultTaskID.extractPhrases:
            return .phraseExtraction(importPhraseDiscoveryResponse(responseText))
        case AIResultTaskID.translatePage:
            guard let collection else { throw AIResultApplicationError.missingCollection }
            return .translation(saveTranslationReport(fromAIResponse: responseText, for: collection))
        case AIResultTaskID.checkOCR:
            guard let collection else { throw AIResultApplicationError.missingCollection }
            return .correctedOCR(try createCorrectedOCRCollection(fromAIResponse: responseText, original: collection))
        case AIResultTaskID.generatePracticePack, AIResultTaskID.extractSentences:
            return .conversationPractice(try importConversationPracticePack(fromAIResponse: responseText, sourceName: sourceName))
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
        return try importConversationPracticePack(fromAIResponse: response, sourceName: collection.name)
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

    func pageQuizQuestions(for collection: CharacterCollection, limit: Int = 10) -> [PageQuizQuestion] {
        let pageItems = items(for: collection.characters).filter {
            !$0.definition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !$0.pinyinText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard !pageItems.isEmpty else { return [] }

        let dictionaryItems = componentRepo.allCharacters
            .compactMap { componentRepo.byCharacter[$0] }
            .filter {
                !$0.definition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && !$0.pinyinText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }

        var questions: [PageQuizQuestion] = []
        for item in pageItems {
            if questions.count >= limit { break }
            if let pinyinQuestion = pagePinyinQuizQuestion(for: item, pageItems: pageItems, dictionaryItems: dictionaryItems) {
                questions.append(pinyinQuestion)
            }
            if questions.count >= limit { break }
            if let characterQuestion = pageCharacterQuizQuestion(for: item, pageItems: pageItems, dictionaryItems: dictionaryItems) {
                questions.append(characterQuestion)
            }
        }

        return Array(questions.prefix(limit))
    }

    func runGeminiPageQuizQuestions(for collection: CharacterCollection, limit: Int = 10) async throws -> [PageQuizQuestion] {
        let characters = collection.characters.joined()
        let pageText = browseQuizSourceText(for: collection)
        let prompt = """
        Create an in-app Chinese learning quiz from this Radix saved page.

        Return JSON only. Do not wrap it in Markdown. Return an array of \(limit) objects.

        Each object must have exactly these keys:
        - "kind": one of "meaning", "pinyin", or "character"
        - "display": short Chinese text, pinyin, or phrase shown above the question
        - "prompt": the question shown to the learner
        - "options": exactly 4 answer strings
        - "correctIndex": zero-based index of the correct option
        - "explanation": brief English explanation shown after the learner answers

        Rules:
        1. Use the page text as the source. Do not invent facts beyond it.
        2. Prefer useful phrases, context, pinyin, translation, and meaning-in-context.
        3. Avoid ambiguous one-character English meaning questions unless the page context makes one answer clearly correct.
        4. Exactly one option must be correct.
        5. Explanations must be in English.
        6. Difficulty is 5/10: practical learner questions, not trivia.

        Page name: \(collection.name)
        Referenced Chinese characters:
        \(characters)

        Page text:
        \(pageText)
        """

        let response = try await GeminiTextGenerationService().generateText(
            apiKey: geminiAPIKey,
            modelID: geminiModelID,
            prompt: prompt,
            systemInstruction: """
            You are a careful Chinese teacher creating structured quiz data for an app. Return valid JSON only.
            """
        )
        return try parseGeminiPageQuizQuestions(response)
    }

    private func browseQuizSourceText(for collection: CharacterCollection) -> String {
        let reviewed = collection.reviewedOCRText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let original = collection.originalOCRText?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let reviewed, !reviewed.isEmpty { return reviewed }
        if let original, !original.isEmpty { return original }
        return collection.characters.joined()
    }

    private func parseGeminiPageQuizQuestions(_ response: String) throws -> [PageQuizQuestion] {
        guard let start = response.firstIndex(of: "["),
              let end = response.lastIndex(of: "]"),
              start <= end else {
            throw NSError(domain: "Radix", code: 41, userInfo: [NSLocalizedDescriptionKey: "Gemini did not return quiz JSON."])
        }

        let json = String(response[start...end])
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode([GeminiPageQuizQuestionDTO].self, from: data)
        let questions = decoded.compactMap { dto -> PageQuizQuestion? in
            let options = dto.options
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            guard options.count == 4, options.indices.contains(dto.correctIndex) else { return nil }
            let prompt = dto.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            let explanation = dto.explanation.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !prompt.isEmpty, !explanation.isEmpty else { return nil }

            let rawKind = dto.kind?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            let kind = PageQuizQuestion.Kind(rawValue: rawKind) ?? .meaning
            let display = dto.display?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            return PageQuizQuestion(
                id: UUID(),
                kind: kind,
                character: display.isEmpty ? "Quiz" : display,
                prompt: prompt,
                options: options,
                correctOption: options[dto.correctIndex],
                explanation: explanation
            )
        }

        guard !questions.isEmpty else {
            throw NSError(domain: "Radix", code: 42, userInfo: [NSLocalizedDescriptionKey: "Gemini returned quiz data Radix could not use."])
        }
        return questions
    }

    private func pagePinyinQuizQuestion(
        for item: ComponentItem,
        pageItems: [ComponentItem],
        dictionaryItems: [ComponentItem]
    ) -> PageQuizQuestion? {
        let answer = item.pinyinText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !answer.isEmpty else { return nil }

        let distractors = quizDistractors(
            correct: answer,
            preferred: pageItems.map { $0.pinyinText.trimmingCharacters(in: .whitespacesAndNewlines) },
            fallback: dictionaryItems.map { $0.pinyinText.trimmingCharacters(in: .whitespacesAndNewlines) }
        )
        guard distractors.count >= 3 else { return nil }

        let options = quizStableShuffle([answer] + distractors, seed: item.character + "pinyin")
        return PageQuizQuestion(
            id: UUID(),
            kind: .pinyin,
            character: item.character,
            prompt: "Which pinyin belongs to \(item.character)?",
            options: options,
            correctOption: answer,
            explanation: "\(item.character) is read \(answer). \(quizDefinitionSnippet(item.definition))"
        )
    }

    private func pageCharacterQuizQuestion(
        for item: ComponentItem,
        pageItems: [ComponentItem],
        dictionaryItems: [ComponentItem]
    ) -> PageQuizQuestion? {
        let pinyin = item.pinyinText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pinyin.isEmpty else { return nil }

        let distractors = quizDistractors(
            correct: item.character,
            preferred: pageItems.map(\.character),
            fallback: dictionaryItems.map(\.character)
        )
        guard distractors.count >= 3 else { return nil }

        let options = quizStableShuffle([item.character] + distractors, seed: item.character + "character")
        return PageQuizQuestion(
            id: UUID(),
            kind: .character,
            character: pinyin,
            prompt: "Which character is read \(pinyin)?",
            options: options,
            correctOption: item.character,
            explanation: "\(item.character) is read \(pinyin). \(quizDefinitionSnippet(item.definition))"
        )
    }

    private func quizDefinitionSnippet(_ definition: String) -> String {
        let trimmed = definition
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let separators = CharacterSet(charactersIn: ";,(")
        let prefix = trimmed.components(separatedBy: separators).first ?? trimmed
        return prefix.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func quizDistractors(correct: String, preferred: [String], fallback: [String]) -> [String] {
        var seen = Set([correct.lowercased()])
        var result: [String] = []

        for candidate in preferred + fallback {
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard seen.insert(trimmed.lowercased()).inserted else { continue }
            result.append(trimmed)
            if result.count == 3 { break }
        }

        return result
    }

    private func quizStableShuffle(_ values: [String], seed: String) -> [String] {
        guard !values.isEmpty else { return [] }
        let offset = abs(seed.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) }) % values.count
        return Array(values[offset...]) + Array(values[..<offset])
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
