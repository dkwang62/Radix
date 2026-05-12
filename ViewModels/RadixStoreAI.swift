import Foundation
import CoreGraphics

struct GeminiPhraseExtractionService {
    func extractPhrases(
        apiKey: String,
        modelID: String,
        collectionName: String,
        characters: String,
        knownPhrases: [String]
    ) async throws -> String {
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanModel = modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty else {
            throw NSError(domain: "Radix", code: 4001, userInfo: [NSLocalizedDescriptionKey: "Missing Gemini API key."])
        }
        guard !cleanModel.isEmpty else {
            throw NSError(domain: "Radix", code: 4002, userInfo: [NSLocalizedDescriptionKey: "Missing Gemini model ID."])
        }
        guard let encodedModel = cleanModel.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(encodedModel):generateContent") else {
            throw NSError(domain: "Radix", code: 4003, userInfo: [NSLocalizedDescriptionKey: "Invalid Gemini model ID."])
        }

        let prompt = makePrompt(
            collectionName: collectionName,
            characters: characters,
            knownPhrases: knownPhrases
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(cleanKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody(prompt: prompt))

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "No response body."
            throw NSError(
                domain: "Radix",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Gemini API request failed (\(http.statusCode)): \(body)"]
            )
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func makePrompt(collectionName: String, characters: String, knownPhrases: [String]) -> String {
        let knownList = knownPhrases.isEmpty ? "(none)" : knownPhrases.joined(separator: "\n")
        return """
        Image: \(collectionName)
        Characters / OCR text in reading order:
        \(characters)

        Known phrases to ignore:
        \(knownList)

        Extract useful NEW 2-, 3-, and 4-character Chinese dictionary headwords from the text. Return only the JSON object required by the schema.
        """
    }

    private func requestBody(prompt: String) -> [String: Any] {
        [
            "systemInstruction": [
                "parts": [
                    [
                        "text": """
                        You are a bilingual Chinese dictionary editor producing structured data for Radix. Extract only useful, dictionary-attested phrase headwords. Return valid JSON only.
                        """
                    ]
                ]
            ],
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.2,
                "responseMimeType": "application/json",
                "responseJsonSchema": responseSchema()
            ]
        ]
    }

    private func responseSchema() -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "phrases": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "phrase": [
                                "type": "string",
                                "description": "A 2-, 3-, or 4-character Chinese dictionary headword found in or strongly supported by the text."
                            ],
                            "pinyin": [
                                "type": "string",
                                "description": "Pinyin with tone marks."
                            ],
                            "meaning": [
                                "type": "string",
                                "description": "A concise English meaning with no pipe characters."
                            ]
                        ],
                        "required": ["phrase", "pinyin", "meaning"],
                        "additionalProperties": false
                    ]
                ]
            ],
            "required": ["phrases"],
            "additionalProperties": false
        ]
    }
}

/*
 RADIX STORE — AI HELPERS
 =========================
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
