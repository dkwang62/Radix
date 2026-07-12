import Foundation
import SQLite3

private let SQLITE_TRANSIENT_SENTENCE_EXAMPLES = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum SentenceExampleQueryScope: Equatable {
    case all
    case favorites
    case pageLinked
    case practice
    case page(UUID, SentenceExampleSourceType?)
}

struct SentenceExampleQuery: Equatable {
    var scope: SentenceExampleQueryScope = .all
    var searchText = ""
    var offset = 0
    var limit: Int? = nil
}

struct SentenceExampleQueryResult: Equatable {
    var records: [SentenceExampleRecord]
    var totalCount: Int
}

enum RadixStudyPreferences {
    private static let usesTraditionalScriptKey = "studyGridUsesTraditionalScript"
    private static let gridScopeKey = "studyGridScope"
    private static let savedPagesDefaultMigrationKey = "studyGridScopeSavedPagesDefaultV1"
    private static let pageSortOrderKey = "studyPageSortOrder"
    private static let hasDismissedIntroKey = "hasDismissedStudyIntroV1"
    private static let preferences = RadixPreferences.standard
    private static let sentenceExampleRepository = SentenceExampleRepository()

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
            return canonicalizedFavoriteSentences(
                (try? JSONDecoder().decode([FavoriteSentenceRecord].self, from: data)) ?? []
            )
        }
        set {
            let data = try? JSONEncoder().encode(canonicalizedFavoriteSentences(newValue))
            preferences.set(data, forKey: RadixPreferenceKey.favoriteSentences)
        }
    }

    static var sentenceExamples: [SentenceExampleRecord] {
        get {
            sentenceExampleRepository.fetchAll(migratingLegacy: legacySentenceExamplesFromPreferences)
        }
        set {
            let records = canonicalizedSentenceExamples(newValue)
            sentenceExampleRepository.replaceAll(records)
        }
    }

    static var currentSentenceExamples: [SentenceExampleRecord] {
        migrateLegacyFavoriteSentencesIntoSentenceExamples()
        return sentenceExamples
    }

    static func querySentenceExamples(_ query: SentenceExampleQuery) -> SentenceExampleQueryResult {
        migrateLegacyFavoriteSentencesIntoSentenceExamples()
        return sentenceExampleRepository.query(query, migratingLegacy: legacySentenceExamplesFromPreferences)
    }

    static func sentenceExamples(matching query: SentenceExampleQuery) -> [SentenceExampleRecord] {
        var allQuery = query
        allQuery.offset = 0
        allQuery.limit = nil
        return querySentenceExamples(allQuery).records
    }

    static func sentenceExample(normalizedKey: String) -> SentenceExampleRecord? {
        sentenceExampleRepository.fetch(
            normalizedKey: normalizedKey,
            migratingLegacy: legacySentenceExamplesFromPreferences
        )
    }

    static func sentenceExamples(normalizedKeys: [String]) -> [String: SentenceExampleRecord] {
        sentenceExampleRepository.fetch(
            normalizedKeys: normalizedKeys,
            migratingLegacy: legacySentenceExamplesFromPreferences
        )
    }

    static func recordSentenceExamples(_ records: [SentenceExampleRecord]) {
        guard !records.isEmpty else { return }
        sentenceExampleRepository.upsert(canonicalizedSentenceExamples(records))
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
        let records = canonicalizedSentenceExamples(
            RadixCaptureJSONParser.sentenceExamples(from: text, createdAt: createdAt)
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
        let incoming = SentenceExampleRecord.fromPracticeItem(item, pack: nil, isFavorited: isFavorited)
        let key = incoming.normalizedChineseKey
        if var existing = sentenceExampleRepository.fetch(normalizedKey: key, migratingLegacy: legacySentenceExamplesFromPreferences) {
            existing.isFavorited = isFavorited
            existing.qualityScore = max(0, existing.qualityScore + (isFavorited ? 2 : -2))
            recordSentenceExamples([existing])
        } else {
            recordSentenceExamples([incoming])
        }
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
        guard let previous = sentenceExampleRepository.fetch(id: updated.id, migratingLegacy: legacySentenceExamplesFromPreferences) else {
            recordSentenceExamples([updated])
            if updated.isFavorited {
                setCompatibilityFavoriteRecord(FavoriteSentenceRecord(sentenceExample: updated), isFavorited: true)
            }
            return
        }

        recordSentenceExamples([updated])

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
        let deleted = sentenceExampleRepository.fetch(id: id, migratingLegacy: legacySentenceExamplesFromPreferences)
        sentenceExampleRepository.delete(id: id)
        if let deleted {
            removeCompatibilityFavoriteRecord(matchingChinese: deleted.chinese)
        }
    }

    static func deleteSentenceExample(matchingChinese chinese: String) {
        let key = SentenceExampleRecord.normalizedChineseKey(chinese)
        guard !key.isEmpty else { return }
        let deleted = sentenceExampleRepository.fetch(normalizedKey: key, migratingLegacy: legacySentenceExamplesFromPreferences)
        sentenceExampleRepository.delete(normalizedKey: key)
        if let deleted {
            removeCompatibilityFavoriteRecord(matchingChinese: deleted.chinese)
        } else {
            removeCompatibilityFavoriteRecord(matchingChinese: chinese)
        }
    }

    private static func updateSentenceExample(id: UUID, mutate: (inout SentenceExampleRecord) -> Void) {
        guard var record = sentenceExampleRepository.fetch(id: id, migratingLegacy: legacySentenceExamplesFromPreferences) else { return }
        mutate(&record)
        recordSentenceExamples([record])
    }

    static func migrateLegacyFavoriteSentencesIntoSentenceExamples() {
        let records = favoriteSentences
        guard !records.isEmpty else { return }
        let missingRecords = records.compactMap { record -> SentenceExampleRecord? in
            let incoming = SentenceExampleRecord.fromFavoriteSentence(record)
            if let existing = sentenceExampleRepository.fetch(
                normalizedKey: incoming.normalizedChineseKey,
                migratingLegacy: legacySentenceExamplesFromPreferences
            ), existing.isFavorited {
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
        let simplifiedChinese = ScriptTextConverter.simplified(chinese)
        let id = FavoriteSentenceRecord.identifier(forChinese: simplifiedChinese)
        favoriteSentences = favoriteSentences.filter { record in
            record.id != id &&
                SentenceExampleRecord.normalizedChineseKey(record.simplified) != SentenceExampleRecord.normalizedChineseKey(simplifiedChinese)
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
            SentenceExampleRecord.ranked(currentSentenceExamples).filter { sentenceExample($0, containsPhrase: phrase) },
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

    static func sentenceExample(_ example: SentenceExampleRecord, containsPhrase phrase: String) -> Bool {
        let simplifiedPhrase = ScriptTextConverter.simplified(phrase)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !simplifiedPhrase.isEmpty else { return false }
        return example.containsPhrase(simplifiedPhrase)
    }

    static func sentenceExample(_ example: SentenceExampleRecord, matchesSearchText query: String) -> Bool {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return true }
        if sentenceExample(example, containsPhrase: trimmedQuery) {
            return true
        }

        let simplifiedQuery = ScriptTextConverter.simplified(trimmedQuery)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let haystack = [
            example.chinese,
            example.pinyin ?? "",
            example.english ?? "",
            example.targetPhrases.joined(separator: " "),
            example.detectedPhrases.joined(separator: " "),
            example.targetCharacters.joined(separator: " "),
            example.detectedCharacters.joined(separator: " "),
            example.sources.compactMap(\.sourceTitle).joined(separator: " "),
            example.tags.joined(separator: " ")
        ]
            .joined(separator: " ")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let foldedQuery = trimmedQuery.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let foldedSimplifiedQuery = simplifiedQuery.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return haystack.contains(foldedQuery) || haystack.contains(foldedSimplifiedQuery)
    }

    private static func limited(_ records: [SentenceExampleRecord], limit: Int?) -> [SentenceExampleRecord] {
        guard let limit else { return records }
        return Array(records.prefix(limit))
    }

    private static func legacySentenceExamplesFromPreferences() -> [SentenceExampleRecord] {
        guard let data = preferences.data(forKey: RadixPreferenceKey.sentenceExamples) else {
            return []
        }
        return (try? JSONDecoder().decode([SentenceExampleRecord].self, from: data)) ?? []
    }

    fileprivate static func canonicalizedSentenceExamples(_ records: [SentenceExampleRecord]) -> [SentenceExampleRecord] {
        SentenceExampleRecord.upserting(records.map(canonicalizedSentenceExample(_:)), into: [])
    }

    fileprivate static func canonicalizedSentenceExample(_ record: SentenceExampleRecord) -> SentenceExampleRecord {
        let simplifiedChinese = ScriptTextConverter.simplified(record.chinese)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let detectedCharacters = SentenceExampleRecord.detectChineseCharacters(in: simplifiedChinese)
        return SentenceExampleRecord(
            id: record.id,
            chinese: simplifiedChinese,
            script: .simplified,
            pinyin: record.pinyin,
            english: record.english,
            sources: record.sources,
            targetCharacters: canonicalizedChineseList(record.targetCharacters),
            targetPhrases: canonicalizedChineseList(record.targetPhrases),
            detectedCharacters: detectedCharacters,
            detectedPhrases: canonicalizedChineseList(record.detectedPhrases),
            grammarPoints: record.grammarPoints,
            hskLevel: record.hskLevel,
            difficulty: record.difficulty,
            naturalness: record.naturalness,
            createdAt: record.createdAt,
            lastUsedAt: record.lastUsedAt,
            usageCount: record.usageCount,
            viewedCount: record.viewedCount,
            practicedCount: record.practicedCount,
            skippedCount: record.skippedCount,
            isFavorited: record.isFavorited,
            isHidden: record.isHidden,
            qualityScore: record.qualityScore,
            notes: record.notes,
            tags: record.tags
        )
    }

    private static func canonicalizedChineseList(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.compactMap { value in
            let simplified = ScriptTextConverter.simplified(value)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !simplified.isEmpty, seen.insert(simplified).inserted else { return nil }
            return simplified
        }
    }

    private static func canonicalizedFavoriteSentences(_ records: [FavoriteSentenceRecord]) -> [FavoriteSentenceRecord] {
        FavoriteSentenceRecord.deduplicated(records.map { record in
            let simplified = ScriptTextConverter.simplified(record.simplified)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return FavoriteSentenceRecord(
                id: FavoriteSentenceRecord.identifier(forChinese: simplified),
                simplified: simplified,
                pinyin: record.pinyin,
                english: record.english,
                sourceSetID: record.sourceSetID,
                sourceItemID: record.sourceItemID,
                phraseHints: canonicalizedChineseList(record.phraseHints),
                characterHints: canonicalizedChineseList(record.characterHints),
                favoritedAt: record.favoritedAt
            )
        })
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

    static var aiCleanedPages: [AICleanedPageRecord] {
        get {
            guard let data = preferences.data(forKey: RadixPreferenceKey.aiCleanedPages) else {
                return []
            }
            return (try? JSONDecoder().decode([AICleanedPageRecord].self, from: data)) ?? []
        }
        set {
            let records = newValue
                .filter { !$0.cleanedChineseText.isEmpty || !$0.sentences.isEmpty }
                .sorted { $0.createdAt > $1.createdAt }
            let data = try? JSONEncoder().encode(records)
            preferences.set(data, forKey: RadixPreferenceKey.aiCleanedPages)
        }
    }

    static func aiCleanedPage(for pageID: UUID) -> AICleanedPageRecord? {
        aiCleanedPages.first { $0.sourcePageID == pageID }
    }

    static func recordAICleanedPage(_ record: AICleanedPageRecord) {
        var records = aiCleanedPages
        records.removeAll { $0.sourcePageID == record.sourcePageID }
        records.append(record)
        aiCleanedPages = records
        recordSentenceExamples(SentenceExampleRecord.fromAICleanedPage(record))
    }

    static func applyImportedAICleanedPages(_ records: [AICleanedPageRecord]?, mode: RestoreMode) {
        switch mode {
        case .additive:
            guard let records, !records.isEmpty else { return }
            for record in records {
                recordAICleanedPage(record)
            }
        case .complete:
            let records = records ?? []
            aiCleanedPages = records
            recordSentenceExamples(records.flatMap(SentenceExampleRecord.fromAICleanedPage(_:)))
        }
    }
}

private final class SentenceExampleRepository: @unchecked Sendable {
    private let databaseURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let lock = NSRecursiveLock()
    private var db: OpaquePointer?
    private var fallbackRecords: [SentenceExampleRecord]?

    init(databaseURL: URL? = nil) {
        self.databaseURL = databaseURL ?? Self.defaultDatabaseURL()
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    func fetchAll(migratingLegacy legacyProvider: () -> [SentenceExampleRecord]) -> [SentenceExampleRecord] {
        lock.lock()
        defer { lock.unlock() }

        if let fallbackRecords {
            if fallbackRecords.isEmpty {
                let legacy = RadixStudyPreferences.canonicalizedSentenceExamples(legacyProvider())
                self.fallbackRecords = legacy
                return legacy
            }
            return fallbackRecords
        }

        do {
            try openIfNeeded()
            let records = try fetchAllUnlocked()
            if !records.isEmpty {
                let canonicalRecords = RadixStudyPreferences.canonicalizedSentenceExamples(records)
                if canonicalRecords != records {
                    try replaceAllUnlocked(canonicalRecords)
                }
                return canonicalRecords
            }
            let legacy = RadixStudyPreferences.canonicalizedSentenceExamples(legacyProvider())
            if !legacy.isEmpty {
                try replaceAllUnlocked(legacy)
            }
            return legacy
        } catch {
            let legacy = RadixStudyPreferences.canonicalizedSentenceExamples(legacyProvider())
            fallbackRecords = legacy
            return legacy
        }
    }

    func query(_ query: SentenceExampleQuery, migratingLegacy legacyProvider: () -> [SentenceExampleRecord]) -> SentenceExampleQueryResult {
        lock.lock()
        defer { lock.unlock() }

        if let fallbackRecords {
            let records = queryFallbackRecords(fallbackRecords, query: query)
            return SentenceExampleQueryResult(records: records.page, totalCount: records.totalCount)
        }

        do {
            try openIfNeeded()
            try migrateLegacyIfNeededUnlocked(legacyProvider)
            let totalCount = try countUnlocked(query)
            let records = try fetchUnlocked(query)
            return SentenceExampleQueryResult(records: records, totalCount: totalCount)
        } catch {
            let legacy = RadixStudyPreferences.canonicalizedSentenceExamples(legacyProvider())
            fallbackRecords = legacy
            let records = queryFallbackRecords(legacy, query: query)
            return SentenceExampleQueryResult(records: records.page, totalCount: records.totalCount)
        }
    }

    func fetch(id: UUID, migratingLegacy legacyProvider: () -> [SentenceExampleRecord]) -> SentenceExampleRecord? {
        lock.lock()
        defer { lock.unlock() }

        if let fallbackRecords {
            return fallbackRecords.first { $0.id == id }
        }

        do {
            try openIfNeeded()
            try migrateLegacyIfNeededUnlocked(legacyProvider)
            return try fetchOneUnlocked(whereSQL: "id = ?", bindings: [id.uuidString])
        } catch {
            let legacy = RadixStudyPreferences.canonicalizedSentenceExamples(legacyProvider())
            fallbackRecords = legacy
            return legacy.first { $0.id == id }
        }
    }

    func fetch(normalizedKey: String, migratingLegacy legacyProvider: () -> [SentenceExampleRecord]) -> SentenceExampleRecord? {
        let key = normalizedKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return nil }
        lock.lock()
        defer { lock.unlock() }

        if let fallbackRecords {
            return fallbackRecords.first { $0.normalizedChineseKey == key }
        }

        do {
            try openIfNeeded()
            try migrateLegacyIfNeededUnlocked(legacyProvider)
            return try fetchOneUnlocked(whereSQL: "normalized_key = ?", bindings: [key])
        } catch {
            let legacy = RadixStudyPreferences.canonicalizedSentenceExamples(legacyProvider())
            fallbackRecords = legacy
            return legacy.first { $0.normalizedChineseKey == key }
        }
    }

    func fetch(
        normalizedKeys: [String],
        migratingLegacy legacyProvider: () -> [SentenceExampleRecord]
    ) -> [String: SentenceExampleRecord] {
        let keys = Array(Set(normalizedKeys.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }))
            .filter { !$0.isEmpty }
        guard !keys.isEmpty else { return [:] }

        lock.lock()
        defer { lock.unlock() }

        if let fallbackRecords {
            return recordsByNormalizedKey(fallbackRecords, matching: keys)
        }

        do {
            try openIfNeeded()
            try migrateLegacyIfNeededUnlocked(legacyProvider)
            return try fetchManyUnlocked(normalizedKeys: keys)
        } catch {
            let legacy = RadixStudyPreferences.canonicalizedSentenceExamples(legacyProvider())
            fallbackRecords = legacy
            return recordsByNormalizedKey(legacy, matching: keys)
        }
    }

    func replaceAll(_ records: [SentenceExampleRecord]) {
        lock.lock()
        defer { lock.unlock() }

        let records = RadixStudyPreferences.canonicalizedSentenceExamples(records)
        if fallbackRecords != nil {
            fallbackRecords = records
            return
        }

        do {
            try openIfNeeded()
            try replaceAllUnlocked(records)
        } catch {
            fallbackRecords = records
        }
    }

    func upsert(_ records: [SentenceExampleRecord]) {
        guard !records.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }

        if let fallbackRecords {
            self.fallbackRecords = RadixStudyPreferences.canonicalizedSentenceExamples(
                fallbackRecords + records
            )
            return
        }

        do {
            try openIfNeeded()
            let records = RadixStudyPreferences.canonicalizedSentenceExamples(records)
            guard sqlite3_exec(db, "BEGIN IMMEDIATE TRANSACTION", nil, nil, nil) == SQLITE_OK else {
                throw sqliteError(code: 3112, message: "Failed to begin sentence upsert")
            }
            do {
                for incoming in records {
                    var merged = incoming
                    if var existing = try fetchOneUnlocked(whereSQL: "normalized_key = ?", bindings: [incoming.normalizedChineseKey]) {
                        existing.merge(incoming)
                        merged = existing
                    }
                    try insertUnlocked([merged])
                }
                guard sqlite3_exec(db, "COMMIT", nil, nil, nil) == SQLITE_OK else {
                    throw sqliteError(code: 3113, message: "Failed to commit sentence upsert")
                }
            } catch {
                sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
                throw error
            }
        } catch {
            fallbackRecords = RadixStudyPreferences.canonicalizedSentenceExamples(records)
        }
    }

    func delete(id: UUID) {
        delete(whereSQL: "id = ?", bindings: [id.uuidString]) { record in
            record.id != id
        }
    }

    func delete(normalizedKey: String) {
        let key = normalizedKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        delete(whereSQL: "normalized_key = ?", bindings: [key]) { record in
            record.normalizedChineseKey != key
        }
    }

    private func delete(
        whereSQL: String,
        bindings: [String],
        fallbackFilter: (SentenceExampleRecord) -> Bool
    ) {
        lock.lock()
        defer { lock.unlock() }

        if let fallbackRecords {
            self.fallbackRecords = fallbackRecords.filter(fallbackFilter)
            return
        }

        do {
            try openIfNeeded()
            let sql = "DELETE FROM sentence_examples WHERE \(whereSQL)"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw sqliteError(code: 3114, message: "Failed to prepare sentence delete")
            }
            defer { sqlite3_finalize(statement) }
            for (index, value) in bindings.enumerated() {
                bind(value, to: Int32(index + 1), in: statement)
            }
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw sqliteError(code: 3115, message: "Failed to delete sentence")
            }
        } catch {
            fallbackRecords = fallbackRecords?.filter(fallbackFilter) ?? []
        }
    }

    private static func defaultDatabaseURL() -> URL {
        let fileManager = FileManager.default
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return baseURL
            .appendingPathComponent("Radix", isDirectory: true)
            .appendingPathComponent("sentence_examples.sqlite")
    }

    private func openIfNeeded() throws {
        guard db == nil else { return }
        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        var openedDB: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &openedDB, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK,
              let openedDB
        else {
            let message = openedDB.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            if let openedDB { sqlite3_close(openedDB) }
            throw NSError(
                domain: "Radix",
                code: 3101,
                userInfo: [NSLocalizedDescriptionKey: "Failed to open sentence database: \(message)"]
            )
        }
        db = openedDB
        try ensureSchema()
    }

    private func ensureSchema() throws {
        guard let db else { return }
        let sql = """
        CREATE TABLE IF NOT EXISTS sentence_examples (
          id TEXT PRIMARY KEY NOT NULL,
          normalized_key TEXT NOT NULL UNIQUE,
          chinese TEXT NOT NULL,
          pinyin TEXT,
          english TEXT,
          search_text TEXT,
          source_text TEXT,
          source_page_ids TEXT,
          has_page_source INTEGER NOT NULL DEFAULT 0,
          has_conversation_practice_source INTEGER NOT NULL DEFAULT 0,
          has_sentence_practice_source INTEGER NOT NULL DEFAULT 0,
          has_ai_cleaned_page_source INTEGER NOT NULL DEFAULT 0,
          is_favorited INTEGER NOT NULL DEFAULT 0,
          is_hidden INTEGER NOT NULL DEFAULT 0,
          quality_score REAL NOT NULL DEFAULT 0,
          created_at REAL NOT NULL,
          updated_at REAL,
          record_json BLOB NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_sentence_examples_created_at
          ON sentence_examples(created_at DESC);
        CREATE INDEX IF NOT EXISTS idx_sentence_examples_favorited
          ON sentence_examples(is_favorited, is_hidden);
        CREATE INDEX IF NOT EXISTS idx_sentence_examples_hidden_rank
          ON sentence_examples(is_hidden, is_favorited, quality_score, created_at);
        """
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw sqliteError(code: 3102, message: "Failed to create sentence schema")
        }
        let existingColumns = try tableColumnsUnlocked()
        var addedColumns = false
        if !existingColumns.contains("search_text") {
            guard sqlite3_exec(db, "ALTER TABLE sentence_examples ADD COLUMN search_text TEXT", nil, nil, nil) == SQLITE_OK else {
                throw sqliteError(code: 3116, message: "Failed to add sentence search column")
            }
            addedColumns = true
        }
        if !existingColumns.contains("source_text") {
            guard sqlite3_exec(db, "ALTER TABLE sentence_examples ADD COLUMN source_text TEXT", nil, nil, nil) == SQLITE_OK else {
                throw sqliteError(code: 3117, message: "Failed to add sentence source column")
            }
            addedColumns = true
        }
        let sourceFlagColumns: [(name: String, sql: String)] = [
            ("source_page_ids", "ALTER TABLE sentence_examples ADD COLUMN source_page_ids TEXT"),
            ("has_page_source", "ALTER TABLE sentence_examples ADD COLUMN has_page_source INTEGER NOT NULL DEFAULT 0"),
            ("has_conversation_practice_source", "ALTER TABLE sentence_examples ADD COLUMN has_conversation_practice_source INTEGER NOT NULL DEFAULT 0"),
            ("has_sentence_practice_source", "ALTER TABLE sentence_examples ADD COLUMN has_sentence_practice_source INTEGER NOT NULL DEFAULT 0"),
            ("has_ai_cleaned_page_source", "ALTER TABLE sentence_examples ADD COLUMN has_ai_cleaned_page_source INTEGER NOT NULL DEFAULT 0")
        ]
        for column in sourceFlagColumns where !existingColumns.contains(column.name) {
            guard sqlite3_exec(db, column.sql, nil, nil, nil) == SQLITE_OK else {
                throw sqliteError(code: 3125, message: "Failed to add sentence source flag column")
            }
            addedColumns = true
        }
        if addedColumns {
            try backfillSearchColumnsUnlocked()
        }
        let indexSQL = """
        CREATE INDEX IF NOT EXISTS idx_sentence_examples_source_text
          ON sentence_examples(source_text);
        CREATE INDEX IF NOT EXISTS idx_sentence_examples_page_source
          ON sentence_examples(has_page_source, is_hidden);
        CREATE INDEX IF NOT EXISTS idx_sentence_examples_practice_source
          ON sentence_examples(has_conversation_practice_source, has_sentence_practice_source, is_hidden);
        CREATE INDEX IF NOT EXISTS idx_sentence_examples_ai_cleaned_source
          ON sentence_examples(has_ai_cleaned_page_source, is_hidden);
        """
        guard sqlite3_exec(db, indexSQL, nil, nil, nil) == SQLITE_OK else {
            throw sqliteError(code: 3123, message: "Failed to index sentence source text")
        }
    }

    private func tableColumnsUnlocked() throws -> Set<String> {
        guard let db else { return [] }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA table_info(sentence_examples)", -1, &statement, nil) == SQLITE_OK else {
            throw sqliteError(code: 3118, message: "Failed to inspect sentence schema")
        }
        defer { sqlite3_finalize(statement) }

        var columns = Set<String>()
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let text = sqlite3_column_text(statement, 1) else { continue }
            columns.insert(String(cString: text))
        }
        return columns
    }

    private func backfillSearchColumnsUnlocked() throws {
        let records = try fetchAllUnlocked()
        guard !records.isEmpty else { return }
        try insertUnlocked(records)
    }

    private func migrateLegacyIfNeededUnlocked(_ legacyProvider: () -> [SentenceExampleRecord]) throws {
        guard try rawCountUnlocked() == 0 else { return }
        let legacy = RadixStudyPreferences.canonicalizedSentenceExamples(legacyProvider())
        guard !legacy.isEmpty else { return }
        try replaceAllUnlocked(legacy)
    }

    private func rawCountUnlocked() throws -> Int {
        guard let db else { return 0 }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM sentence_examples", -1, &statement, nil) == SQLITE_OK else {
            throw sqliteError(code: 3119, message: "Failed to count sentence records")
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int64(statement, 0))
    }

    private func fetchAllUnlocked() throws -> [SentenceExampleRecord] {
        guard let db else { return [] }
        let sql = """
        SELECT record_json
        FROM sentence_examples
        ORDER BY is_favorited DESC, quality_score DESC, created_at DESC, chinese ASC
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw sqliteError(code: 3103, message: "Failed to prepare sentence fetch")
        }
        defer { sqlite3_finalize(statement) }

        var records: [SentenceExampleRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let bytes = sqlite3_column_blob(statement, 0) else { continue }
            let count = Int(sqlite3_column_bytes(statement, 0))
            let data = Data(bytes: bytes, count: count)
            if let record = try? decoder.decode(SentenceExampleRecord.self, from: data) {
                records.append(record)
            }
        }
        return records
    }

    private func fetchUnlocked(_ query: SentenceExampleQuery) throws -> [SentenceExampleRecord] {
        guard let db else { return [] }
        let parts = querySQLParts(for: query)
        var sql = """
        SELECT record_json
        FROM sentence_examples
        \(parts.whereClause)
        ORDER BY is_favorited DESC, quality_score DESC, created_at DESC, chinese ASC
        """
        if let limit = query.limit {
            sql += "\nLIMIT \(max(0, limit)) OFFSET \(max(0, query.offset))"
        }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw sqliteError(code: 3120, message: "Failed to prepare sentence query")
        }
        defer { sqlite3_finalize(statement) }
        bind(parts.bindings, in: statement)

        var records: [SentenceExampleRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let record = decodeRecord(from: statement, column: 0) {
                records.append(record)
            }
        }
        return records
    }

    private func countUnlocked(_ query: SentenceExampleQuery) throws -> Int {
        guard let db else { return 0 }
        let parts = querySQLParts(for: query)
        let sql = """
        SELECT COUNT(*)
        FROM sentence_examples
        \(parts.whereClause)
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw sqliteError(code: 3121, message: "Failed to prepare sentence count")
        }
        defer { sqlite3_finalize(statement) }
        bind(parts.bindings, in: statement)
        guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int64(statement, 0))
    }

    private func fetchOneUnlocked(whereSQL: String, bindings: [String]) throws -> SentenceExampleRecord? {
        guard let db else { return nil }
        let sql = """
        SELECT record_json
        FROM sentence_examples
        WHERE \(whereSQL)
        LIMIT 1
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw sqliteError(code: 3122, message: "Failed to prepare sentence lookup")
        }
        defer { sqlite3_finalize(statement) }
        bind(bindings, in: statement)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return decodeRecord(from: statement, column: 0)
    }

    private func fetchManyUnlocked(normalizedKeys keys: [String]) throws -> [String: SentenceExampleRecord] {
        guard let db, !keys.isEmpty else { return [:] }
        let placeholders = Array(repeating: "?", count: keys.count).joined(separator: ",")
        let sql = """
        SELECT record_json
        FROM sentence_examples
        WHERE normalized_key IN (\(placeholders))
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw sqliteError(code: 3124, message: "Failed to prepare sentence batch lookup")
        }
        defer { sqlite3_finalize(statement) }
        bind(keys, in: statement)

        var records: [String: SentenceExampleRecord] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let record = decodeRecord(from: statement, column: 0) else { continue }
            records[record.normalizedChineseKey] = record
        }
        return records
    }

    private func querySQLParts(for query: SentenceExampleQuery) -> (whereClause: String, bindings: [String]) {
        var clauses: [String] = []
        var bindings: [String] = []

        switch query.scope {
        case .all:
            clauses.append("is_hidden = 0")
        case .favorites:
            clauses.append("is_hidden = 0")
            clauses.append("is_favorited = 1")
        case .pageLinked:
            clauses.append("is_hidden = 0")
            clauses.append("has_page_source = 1")
        case .practice:
            clauses.append("is_hidden = 0")
            clauses.append("(has_conversation_practice_source = 1 OR has_sentence_practice_source = 1)")
        case .page(let pageID, let sourceType):
            clauses.append("is_hidden = 0")
            clauses.append("source_page_ids LIKE ?")
            bindings.append("%\(pageID.uuidString.lowercased())%")
            if let sourceType {
                switch sourceType {
                case .conversationPractice:
                    clauses.append("has_conversation_practice_source = 1")
                case .sentencePractice:
                    clauses.append("has_sentence_practice_source = 1")
                case .aiCleanedPage:
                    clauses.append("has_ai_cleaned_page_source = 1")
                default:
                    clauses.append("source_text LIKE ?")
                    bindings.append("% source_type:\(sourceType.rawValue) %")
                }
            }
        }

        let searchBindings = searchPatterns(for: query.searchText)
        if !searchBindings.isEmpty {
            let searchClauses = searchBindings.map { _ in "search_text LIKE ?" }.joined(separator: " OR ")
            clauses.append("(\(searchClauses))")
            bindings.append(contentsOf: searchBindings)
        }

        return (clauses.isEmpty ? "" : "WHERE \(clauses.joined(separator: " AND "))", bindings)
    }

    private func searchPatterns(for query: String) -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let simplified = ScriptTextConverter.simplified(trimmed).trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = SentenceExampleRecord.normalizedChineseKey(simplified)
        let values = [trimmed, simplified, normalized]
            .map { Self.foldedSearchText($0) }
            .filter { !$0.isEmpty }
        return Array(Set(values)).map { "%\($0)%" }
    }

    private func queryFallbackRecords(
        _ records: [SentenceExampleRecord],
        query: SentenceExampleQuery
    ) -> (page: [SentenceExampleRecord], totalCount: Int) {
        let filtered = SentenceExampleRecord.ranked(records).filter { record in
            switch query.scope {
            case .all:
                break
            case .favorites:
                guard record.isFavorited else { return false }
            case .pageLinked:
                guard record.sources.contains(where: { $0.sourcePageID != nil }) else { return false }
            case .practice:
                guard record.hasSourceType(.conversationPractice) || record.hasSourceType(.sentencePractice) else { return false }
            case .page(let pageID, let sourceType):
                guard record.isLinked(toPageID: pageID) else { return false }
                if let sourceType, !record.hasSourceType(sourceType) {
                    return false
                }
            }
            return RadixStudyPreferences.sentenceExample(record, matchesSearchText: query.searchText)
        }
        let totalCount = filtered.count
        guard let limit = query.limit else { return (filtered, totalCount) }
        let start = min(max(0, query.offset), totalCount)
        let end = min(start + max(0, limit), totalCount)
        return (Array(filtered[start..<end]), totalCount)
    }

    private func recordsByNormalizedKey(
        _ records: [SentenceExampleRecord],
        matching keys: [String]
    ) -> [String: SentenceExampleRecord] {
        let keySet = Set(keys)
        var matches: [String: SentenceExampleRecord] = [:]
        for record in records where keySet.contains(record.normalizedChineseKey) {
            matches[record.normalizedChineseKey] = record
        }
        return matches
    }

    private func replaceAllUnlocked(_ records: [SentenceExampleRecord]) throws {
        guard let db else { return }
        guard sqlite3_exec(db, "BEGIN IMMEDIATE TRANSACTION", nil, nil, nil) == SQLITE_OK else {
            throw sqliteError(code: 3104, message: "Failed to begin sentence replace")
        }

        do {
            guard sqlite3_exec(db, "DELETE FROM sentence_examples", nil, nil, nil) == SQLITE_OK else {
                throw sqliteError(code: 3105, message: "Failed to clear sentence records")
            }
            try insertUnlocked(records)
            guard sqlite3_exec(db, "COMMIT", nil, nil, nil) == SQLITE_OK else {
                throw sqliteError(code: 3106, message: "Failed to commit sentence replace")
            }
        } catch {
            sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
            throw error
        }
    }

    private func insertUnlocked(_ records: [SentenceExampleRecord]) throws {
        guard let db else { return }
        let sql = """
        INSERT OR REPLACE INTO sentence_examples (
          id,
          normalized_key,
          chinese,
          pinyin,
          english,
          search_text,
          source_text,
          source_page_ids,
          has_page_source,
          has_conversation_practice_source,
          has_sentence_practice_source,
          has_ai_cleaned_page_source,
          is_favorited,
          is_hidden,
          quality_score,
          created_at,
          updated_at,
          record_json
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw sqliteError(code: 3107, message: "Failed to prepare sentence insert")
        }
        defer { sqlite3_finalize(statement) }

        for record in records where !record.normalizedChineseKey.isEmpty {
            let data = try encoder.encode(record)
            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)
            bind(record.id.uuidString, to: 1, in: statement)
            bind(record.normalizedChineseKey, to: 2, in: statement)
            bind(record.chinese, to: 3, in: statement)
            bind(record.pinyin, to: 4, in: statement)
            bind(record.english, to: 5, in: statement)
            bind(Self.searchText(for: record), to: 6, in: statement)
            bind(Self.sourceText(for: record), to: 7, in: statement)
            bind(Self.sourcePageIDText(for: record), to: 8, in: statement)
            sqlite3_bind_int(statement, 9, record.sources.contains(where: { $0.sourcePageID != nil }) ? 1 : 0)
            sqlite3_bind_int(statement, 10, record.hasSourceType(.conversationPractice) ? 1 : 0)
            sqlite3_bind_int(statement, 11, record.hasSourceType(.sentencePractice) ? 1 : 0)
            sqlite3_bind_int(statement, 12, record.hasSourceType(.aiCleanedPage) ? 1 : 0)
            sqlite3_bind_int(statement, 13, record.isFavorited ? 1 : 0)
            sqlite3_bind_int(statement, 14, record.isHidden ? 1 : 0)
            sqlite3_bind_double(statement, 15, record.qualityScore)
            sqlite3_bind_double(statement, 16, record.createdAt.timeIntervalSince1970)
            if let lastUsedAt = record.lastUsedAt {
                sqlite3_bind_double(statement, 17, lastUsedAt.timeIntervalSince1970)
            } else {
                sqlite3_bind_null(statement, 17)
            }
            _ = data.withUnsafeBytes { buffer in
                sqlite3_bind_blob(
                    statement,
                    18,
                    buffer.baseAddress,
                    Int32(data.count),
                    SQLITE_TRANSIENT_SENTENCE_EXAMPLES
                )
            }

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw sqliteError(code: 3108, message: "Failed to insert sentence record")
            }
        }
    }

    private func decodeRecord(from statement: OpaquePointer?, column: Int32) -> SentenceExampleRecord? {
        guard let bytes = sqlite3_column_blob(statement, column) else { return nil }
        let count = Int(sqlite3_column_bytes(statement, column))
        let data = Data(bytes: bytes, count: count)
        return try? decoder.decode(SentenceExampleRecord.self, from: data)
    }

    private func bind(_ values: [String], in statement: OpaquePointer?) {
        for (index, value) in values.enumerated() {
            bind(value, to: Int32(index + 1), in: statement)
        }
    }

    private static func searchText(for record: SentenceExampleRecord) -> String {
        let values = [
            record.chinese,
            ScriptTextConverter.simplified(record.chinese),
            record.normalizedChineseKey,
            record.pinyin ?? "",
            record.english ?? "",
            record.targetPhrases.joined(separator: " "),
            record.detectedPhrases.joined(separator: " "),
            record.targetPhrases.map { SentenceExampleRecord.normalizedChineseKey($0) }.joined(separator: " "),
            record.detectedPhrases.map { SentenceExampleRecord.normalizedChineseKey($0) }.joined(separator: " "),
            record.targetCharacters.joined(separator: " "),
            record.detectedCharacters.joined(separator: " "),
            record.sources.compactMap(\.sourceTitle).joined(separator: " "),
            record.tags.joined(separator: " ")
        ]
        return foldedSearchText(values.joined(separator: " "))
    }

    private static func sourceText(for record: SentenceExampleRecord) -> String {
        var tokens: [String] = []
        for source in record.sources {
            tokens.append("source_type:\(source.sourceType.rawValue)")
            if let sourcePageID = source.sourcePageID {
                tokens.append("source_page")
                tokens.append("page:\(sourcePageID.uuidString.lowercased())")
            }
            if let practicePackID = source.practicePackID {
                tokens.append("pack:\(practicePackID)")
            }
        }
        return " \(tokens.joined(separator: " ")) "
    }

    private static func sourcePageIDText(for record: SentenceExampleRecord) -> String {
        let ids = record.sources
            .compactMap(\.sourcePageID)
            .map { $0.uuidString.lowercased() }
        return " \(Array(Set(ids)).sorted().joined(separator: " ")) "
    }

    private static func foldedSearchText(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }

    private func bind(_ value: String?, to index: Int32, in statement: OpaquePointer?) {
        guard let value, !value.isEmpty else {
            sqlite3_bind_null(statement, index)
            return
        }
        sqlite3_bind_text(statement, index, (value as NSString).utf8String, -1, SQLITE_TRANSIENT_SENTENCE_EXAMPLES)
    }

    private func sqliteError(code: Int, message: String) -> NSError {
        let sqliteMessage = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
        return NSError(
            domain: "Radix",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: "\(message): \(sqliteMessage)"]
        )
    }
}
