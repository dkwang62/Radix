import Foundation
import CoreGraphics

/*
 RADIX STORE - AI HELPERS
 ========================
 AI task selection for character launch, URL construction for AI presets,
 prompt settings persistence, and Mac clipboard paste automation.
 Extracted from RadixStore Private Utilities.
*/

extension RadixStore {

    // MARK: - Task selection

    func selectedPromptTaskIDsForCharacterLaunch() -> [String] {
        let availableTaskIDs = Set(promptConfig.normalized().tasks.map(\.id))
        let characterTaskIDs = promptSelectedTaskIDs.filter {
            !PromptConfig.collectionTaskIDs.contains($0) && availableTaskIDs.contains($0)
        }
        if !characterTaskIDs.isEmpty { return characterTaskIDs }
        if availableTaskIDs.contains("task1") { return ["task1"] }
        return promptConfig.normalized().tasks
            .map(\.id)
            .filter { !PromptConfig.collectionTaskIDs.contains($0) }
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
        updateCollectionTranslationReport(id: collection.id, report: report)
        return report
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
            if let meaningQuestion = pageMeaningQuizQuestion(for: item, pageItems: pageItems, dictionaryItems: dictionaryItems) {
                questions.append(meaningQuestion)
            }
            if questions.count >= limit { break }
            if let pinyinQuestion = pagePinyinQuizQuestion(for: item, pageItems: pageItems, dictionaryItems: dictionaryItems) {
                questions.append(pinyinQuestion)
            }
        }

        return Array(questions.prefix(limit))
    }

    private func pageMeaningQuizQuestion(
        for item: ComponentItem,
        pageItems: [ComponentItem],
        dictionaryItems: [ComponentItem]
    ) -> PageQuizQuestion? {
        let answer = quizDefinitionSnippet(item.definition)
        guard !answer.isEmpty else { return nil }

        let distractors = quizDistractors(
            correct: answer,
            preferred: pageItems.map { quizDefinitionSnippet($0.definition) },
            fallback: dictionaryItems.map { quizDefinitionSnippet($0.definition) }
        )
        guard distractors.count >= 3 else { return nil }

        let options = quizStableShuffle([answer] + distractors, seed: item.character + "meaning")
        return PageQuizQuestion(
            id: UUID(),
            kind: .meaning,
            character: item.character,
            prompt: "What does \(item.character) usually mean?",
            options: options,
            correctOption: answer,
            explanation: "\(item.character) is read \(item.pinyinText.isEmpty ? "with no pinyin listed" : item.pinyinText) and means \(answer)."
        )
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
        case .chatGPT: return true
        case .custom:  return normalizedCustomAIURL?.absoluteString.contains("{prompt}") == true
        default:       return false
        }
    }

    func defaultAIURL(prompt: String) -> URL? { aiURL(for: defaultAIPreset, prompt: prompt) }

    func aiURL(for preset: DefaultAIPreset, prompt: String) -> URL? {
        switch preset {
        case .chatGPT:
            var components = URLComponents(string: preset.baseURLString)
            components?.queryItems = [URLQueryItem(name: "q", value: prompt)]
            return components?.url
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
