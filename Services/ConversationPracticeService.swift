import Foundation

enum ConversationPracticeServiceError: LocalizedError {
    case missingPack(String)
    case invalidPack(String, [ConversationPracticeValidationIssue])

    var errorDescription: String? {
        switch self {
        case .missingPack(let resourceName):
            return "Missing \(resourceName).json in the app bundle."
        case .invalidPack(let resourceName, let issues):
            let summary = issues.map(\.description).joined(separator: "\n")
            return "Conversation practice pack \(resourceName).json is invalid.\n\(summary)"
        }
    }
}

struct ConversationPracticeService {
    func loadStarterLibrary(bundle: Bundle = .main) throws -> ConversationPracticeLibrary {
        guard let library = try loadLibrary(for: .generalGreetings, bundle: bundle) else {
            throw ConversationPracticeServiceError.missingPack(ConversationPracticeTopic.generalGreetings.bundledResourceName ?? "conversation100")
        }
        return library
    }

    func loadLibrary(
        for topic: ConversationPracticeTopic,
        bundle: Bundle = .main
    ) throws -> ConversationPracticeLibrary? {
        guard let resourceName = topic.bundledResourceName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !resourceName.isEmpty
        else {
            return nil
        }

        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw ConversationPracticeServiceError.missingPack(resourceName)
        }

        let data = try Data(contentsOf: url)
        let pack = try JSONDecoder().decode(ConversationPracticePack.self, from: data)
        let validation = ConversationPracticeRules.validate(pack)
        guard validation.isValid else {
            throw ConversationPracticeServiceError.invalidPack(resourceName, validation.errors)
        }
        return pack.practiceLibrary
    }

    func loadPack(from data: Data, sourceName: String) throws -> ConversationPracticePack {
        let pack = try JSONDecoder().decode(ConversationPracticePack.self, from: data)
        let validation = ConversationPracticeRules.validate(pack)
        guard validation.isValid else {
            throw ConversationPracticeServiceError.invalidPack(sourceName, validation.errors)
        }
        return pack
    }

    func loadPack(fromPastedText text: String, sourceName: String) throws -> ConversationPracticePack {
        var lastError: Error?
        for candidate in ConversationPracticeRules.importJSONCandidates(from: text) {
            guard let data = candidate.data(using: .utf8) else { continue }
            do {
                return try loadPack(from: data, sourceName: sourceName)
            } catch {
                lastError = error
            }
        }
        if let lastError {
            throw lastError
        }
        throw DecodingError.dataCorrupted(.init(
            codingPath: [],
            debugDescription: "Paste a JSON object with a theme and entries."
        ))
    }

    func loadLibrary(from data: Data, sourceName: String) throws -> ConversationPracticeLibrary {
        try loadPack(from: data, sourceName: sourceName).practiceLibrary
    }
}
