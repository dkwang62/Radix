import Foundation

enum ConversationPracticeServiceError: LocalizedError {
    case missingStarterPack
    case invalidStarterPack([ConversationPracticeValidationIssue])

    var errorDescription: String? {
        switch self {
        case .missingStarterPack:
            return "Missing conversation100.json in the app bundle."
        case .invalidStarterPack(let issues):
            let summary = issues.map(\.description).joined(separator: "\n")
            return "Conversation practice starter pack is invalid.\n\(summary)"
        }
    }
}

struct ConversationPracticeService {
    func loadStarterLibrary(bundle: Bundle = .main) throws -> ConversationPracticeLibrary {
        guard let url = bundle.url(forResource: "conversation100", withExtension: "json") else {
            throw ConversationPracticeServiceError.missingStarterPack
        }

        let data = try Data(contentsOf: url)
        let pack = try JSONDecoder().decode(ConversationPracticePack.self, from: data)
        let validation = ConversationPracticeRules.validate(pack)
        guard validation.isValid else {
            throw ConversationPracticeServiceError.invalidStarterPack(validation.errors)
        }
        return pack.practiceLibrary
    }
}
