import Foundation
import Testing
@testable import RadixCore

@Suite("Study persistence ownership")
struct StudyPersistenceStoreTests {
    @Test("Conversation practice store round-trips packs and progress")
    func conversationPracticeRoundTrip() {
        let preferences = InMemoryStudyPreferenceStore()
        let store = ConversationPracticeStore(preferences: preferences)
        let pack = ConversationPracticePack(
            packID: "practice-1",
            version: "1",
            title: "Practice",
            description: "",
            language: "zh-CN",
            sourceType: "test",
            createdFor: "Radix",
            sourceLink: nil,
            entries: []
        )
        var progress = ConversationPracticeProgressSnapshot()
        progress.record(
            packID: pack.packID,
            itemID: "item-1",
            outcome: .good,
            practicedAt: Date(timeIntervalSince1970: 100)
        )

        store.importedPacks = [pack]
        store.progress = progress

        let restored = ConversationPracticeStore(preferences: preferences)
        #expect(restored.importedPacks == [pack])
        #expect(restored.progress == progress)
        #expect(preferences.data(forKey: RadixPreferenceKey.importedConversationPracticePacks) != nil)
        #expect(preferences.data(forKey: RadixPreferenceKey.conversationPracticeProgress) != nil)
    }

    @Test("Page artifact store preserves normalization and replacement rules")
    func pageArtifactRules() {
        let preferences = InMemoryStudyPreferenceStore()
        let store = PageStudyArtifactStore(preferences: preferences)
        let pageID = UUID(uuidString: "00000000-0000-0000-0000-000000000501")!

        store.recordPhraseExtraction(
            pageID: pageID,
            title: "First",
            words: ["学习", " 学习 ", "中文"],
            extractedAt: Date(timeIntervalSince1970: 100)
        )
        store.recordPhraseExtraction(
            pageID: pageID,
            title: "Updated",
            words: ["中文", "语言"],
            extractedAt: Date(timeIntervalSince1970: 200)
        )

        #expect(store.phraseExtractions.count == 1)
        #expect(store.phraseExtractions.first?.sourceTitle == "Updated")
        #expect(store.phraseExtractions.first?.phraseWords == ["学习", "中文", "语言"])

        let firstPage = AICleanedPageRecord(
            sourcePageID: pageID,
            sourceTitle: "Source",
            cleanedTitle: "First",
            cleanedChineseText: "你好。",
            sentences: [],
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let replacement = AICleanedPageRecord(
            sourcePageID: pageID,
            sourceTitle: "Source",
            cleanedTitle: "Replacement",
            cleanedChineseText: "你好世界。",
            sentences: [],
            createdAt: Date(timeIntervalSince1970: 200)
        )
        store.replaceCleanedPage(firstPage)
        store.replaceCleanedPage(replacement)

        #expect(store.cleanedPages == [replacement])
        #expect(store.cleanedPage(for: pageID) == replacement)
        #expect(preferences.data(forKey: RadixPreferenceKey.pagePhraseExtractions) != nil)
        #expect(preferences.data(forKey: RadixPreferenceKey.aiCleanedPages) != nil)
    }

    @Test("Corrupt study payloads fail closed without crossing store boundaries")
    func corruptPayloadFallbacks() {
        let preferences = InMemoryStudyPreferenceStore()
        preferences.set(Data("not-json".utf8), forKey: RadixPreferenceKey.conversationPracticeProgress)
        preferences.set(Data("not-json".utf8), forKey: RadixPreferenceKey.aiCleanedPages)

        #expect(ConversationPracticeStore(preferences: preferences).progress.records.isEmpty)
        #expect(PageStudyArtifactStore(preferences: preferences).cleanedPages.isEmpty)
    }
}

private final class InMemoryStudyPreferenceStore: RadixPreferenceStore, @unchecked Sendable {
    private var values: [String: Any] = [:]

    func data(forKey key: String) -> Data? { values[key] as? Data }
    func string(forKey key: String) -> String? { values[key] as? String }
    func bool(forKey key: String) -> Bool { values[key] as? Bool ?? false }
    func integer(forKey key: String) -> Int { values[key] as? Int ?? 0 }
    func double(forKey key: String) -> Double { values[key] as? Double ?? 0 }
    func array(forKey key: String) -> [Any]? { values[key] as? [Any] }
    func dictionary(forKey key: String) -> [String: Any]? { values[key] as? [String: Any] }
    func object(forKey key: String) -> Any? { values[key] }
    func set(_ value: Any?, forKey key: String) { values[key] = value }
    func removeObject(forKey key: String) { values.removeValue(forKey: key) }
}
