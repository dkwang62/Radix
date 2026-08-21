import Testing
@testable import RadixCore

@Suite("Preference-key compatibility")
struct PreferenceKeyCompatibilityTests {
    @Test("Persisted identifiers remain stable across platforms")
    func stableIdentifiers() {
        #expect(RadixPreferenceKey.favorites == "radix.favorites")
        #expect(RadixPreferenceKey.favoriteEntries == "radix.favoriteEntries")
        #expect(RadixPreferenceKey.favoritePhrases == "radix.favoritePhrases")
        #expect(RadixPreferenceKey.favoriteSentences == "radix.favoriteSentences")
        #expect(RadixPreferenceKey.pagePhraseExtractions == "radix.pagePhraseExtractions")
        #expect(RadixPreferenceKey.aiCleanedPages == "radix.aiCleanedPages")
        #expect(RadixPreferenceKey.browsePageGridFilter == "radix.browsePageGridFilter")
        #expect(RadixPreferenceKey.collections == "radix.characterCollections")
        #expect(RadixPreferenceKey.selectedAICollection == "radix.selectedAICollectionID")
        #expect(RadixPreferenceKey.searchHistory == "radix.searchHistory")
        #expect(RadixPreferenceKey.promptConfig == "radix.promptConfig")
        #expect(RadixPreferenceKey.promptTaskSelection == "radix.promptSelectedTaskIDs")
        #expect(RadixPreferenceKey.conversationPracticeTopic == "radix.conversationPracticeTopicID")
        #expect(RadixPreferenceKey.aiConversationEntryCount == "radix.aiConversationEntryCount")
        #expect(RadixPreferenceKey.aiSentenceExtractionDetail == "radix.aiSentenceExtractionDetail")
        #expect(RadixPreferenceKey.importedConversationPracticePacks == "radix.importedConversationPracticePacks")
        #expect(RadixPreferenceKey.conversationPracticeProgress == "radix.conversationPracticeProgress")
        #expect(RadixPreferenceKey.openAIAPIKey == "radix.openAIAPIKey")
        #expect(RadixPreferenceKey.geminiAPIKey == "radix.geminiAPIKey")
        #expect(RadixPreferenceKey.latestGeminiAPIKey == "radix.latestGeminiAPIKey")
        #expect(RadixPreferenceKey.claudeAPIKey == "radix.claudeAPIKey")
        #expect(RadixPreferenceKey.deepSeekAPIKey == "radix.deepSeekAPIKey")
        #expect(RadixPreferenceKey.customAIAPIKey == "radix.customAIAPIKey")
    }

    @Test("Legacy speech identifiers stay available for migration")
    func legacySpeechIdentifiers() {
        #expect(RadixPreferenceKey.speechEnabled == "radix.speechEnabled")
        #expect(RadixPreferenceKey.legacySpeakOnSelection == "radix.speakOnSelection")
        #expect(RadixPreferenceKey.legacySpeakOnPreview == "radix.speakOnPreview")
    }

    @Test("Gemini key retention keeps the local latest key ahead of restore data")
    func geminiKeyRetentionPrefersLocalLatest() {
        #expect(APIKeyRetentionPolicy.resolvedGeminiKey(
            current: "new-device-key",
            retainedLatest: "retained-key",
            imported: "backup-key"
        ) == "new-device-key")
        #expect(APIKeyRetentionPolicy.resolvedGeminiKey(
            current: "",
            retainedLatest: "retained-key",
            imported: "backup-key"
        ) == "retained-key")
        #expect(APIKeyRetentionPolicy.resolvedGeminiKey(
            current: "",
            retainedLatest: nil,
            imported: "backup-key"
        ) == "backup-key")
        #expect(APIKeyRetentionPolicy.resolvedGeminiKey(
            current: "",
            retainedLatest: nil,
            imported: nil
        ) == "")
    }
}
