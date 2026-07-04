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
        #expect(RadixPreferenceKey.collections == "radix.characterCollections")
        #expect(RadixPreferenceKey.selectedAICollection == "radix.selectedAICollectionID")
        #expect(RadixPreferenceKey.searchHistory == "radix.searchHistory")
        #expect(RadixPreferenceKey.promptConfig == "radix.promptConfig")
        #expect(RadixPreferenceKey.promptTaskSelection == "radix.promptSelectedTaskIDs")
        #expect(RadixPreferenceKey.conversationPracticeTopic == "radix.conversationPracticeTopicID")
        #expect(RadixPreferenceKey.aiConversationEntryCount == "radix.aiConversationEntryCount")
        #expect(RadixPreferenceKey.importedConversationPracticePacks == "radix.importedConversationPracticePacks")
        #expect(RadixPreferenceKey.conversationPracticeProgress == "radix.conversationPracticeProgress")
    }

    @Test("Legacy speech identifiers stay available for migration")
    func legacySpeechIdentifiers() {
        #expect(RadixPreferenceKey.speechEnabled == "radix.speechEnabled")
        #expect(RadixPreferenceKey.legacySpeakOnSelection == "radix.speakOnSelection")
        #expect(RadixPreferenceKey.legacySpeakOnPreview == "radix.speakOnPreview")
    }
}
