import Foundation

enum RadixStudyPreferences {
    private static let usesTraditionalScriptKey = "studyGridUsesTraditionalScript"
    private static let gridScopeKey = "studyGridScope"
    private static let savedPagesDefaultMigrationKey = "studyGridScopeSavedPagesDefaultV1"
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
                return .savedPages
            }
            return StudyGridScope(rawValue: rawValue) ?? .savedPages
        }
        set { preferences.set(newValue.rawValue, forKey: gridScopeKey) }
    }

    static var initialGridScope: StudyGridScope {
        migrateSavedPagesDefaultIfNeeded()
        return gridScope
    }

    static func migrateSavedPagesDefaultIfNeeded() {
        guard preferences.object(forKey: savedPagesDefaultMigrationKey) == nil else { return }
        gridScope = .savedPages
        preferences.set(true, forKey: savedPagesDefaultMigrationKey)
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

    static var sentenceExamples: [SentenceExampleRecord] {
        get {
            guard let data = preferences.data(forKey: RadixPreferenceKey.sentenceExamples) else {
                return []
            }
            return (try? JSONDecoder().decode([SentenceExampleRecord].self, from: data)) ?? []
        }
        set {
            let records = SentenceExampleRecord.upserting(newValue, into: [])
            let data = try? JSONEncoder().encode(records)
            preferences.set(data, forKey: RadixPreferenceKey.sentenceExamples)
        }
    }

    static var currentSentenceExamples: [SentenceExampleRecord] {
        migrateLegacyFavoriteSentencesIntoSentenceExamples()
        return sentenceExamples
    }

    static func recordSentenceExamples(_ records: [SentenceExampleRecord]) {
        guard !records.isEmpty else { return }
        sentenceExamples = SentenceExampleRecord.upserting(records, into: sentenceExamples)
    }

    static func recordSentenceExamples(from pack: ConversationPracticePack, createdAt: Date = Date()) {
        let favoriteIDs = Set(favoriteSentences.map(\.sourceItemID))
        let records = pack.practiceItems.map { item in
            SentenceExampleRecord.fromPracticeItem(
                item,
                pack: pack,
                isFavorited: favoriteIDs.contains(item.id),
                createdAt: createdAt
            )
        }
        recordSentenceExamples(records)
    }

    @discardableResult
    static func recordSentenceExamples(fromCaptureText text: String, createdAt: Date = Date()) -> [SentenceExampleRecord] {
        let records = RadixCaptureJSONParser.sentenceExamples(from: text, createdAt: createdAt)
        recordSentenceExamples(records)
        return records
    }

    @discardableResult
    static func recordSentenceExamples(
        fromOCRText text: String,
        sourcePageID: UUID,
        sourceTitle: String,
        createdAt: Date = Date()
    ) -> [SentenceExampleRecord] {
        let records = SentenceExampleRecord.fromOCRText(
            text,
            sourcePageID: sourcePageID,
            sourceTitle: sourceTitle,
            createdAt: createdAt
        )
        recordSentenceExamples(records)
        return records
    }

    static func canonicalizedConversationPracticePack(_ pack: ConversationPracticePack) -> ConversationPracticePack {
        recordSentenceExamples(from: pack)
        return pack.withCanonicalSentenceReferences(from: sentenceExamples)
    }

    @discardableResult
    static func migrateImportedConversationPracticePacksIntoSentenceExamples() -> Bool {
        let packs = importedConversationPracticePacks
        guard !packs.isEmpty else { return false }
        var didMigrate = false
        let migrated = packs.map { pack -> ConversationPracticePack in
            guard pack.needsCanonicalSentenceReferences else { return pack }
            didMigrate = true
            return canonicalizedConversationPracticePack(pack)
        }
        if didMigrate {
            importedConversationPracticePacks = migrated
        }
        return didMigrate
    }

    static func prepareSentenceExamplesForBackup() {
        migrateImportedConversationPracticePacksIntoSentenceExamples()
        migrateLegacyFavoriteSentencesIntoSentenceExamples()
    }

    static func refreshConversationPracticePackSentenceReferences() {
        let packs = importedConversationPracticePacks
        guard !packs.isEmpty else { return }
        importedConversationPracticePacks = packs.map {
            $0.withCanonicalSentenceReferences(from: sentenceExamples)
        }
    }

    static func setSentenceExampleFavorite(_ item: ConversationPracticeItem, isFavorited: Bool) {
        var records = sentenceExamples
        let incoming = SentenceExampleRecord.fromPracticeItem(item, pack: nil, isFavorited: isFavorited)
        let key = incoming.normalizedChineseKey
        if let index = records.firstIndex(where: { $0.normalizedChineseKey == key }) {
            records[index].isFavorited = isFavorited
            records[index].qualityScore = max(0, records[index].qualityScore + (isFavorited ? 2 : -2))
        } else {
            records.append(incoming)
        }
        sentenceExamples = records
        setCompatibilityFavoriteRecord(FavoriteSentenceRecord(item: item), isFavorited: isFavorited)
    }

    static func setSentenceExampleFavorite(id: UUID, isFavorited: Bool) {
        var updatedRecord: SentenceExampleRecord?
        updateSentenceExample(id: id) { record in
            record.isFavorited = isFavorited
            record.qualityScore = max(0, record.qualityScore + (isFavorited ? 2 : -2))
            updatedRecord = record
        }
        if let updatedRecord {
            setCompatibilityFavoriteRecord(FavoriteSentenceRecord(sentenceExample: updatedRecord), isFavorited: isFavorited)
        }
    }

    static func setSentenceExampleHidden(id: UUID, isHidden: Bool) {
        updateSentenceExample(id: id) { record in
            record.isHidden = isHidden
        }
    }

    static func replaceSentenceExample(_ updated: SentenceExampleRecord) {
        var records = sentenceExamples
        guard let index = records.firstIndex(where: { $0.id == updated.id }) else {
            recordSentenceExamples([updated])
            if updated.isFavorited {
                setCompatibilityFavoriteRecord(FavoriteSentenceRecord(sentenceExample: updated), isFavorited: true)
            }
            return
        }

        let previous = records[index]
        records[index] = updated
        sentenceExamples = records

        if previous.normalizedChineseKey != updated.normalizedChineseKey {
            removeCompatibilityFavoriteRecord(matchingChinese: previous.chinese)
        }

        if updated.isFavorited {
            setCompatibilityFavoriteRecord(FavoriteSentenceRecord(sentenceExample: updated), isFavorited: true)
        } else {
            removeCompatibilityFavoriteRecord(matchingChinese: updated.chinese)
        }
    }

    static func deleteSentenceExample(id: UUID) {
        let deleted = sentenceExamples.first { $0.id == id }
        sentenceExamples = sentenceExamples.filter { $0.id != id }
        if let deleted {
            removeCompatibilityFavoriteRecord(matchingChinese: deleted.chinese)
        }
    }

    private static func updateSentenceExample(id: UUID, mutate: (inout SentenceExampleRecord) -> Void) {
        var records = sentenceExamples
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        mutate(&records[index])
        sentenceExamples = records
    }

    static func migrateLegacyFavoriteSentencesIntoSentenceExamples() {
        let records = favoriteSentences
        guard !records.isEmpty else { return }
        let existingByKey = Dictionary(
            uniqueKeysWithValues: sentenceExamples.map { ($0.normalizedChineseKey, $0) }
        )
        let missingRecords = records.compactMap { record -> SentenceExampleRecord? in
            let incoming = SentenceExampleRecord.fromFavoriteSentence(record)
            if let existing = existingByKey[incoming.normalizedChineseKey], existing.isFavorited {
                return nil
            }
            return incoming
        }
        recordSentenceExamples(missingRecords)
    }

    static func setCompatibilityFavoriteRecord(_ record: FavoriteSentenceRecord, isFavorited: Bool) {
        if isFavorited {
            favoriteSentences = favoriteSentences + [record]
        } else {
            removeCompatibilityFavoriteRecord(matchingChinese: record.simplified)
        }
    }

    static func removeCompatibilityFavoriteRecord(matchingChinese chinese: String) {
        let id = FavoriteSentenceRecord.identifier(forChinese: chinese)
        favoriteSentences = favoriteSentences.filter { record in
            record.id != id &&
                SentenceExampleRecord.normalizedChineseKey(record.simplified) != SentenceExampleRecord.normalizedChineseKey(chinese)
        }
    }

    static func favoriteSentenceExamples() -> [SentenceExampleRecord] {
        SentenceExampleRecord.ranked(currentSentenceExamples).filter(\.isFavorited)
    }

    static func sentenceExamples(containingCharacter character: String, limit: Int? = nil) -> [SentenceExampleRecord] {
        limited(
            SentenceExampleRecord.ranked(currentSentenceExamples).filter { $0.containsCharacter(character) },
            limit: limit
        )
    }

    static func sentenceExamples(containingPhrase phrase: String, limit: Int? = nil) -> [SentenceExampleRecord] {
        limited(
            SentenceExampleRecord.ranked(currentSentenceExamples).filter { $0.containsPhrase(phrase) },
            limit: limit
        )
    }

    static func sentenceExamples(linkedToPageID pageID: UUID, limit: Int? = nil) -> [SentenceExampleRecord] {
        limited(
            SentenceExampleRecord.ranked(currentSentenceExamples).filter { $0.isLinked(toPageID: pageID) },
            limit: limit
        )
    }

    static func sentenceExamples(sourceType: SentenceExampleSourceType, limit: Int? = nil) -> [SentenceExampleRecord] {
        limited(
            SentenceExampleRecord.ranked(currentSentenceExamples).filter { $0.hasSourceType(sourceType) },
            limit: limit
        )
    }

    static func applyImportedSentenceExamples(_ records: [SentenceExampleRecord]?, mode: RestoreMode) {
        switch mode {
        case .additive:
            recordSentenceExamples(records ?? [])
        case .complete:
            sentenceExamples = records ?? []
        }
        refreshConversationPracticePackSentenceReferences()
    }

    private static func limited(_ records: [SentenceExampleRecord], limit: Int?) -> [SentenceExampleRecord] {
        guard let limit else { return records }
        return Array(records.prefix(limit))
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
