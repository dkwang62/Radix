import Foundation

enum RadixStudyPreferences {
    private static let usesTraditionalScriptKey = "studyGridUsesTraditionalScript"
    private static let gridScopeKey = "studyGridScope"
    private static let pageSortOrderKey = "studyPageSortOrder"
    private static let hasDismissedIntroKey = "hasDismissedStudyIntroV1"
    private static let preferences = RadixPreferences.standard

    static var usesTraditionalScript: Bool {
        get { preferences.bool(forKey: usesTraditionalScriptKey) }
        set { preferences.set(newValue, forKey: usesTraditionalScriptKey) }
    }

    static var gridScope: StudyGridScope {
        get {
            guard let rawValue = preferences.string(forKey: gridScopeKey) else {
                return .all
            }
            return StudyGridScope(rawValue: rawValue) ?? .all
        }
        set { preferences.set(newValue.rawValue, forKey: gridScopeKey) }
    }

    static var pageSortOrder: PageCollectionSortOrder {
        get {
            guard let rawValue = preferences.string(forKey: pageSortOrderKey) else {
                return .lastViewed
            }
            return PageCollectionSortOrder(rawValue: rawValue) ?? .lastViewed
        }
        set { preferences.set(newValue.rawValue, forKey: pageSortOrderKey) }
    }

    static var hasDismissedIntro: Bool {
        get { preferences.bool(forKey: hasDismissedIntroKey) }
        set { preferences.set(newValue, forKey: hasDismissedIntroKey) }
    }

    static var importedConversationPracticePacks: [ConversationPracticePack] {
        get {
            guard let data = preferences.data(forKey: RadixPreferenceKey.importedConversationPracticePacks) else {
                return []
            }
            return (try? JSONDecoder().decode([ConversationPracticePack].self, from: data)) ?? []
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            preferences.set(data, forKey: RadixPreferenceKey.importedConversationPracticePacks)
        }
    }

    static var conversationPracticeProgress: ConversationPracticeProgressSnapshot {
        get {
            guard let data = preferences.data(forKey: RadixPreferenceKey.conversationPracticeProgress) else {
                return ConversationPracticeProgressSnapshot()
            }
            return (try? JSONDecoder().decode(ConversationPracticeProgressSnapshot.self, from: data))
                ?? ConversationPracticeProgressSnapshot()
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            preferences.set(data, forKey: RadixPreferenceKey.conversationPracticeProgress)
        }
    }

    static var favoriteSentences: [FavoriteSentenceRecord] {
        get {
            guard let data = preferences.data(forKey: RadixPreferenceKey.favoriteSentences) else {
                return []
            }
            return (try? JSONDecoder().decode([FavoriteSentenceRecord].self, from: data)) ?? []
        }
        set {
            let data = try? JSONEncoder().encode(FavoriteSentenceRecord.deduplicated(newValue))
            preferences.set(data, forKey: RadixPreferenceKey.favoriteSentences)
        }
    }

    static var pagePhraseExtractions: [PagePhraseExtractionRecord] {
        get {
            guard let data = preferences.data(forKey: RadixPreferenceKey.pagePhraseExtractions) else {
                return []
            }
            return (try? JSONDecoder().decode([PagePhraseExtractionRecord].self, from: data)) ?? []
        }
        set {
            let records = newValue
                .filter { !$0.phraseWords.isEmpty }
                .sorted { $0.extractedAt > $1.extractedAt }
            let data = try? JSONEncoder().encode(records)
            preferences.set(data, forKey: RadixPreferenceKey.pagePhraseExtractions)
        }
    }

    static func recordPagePhraseExtraction(
        pageID: UUID,
        title: String,
        words: [String],
        extractedAt: Date = Date()
    ) {
        let cleanWords = PagePhraseExtractionRecord.deduplicated(words)
        guard !cleanWords.isEmpty else { return }

        var records = pagePhraseExtractions
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
        pagePhraseExtractions = records
    }
}
