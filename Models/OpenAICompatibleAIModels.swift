import Foundation

struct OpenAICompatibleEndpoint: Equatable {
    var baseURLString: String

    var chatCompletionsURL: URL? {
        let trimmed = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let urlString: String
        if let direct = URL(string: trimmed), direct.scheme != nil, direct.host != nil {
            urlString = direct.absoluteString
        } else {
            urlString = "https://\(trimmed)"
        }

        guard var components = URLComponents(string: urlString) else { return nil }
        var path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if path.hasSuffix("chat/completions") {
            components.path = "/\(path)"
            return components.url
        }
        if path.hasSuffix("v1") {
            path += "/chat/completions"
        } else if path.isEmpty {
            path = "v1/chat/completions"
        } else {
            path += "/v1/chat/completions"
        }
        components.path = "/\(path)"
        return components.url
    }
}
