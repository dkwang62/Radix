import Foundation

struct ConversationPracticeStore: @unchecked Sendable {
    private let preferences: any RadixPreferenceStore

    init(preferences: any RadixPreferenceStore) {
        self.preferences = preferences
    }

    var importedPacks: [ConversationPracticePack] {
        get {
            decode([ConversationPracticePack].self, forKey: RadixPreferenceKey.importedConversationPracticePacks) ?? []
        }
        nonmutating set {
            encode(newValue, forKey: RadixPreferenceKey.importedConversationPracticePacks)
        }
    }

    var progress: ConversationPracticeProgressSnapshot {
        get {
            decode(ConversationPracticeProgressSnapshot.self, forKey: RadixPreferenceKey.conversationPracticeProgress)
                ?? ConversationPracticeProgressSnapshot()
        }
        nonmutating set {
            encode(newValue, forKey: RadixPreferenceKey.conversationPracticeProgress)
        }
    }

    private func decode<Value: Decodable>(_ type: Value.Type, forKey key: String) -> Value? {
        guard let data = preferences.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func encode<Value: Encodable>(_ value: Value, forKey key: String) {
        preferences.set(try? JSONEncoder().encode(value), forKey: key)
    }
}

struct PageStudyArtifactStore: @unchecked Sendable {
    private let preferences: any RadixPreferenceStore

    init(preferences: any RadixPreferenceStore) {
        self.preferences = preferences
    }

    var phraseExtractions: [PagePhraseExtractionRecord] {
        get {
            decode([PagePhraseExtractionRecord].self, forKey: RadixPreferenceKey.pagePhraseExtractions) ?? []
        }
        nonmutating set {
            let records = newValue
                .filter { !$0.phraseWords.isEmpty }
                .sorted { $0.extractedAt > $1.extractedAt }
            encode(records, forKey: RadixPreferenceKey.pagePhraseExtractions)
        }
    }

    func recordPhraseExtraction(
        pageID: UUID,
        title: String,
        words: [String],
        extractedAt: Date
    ) {
        let cleanWords = PagePhraseExtractionRecord.deduplicated(words)
        guard !cleanWords.isEmpty else { return }

        var records = phraseExtractions
        if let index = records.firstIndex(where: { $0.sourcePageID == pageID }) {
            records[index] = records[index].merging(
                words: cleanWords,
                title: title,
                extractedAt: extractedAt
            )
        } else {
            records.append(PagePhraseExtractionRecord(
                sourcePageID: pageID,
                sourceTitle: title,
                phraseWords: cleanWords,
                extractedAt: extractedAt
            ))
        }
        phraseExtractions = records
    }

    var cleanedPages: [AICleanedPageRecord] {
        get {
            decode([AICleanedPageRecord].self, forKey: RadixPreferenceKey.aiCleanedPages) ?? []
        }
        nonmutating set {
            let records = newValue
                .filter { !$0.cleanedChineseText.isEmpty || !$0.sentences.isEmpty }
                .sorted { $0.createdAt > $1.createdAt }
            encode(records, forKey: RadixPreferenceKey.aiCleanedPages)
        }
    }

    func cleanedPage(for pageID: UUID) -> AICleanedPageRecord? {
        cleanedPages.first { $0.sourcePageID == pageID }
    }

    func replaceCleanedPage(_ record: AICleanedPageRecord) {
        var records = cleanedPages
        records.removeAll { $0.sourcePageID == record.sourcePageID }
        records.append(record)
        cleanedPages = records
    }

    private func decode<Value: Decodable>(_ type: Value.Type, forKey key: String) -> Value? {
        guard let data = preferences.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func encode<Value: Encodable>(_ value: Value, forKey key: String) {
        preferences.set(try? JSONEncoder().encode(value), forKey: key)
    }
}
