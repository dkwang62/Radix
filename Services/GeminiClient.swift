import Foundation

struct GeminiClient {
    let apiKey: String
    let modelID: String

    func generateContent(requestBody: [String: Any]) async throws -> Data {
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanModel = modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty else {
            throw NSError(domain: "Radix", code: 4001, userInfo: [NSLocalizedDescriptionKey: "Missing Gemini API key."])
        }
        guard cleanKey.count >= 30 else {
            throw NSError(
                domain: "Radix",
                code: 4004,
                userInfo: [NSLocalizedDescriptionKey: "The Gemini API key looks incomplete. Paste the full key from Google AI Studio."]
            )
        }
        guard !cleanModel.isEmpty else {
            throw NSError(domain: "Radix", code: 4002, userInfo: [NSLocalizedDescriptionKey: "Missing Gemini model ID."])
        }
        guard let encodedModel = cleanModel.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(encodedModel):generateContent") else {
            throw NSError(domain: "Radix", code: 4003, userInfo: [NSLocalizedDescriptionKey: "Invalid Gemini model ID."])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(cleanKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw NSError(
                domain: "Radix",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: Self.userFacingErrorMessage(statusCode: http.statusCode, data: data)]
            )
        }
        return data
    }

    static func userFacingErrorMessage(statusCode: Int, data: Data) -> String {
        let fallback = "Gemini API request failed (\(statusCode)). Check your Gemini API key and model in Settings."
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let error = object["error"] as? [String: Any]
        else {
            return fallback
        }

        let message = error["message"] as? String ?? ""
        let status = error["status"] as? String ?? ""
        let reason = (error["details"] as? [[String: Any]])?
            .compactMap { detail -> String? in
                if let reason = detail["reason"] as? String { return reason }
                if let metadata = detail["metadata"] as? [String: Any],
                   let reason = metadata["reason"] as? String {
                    return reason
                }
                return nil
            }
            .first

        if status == "INVALID_ARGUMENT" && (reason == "API_KEY_INVALID" || message.localizedCaseInsensitiveContains("API key not valid")) {
            return "Gemini API key is not valid. Paste the full key from Google AI Studio, then try again."
        }
        if status == "PERMISSION_DENIED" || statusCode == 403 {
            return "Gemini API access was denied. Check that the key is enabled for the Gemini API and not blocked by project restrictions."
        }
        if status == "RESOURCE_EXHAUSTED" || statusCode == 429 {
            return "Gemini API quota was reached. Wait a bit or check billing/quota in Google AI Studio."
        }
        if statusCode == 404 {
            return "Gemini model was not found. Check the Gemini model name in Settings."
        }
        if !message.isEmpty {
            return "Gemini API request failed (\(statusCode)): \(message)"
        }
        return fallback
    }
}

struct GeminiPhraseExtractionService {
    func extractPhrases(
        apiKey: String,
        modelID: String,
        collectionName: String,
        characters: String,
        knownPhrases: [String]
    ) async throws -> String {
        let prompt = makePrompt(
            collectionName: collectionName,
            characters: characters,
            knownPhrases: knownPhrases
        )
        let data = try await GeminiClient(apiKey: apiKey, modelID: modelID)
            .generateContent(requestBody: requestBody(prompt: prompt))
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

struct GeminiTextGenerationService {
    func generateText(
        apiKey: String,
        modelID: String,
        prompt: String,
        systemInstruction: String,
        imageJPEGData: Data? = nil
    ) async throws -> String {
        let data = try await GeminiClient(apiKey: apiKey, modelID: modelID)
            .generateContent(
                requestBody: requestBody(
                    prompt: prompt,
                    systemInstruction: systemInstruction,
                    imageJPEGData: imageJPEGData
                )
            )
        let text = Self.responseText(from: data).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw NSError(domain: "Radix", code: 4005, userInfo: [NSLocalizedDescriptionKey: "Gemini returned an empty translation."])
        }
        return text
    }

    private func requestBody(
        prompt: String,
        systemInstruction: String,
        imageJPEGData: Data?
    ) -> [String: Any] {
        var parts: [[String: Any]] = [["text": prompt]]
        if let imageJPEGData {
            parts.append([
                "inlineData": [
                    "mimeType": "image/jpeg",
                    "data": imageJPEGData.base64EncodedString()
                ]
            ])
        }
        return [
            "systemInstruction": [
                "parts": [
                    ["text": systemInstruction]
                ]
            ],
            "contents": [
                [
                    "role": "user",
                    "parts": parts
                ]
            ],
            "generationConfig": [
                "temperature": 0.35
            ]
        ]
    }

    private static func responseText(from data: Data) -> String {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = object["candidates"] as? [[String: Any]]
        else {
            return String(data: data, encoding: .utf8) ?? ""
        }

        return candidates
            .compactMap { candidate -> String? in
                guard let content = candidate["content"] as? [String: Any],
                      let parts = content["parts"] as? [[String: Any]] else {
                    return nil
                }
                return parts
                    .compactMap { $0["text"] as? String }
                    .joined(separator: "\n")
            }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n\n")
    }
}
