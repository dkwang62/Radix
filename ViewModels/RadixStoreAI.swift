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

    func runGeminiPageQuiz(for collection: CharacterCollection) async throws -> String {
        let prompt = promptText(for: .collection(collection), selectedTaskIDs: ["task8"])
        return try await GeminiTextGenerationService().generateText(
            apiKey: geminiAPIKey,
            modelID: geminiModelID,
            prompt: prompt,
            systemInstruction: """
            You are a patient Chinese language teacher. Create a page-based practice quiz from the supplied Radix material. Keep explanations in English. Follow the requested difficulty and hidden-answer practice format.
            """
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
