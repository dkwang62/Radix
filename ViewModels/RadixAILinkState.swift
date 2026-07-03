import Foundation

/// Portable AI Link templates, task selection, and launch workflow state.
/// Provider credentials and device preferences intentionally remain separate.
struct RadixAILinkState {
    var activeSubject: ActiveSubject?
    var promptConfig: PromptConfig = .streamlitDefault
    var selectedTaskIDs: [String] = PromptConfig.defaultSelectedTaskIDs
    var autosaveStatus = "Changes save automatically."
    var shouldAutoOpenTask4 = false
    var shouldAutoRunGeminiPhraseAPI = false
    var selectedConversationPracticeTopicID = ConversationPracticeTopic.generalGreetings.id
    var conversationEntryCount = 25
}
