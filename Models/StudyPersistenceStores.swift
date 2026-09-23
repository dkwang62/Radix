import Foundation

private final class ConversationPracticeStoreCache: @unchecked Sendable {
    private let lock = NSLock()
    private var importedPacksData: Data?
    private var importedPacksValue: [ConversationPracticePack] = []
    private var hasLoadedImportedPacks = false
    private var progressData: Data?
    private var progressValue = ConversationPracticeProgressSnapshot()
    private var hasLoadedProgress = false

    func importedPacks(from data: Data?) -> [ConversationPracticePack] {
        lock.lock()
        defer { lock.unlock() }
        if hasLoadedImportedPacks, importedPacksData == data {
            return importedPacksValue
        }
        let decoded = data.flatMap { try? JSONDecoder().decode([ConversationPracticePack].self, from: $0) } ?? []
        importedPacksData = data
        importedPacksValue = decoded
        hasLoadedImportedPacks = true
        return decoded
    }

    func storeImportedPacks(_ value: [ConversationPracticePack], data: Data?) {
        lock.lock()
        importedPacksData = data
        importedPacksValue = value
        hasLoadedImportedPacks = true
        lock.unlock()
    }

    func progress(from data: Data?) -> ConversationPracticeProgressSnapshot {
        lock.lock()
        defer { lock.unlock() }
        if hasLoadedProgress, progressData == data {
            return progressValue
        }
        let decoded = data.flatMap { try? JSONDecoder().decode(ConversationPracticeProgressSnapshot.self, from: $0) }
            ?? ConversationPracticeProgressSnapshot()
        progressData = data
        progressValue = decoded
        hasLoadedProgress = true
        return decoded
    }

    func storeProgress(_ value: ConversationPracticeProgressSnapshot, data: Data?) {
        lock.lock()
        progressData = data
        progressValue = value
        hasLoadedProgress = true
        lock.unlock()
    }

    func clear() {
        lock.lock()
        importedPacksData = nil
        importedPacksValue = []
        hasLoadedImportedPacks = true
        progressData = nil
        progressValue = ConversationPracticeProgressSnapshot()
        hasLoadedProgress = true
        lock.unlock()
    }
}

struct ConversationPracticeStore: @unchecked Sendable {
    private let preferences: any RadixPreferenceStore
    private let cache = ConversationPracticeStoreCache()

    init(preferences: any RadixPreferenceStore) {
        self.preferences = preferences
    }

    var importedPacks: [ConversationPracticePack] {
        get {
            cache.importedPacks(from: preferences.data(forKey: RadixPreferenceKey.importedConversationPracticePacks))
        }
        nonmutating set {
            let data = try? JSONEncoder().encode(newValue)
            preferences.set(data, forKey: RadixPreferenceKey.importedConversationPracticePacks)
            cache.storeImportedPacks(newValue, data: data)
        }
    }

    var progress: ConversationPracticeProgressSnapshot {
        get {
            cache.progress(from: preferences.data(forKey: RadixPreferenceKey.conversationPracticeProgress))
        }
        nonmutating set {
            let data = try? JSONEncoder().encode(newValue)
            preferences.set(data, forKey: RadixPreferenceKey.conversationPracticeProgress)
            cache.storeProgress(newValue, data: data)
        }
    }

    func clearUserData() {
        preferences.removeObject(forKey: RadixPreferenceKey.importedConversationPracticePacks)
        preferences.removeObject(forKey: RadixPreferenceKey.conversationPracticeProgress)
        cache.clear()
    }
}

private final class PageStudyArtifactStoreCache: @unchecked Sendable {
    private let lock = NSLock()
    private var phraseData: Data?
    private var phraseValue: [PagePhraseExtractionRecord] = []
    private var hasLoadedPhrases = false
    private var cleanedData: Data?
    private var cleanedValue: [AICleanedPageRecord] = []
    private var hasLoadedCleanedPages = false

    func phraseExtractions(from data: Data?) -> [PagePhraseExtractionRecord] {
        lock.lock()
        defer { lock.unlock() }
        if hasLoadedPhrases, phraseData == data { return phraseValue }
        let decoded = data.flatMap { try? JSONDecoder().decode([PagePhraseExtractionRecord].self, from: $0) } ?? []
        phraseData = data
        phraseValue = decoded
        hasLoadedPhrases = true
        return decoded
    }

    func storePhraseExtractions(_ value: [PagePhraseExtractionRecord], data: Data?) {
        lock.lock()
        phraseData = data
        phraseValue = value
        hasLoadedPhrases = true
        lock.unlock()
    }

    func cleanedPages(from data: Data?) -> [AICleanedPageRecord] {
        lock.lock()
        defer { lock.unlock() }
        if hasLoadedCleanedPages, cleanedData == data { return cleanedValue }
        let decoded = data.flatMap { try? JSONDecoder().decode([AICleanedPageRecord].self, from: $0) } ?? []
        cleanedData = data
        cleanedValue = decoded
        hasLoadedCleanedPages = true
        return decoded
    }

    func storeCleanedPages(_ value: [AICleanedPageRecord], data: Data?) {
        lock.lock()
        cleanedData = data
        cleanedValue = value
        hasLoadedCleanedPages = true
        lock.unlock()
    }

    func clear() {
        lock.lock()
        phraseData = nil
        phraseValue = []
        hasLoadedPhrases = true
        cleanedData = nil
        cleanedValue = []
        hasLoadedCleanedPages = true
        lock.unlock()
    }
}

struct PageStudyArtifactStore: @unchecked Sendable {
    private let preferences: any RadixPreferenceStore
    private let cache = PageStudyArtifactStoreCache()

    init(preferences: any RadixPreferenceStore) {
        self.preferences = preferences
    }

    var phraseExtractions: [PagePhraseExtractionRecord] {
        get {
            cache.phraseExtractions(from: preferences.data(forKey: RadixPreferenceKey.pagePhraseExtractions))
        }
        nonmutating set {
            let records = newValue
                .map { $0.simplifiedChinese(using: ScriptTextConverter.simplified) }
                .filter { !$0.phraseWords.isEmpty }
                .sorted { $0.extractedAt > $1.extractedAt }
            let data = try? JSONEncoder().encode(records)
            preferences.set(data, forKey: RadixPreferenceKey.pagePhraseExtractions)
            cache.storePhraseExtractions(records, data: data)
        }
    }

    func recordPhraseExtraction(
        pageID: UUID,
        title: String,
        words: [String],
        extractedAt: Date
    ) {
        let cleanWords = PagePhraseExtractionRecord.deduplicated(words.map(ScriptTextConverter.simplified))
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
            cache.cleanedPages(from: preferences.data(forKey: RadixPreferenceKey.aiCleanedPages))
        }
        nonmutating set {
            let records = newValue
                .filter { !$0.cleanedChineseText.isEmpty || !$0.sentences.isEmpty }
                .sorted { $0.createdAt > $1.createdAt }
            let data = try? JSONEncoder().encode(records)
            preferences.set(data, forKey: RadixPreferenceKey.aiCleanedPages)
            cache.storeCleanedPages(records, data: data)
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

    func clearUserData() {
        preferences.removeObject(forKey: RadixPreferenceKey.pagePhraseExtractions)
        preferences.removeObject(forKey: RadixPreferenceKey.aiCleanedPages)
        cache.clear()
    }
}
