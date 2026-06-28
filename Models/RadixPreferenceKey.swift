import Foundation

/// Stable persisted identifiers shared by every Apple form factor.
/// Keep raw values unchanged so existing installations and exported profiles
/// remain compatible; these names also provide a migration map for Android.
enum RadixPreferenceKey {
    static let favorites = "radix.favorites"
    static let favoriteEntries = "radix.favoriteEntries"
    static let favoritePhrases = "radix.favoritePhrases"
    static let favoritePhraseDates = "radix.favoritePhraseDates"
    static let overlayAddedDates = "radix.overlayAddedDates"

    static let speechEnabled = "radix.speechEnabled"
    static let legacySpeakOnSelection = "radix.speakOnSelection"
    static let legacySpeakOnPreview = "radix.speakOnPreview"

    static let promptConfig = "radix.promptConfig"
    static let promptTaskSelection = "radix.promptSelectedTaskIDs"
    static let conversationPracticeTopic = "radix.conversationPracticeTopicID"
    static let importedConversationPracticePacks = "radix.importedConversationPracticePacks"
    static let defaultAIPreset = "radix.defaultAIPreset"
    static let customAIURL = "radix.customAIURL"
    static let openAIAPIKey = "radix.openAIAPIKey"
    static let geminiAPIKey = "radix.geminiAPIKey"
    static let claudeAPIKey = "radix.claudeAPIKey"
    static let deepSeekAPIKey = "radix.deepSeekAPIKey"
    static let customAIAPIKey = "radix.customAIAPIKey"
    static let geminiModelID = "radix.geminiModelID"

    static let collections = "radix.characterCollections"
    static let selectedAICollection = "radix.selectedAICollectionID"
    static let lastPreviewCharacter = "radix.lastPreviewCharacter"
    static let searchHistory = "radix.searchHistory"
    static let rootBreadcrumb = "radix.rootBreadcrumb"
    static let sidebarNavigationStyle = "radix.sidebarNavigationStyle"
    static let standardDataImportID = "radix.standardDataImportID"
}
