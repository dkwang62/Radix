import Foundation

struct OpenAICompatibleClient {
    let baseURLString: String
    let apiKey: String
    let modelID: String
    var session: URLSession = .shared

    func generateText(
        prompt: String,
        systemInstruction: String,
        imageJPEGData: Data? = nil
    ) async throws -> String {
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty else {
            throw NSError(domain: "Radix", code: 4101, userInfo: [NSLocalizedDescriptionKey: "Missing Custom AI API key."])
        }
        guard let url = OpenAICompatibleEndpoint(baseURLString: baseURLString).chatCompletionsURL else {
            throw NSError(domain: "Radix", code: 4102, userInfo: [NSLocalizedDescriptionKey: "Invalid Custom AI URL."])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(cleanKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody(
            prompt: prompt,
            systemInstruction: systemInstruction,
            imageJPEGData: imageJPEGData
        ))

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw NSError(
                domain: "Radix",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: Self.userFacingErrorMessage(statusCode: http.statusCode, data: data)]
            )
        }

        let text = Self.responseText(from: data).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw NSError(domain: "Radix", code: 4103, userInfo: [NSLocalizedDescriptionKey: "Custom AI returned an empty response."])
        }
        return text
    }

    private func requestBody(
        prompt: String,
        systemInstruction: String,
        imageJPEGData: Data?
    ) -> [String: Any] {
        var userContent: Any = prompt
        if let imageJPEGData {
            userContent = [
                ["type": "text", "text": prompt],
                [
                    "type": "image_url",
                    "image_url": [
                        "url": "data:image/jpeg;base64,\(imageJPEGData.base64EncodedString())"
                    ]
                ]
            ]
        }

        return [
            "model": modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "auto" : modelID,
            "messages": [
                ["role": "system", "content": systemInstruction],
                ["role": "user", "content": userContent]
            ],
            "temperature": 0.35
        ]
    }

    static func responseText(from data: Data) -> String {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = object["choices"] as? [[String: Any]],
            let first = choices.first
        else {
            return String(data: data, encoding: .utf8) ?? ""
        }

        if let message = first["message"] as? [String: Any] {
            if let text = message["content"] as? String { return text }
            if let content = message["content"] as? [[String: Any]] {
                return content.compactMap { part in
                    if let text = part["text"] as? String { return text }
                    if let text = part["content"] as? String { return text }
                    return nil
                }.joined(separator: "\n")
            }
        }
        if let text = first["text"] as? String { return text }
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func userFacingErrorMessage(statusCode: Int, data: Data) -> String {
        let fallback = "Custom AI request failed (\(statusCode)). Check the Custom AI URL and API key in Settings."
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let error = object["error"] as? [String: Any]
        else {
            return fallback
        }

        let message = error["message"] as? String ?? ""
        if statusCode == 401 || statusCode == 403 {
            return "Custom AI access was denied. Check the Custom AI API key in Settings."
        }
        if statusCode == 429 {
            return "Custom AI quota was reached. Wait a bit or check your FreeLLMAPI/provider quotas."
        }
        if !message.isEmpty {
            return "Custom AI request failed (\(statusCode)): \(message)"
        }
        return fallback
    }
}
