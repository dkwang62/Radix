import Foundation

struct ConversationPracticeTranslationQuizPresentation: Identifiable {
    let id = UUID()
    let library: ConversationPracticeLibrary
}

struct ConversationPracticeTranslationRound: Equatable {
    let itemID: String
    let scriptFilter: ScriptFilter
    let direction: ConversationPracticeTranslationDirection
    let choices: [ConversationPracticeItem]
}

enum ConversationPracticeTranslationDirection: String, CaseIterable, Identifiable {
    case englishToChinese = "To Chinese"
    case chineseToEnglish = "To English"

    var id: String { rawValue }

    var prompt: String {
        switch self {
        case .englishToChinese: return "Choose the Chinese sentence."
        case .chineseToEnglish: return "Choose the English meaning."
        }
    }
}
