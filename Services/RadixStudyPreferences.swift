import Foundation
import SQLite3

private let SQLITE_TRANSIENT_SENTENCE_EXAMPLES = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

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
            return (try? JSONDecoder().decode([FavoriteSentenceRecord].self, from: data)) ?? []
        }
        set {
            let data = try? JSONEncoder().encode(FavoriteSentenceRecord.deduplicated(newValue))
            preferences.set(data, forKey: RadixPreferenceKey.favoriteSentences)
        }
    }

    static var sentenceExamples: [SentenceExampleRecord] {
        get {
            sentenceExampleRepository.fetchAll(migratingLegacy: legacySentenceExamplesFromPreferences)
        }
        set {
            let records = SentenceExampleRecord.upserting(newValue, into: [])
            sentenceExampleRepository.replaceAll(records)
        }
    }

    static var currentSentenceExamples: [SentenceExampleRecord] {
        migrateLegacyFavoriteSentencesIntoSentenceExamples()
        return sentenceExamples
    }

    static func recordSentenceExamples(_ records: [SentenceExampleRecord]) {
        guard !records.isEmpty else { return }
        sentenceExampleRepository.upsert(records)
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

    private static func legacySentenceExamplesFromPreferences() -> [SentenceExampleRecord] {
        guard let data = preferences.data(forKey: RadixPreferenceKey.sentenceExamples) else {
            return []
        }
        return (try? JSONDecoder().decode([SentenceExampleRecord].self, from: data)) ?? []
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
                let legacy = SentenceExampleRecord.upserting(legacyProvider(), into: [])
                self.fallbackRecords = legacy
                return legacy
            }
            return fallbackRecords
        }

        do {
            try openIfNeeded()
            let records = try fetchAllUnlocked()
            if !records.isEmpty {
                return records
            }
            let legacy = SentenceExampleRecord.upserting(legacyProvider(), into: [])
            if !legacy.isEmpty {
                try replaceAllUnlocked(legacy)
            }
            return legacy
        } catch {
            let legacy = SentenceExampleRecord.upserting(legacyProvider(), into: [])
            fallbackRecords = legacy
            return legacy
        }
    }

    func replaceAll(_ records: [SentenceExampleRecord]) {
        lock.lock()
        defer { lock.unlock() }

        let records = SentenceExampleRecord.upserting(records, into: [])
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
            self.fallbackRecords = SentenceExampleRecord.upserting(records, into: fallbackRecords)
            return
        }

        do {
            try openIfNeeded()
            let merged = SentenceExampleRecord.upserting(records, into: try fetchAllUnlocked())
            try replaceAllUnlocked(merged)
        } catch {
            fallbackRecords = SentenceExampleRecord.upserting(records, into: [])
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
        """
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw sqliteError(code: 3102, message: "Failed to create sentence schema")
        }
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
          is_favorited,
          is_hidden,
          quality_score,
          created_at,
          updated_at,
          record_json
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
            sqlite3_bind_int(statement, 6, record.isFavorited ? 1 : 0)
            sqlite3_bind_int(statement, 7, record.isHidden ? 1 : 0)
            sqlite3_bind_double(statement, 8, record.qualityScore)
            sqlite3_bind_double(statement, 9, record.createdAt.timeIntervalSince1970)
            if let lastUsedAt = record.lastUsedAt {
                sqlite3_bind_double(statement, 10, lastUsedAt.timeIntervalSince1970)
            } else {
                sqlite3_bind_null(statement, 10)
            }
            _ = data.withUnsafeBytes { buffer in
                sqlite3_bind_blob(
                    statement,
                    11,
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
