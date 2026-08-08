import Foundation
import SQLite3

/*
 PHRASE REPOSITORY (Dual-DB)
 ===========================
 - Base DB (phrases.db in app bundle): read-only, never mutated.
 - Add DB (phrases_add.db in the project folder when available, otherwise Documents):
   all user-created/edited phrases.
 - Queries return the union, with Add DB overriding on word collisions.
*/

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private struct PhraseSequentialSegment {
    let text: String
    let start: Int
    let length: Int
}

private struct PhrasePartMatchRank: Comparable {
    let category: Int
    let segmentLength: Int
    let start: Int
    let phraseLength: Int

    static func < (lhs: PhrasePartMatchRank, rhs: PhrasePartMatchRank) -> Bool {
        if lhs.category != rhs.category { return lhs.category < rhs.category }
        if lhs.segmentLength != rhs.segmentLength { return lhs.segmentLength < rhs.segmentLength }
        if lhs.start != rhs.start { return lhs.start < rhs.start }
        return lhs.phraseLength < rhs.phraseLength
    }
}

final class PhraseRepository {
    private let addPhraseColumns = "word, pinyin, meanings, added_at, notes, review_status, last_reviewed_at"
    private let activeAddPhraseClause = "COALESCE(review_status, '') != 'removed'"
    private let visibleAddPhraseClause = "COALESCE(review_status, '') NOT IN ('hidden', 'removed')"
    private var baseDb: OpaquePointer?
    private var addDb: OpaquePointer?
    private var pinyinSearchIndex = PhrasePinyinSearchIndex()
    private var mergedPhrasesCache: [PhraseItem]?
    private var mergedPhraseLookup: [String: PhraseItem] = [:]
    private let addDBLocationManager = PhraseAddDatabaseLocationManager()

    private var queryRunner: PhraseQueryRunner {
        PhraseQueryRunner(baseDb: baseDb, addDb: addDb)
    }

    deinit { close() }

    // MARK: - Lifecycle

    func openFromBundle() throws {
        let fm = FileManager.default
        guard let bundleURL = Bundle.main.url(forResource: "phrases", withExtension: "db") else {
            throw NSError(domain: "Radix", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing phrases.db in app bundle."])
        }
        // Base DB (read-only)
        if sqlite3_open_v2(bundleURL.path, &baseDb, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
            let err = String(cString: sqlite3_errmsg(baseDb))
            close()
            throw NSError(domain: "Radix", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to open base phrases.db: \(err)"])
        }
        // Add DB (writable, created if missing)
        let addURL = try resolvedActiveAddDBURL(fileManager: fm)
        if sqlite3_open_v2(addURL.path, &addDb, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) != SQLITE_OK {
            let err = String(cString: sqlite3_errmsg(addDb))
            close()
            throw NSError(domain: "Radix", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to open phrases_add.db: \(err)"])
        }
        try ensureAddTable()
    }

    func openForTesting() throws {
        let addURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString).appendingPathExtension("db")
        if sqlite3_open_v2(addURL.path, &addDb, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) != SQLITE_OK {
            throw NSError(domain: "Radix", code: 8, userInfo: [NSLocalizedDescriptionKey: "Failed to open test db"])
        }
        try ensureAddTable()
        baseDb = nil
    }

    func openMasterBundleOnly() throws {
        guard let bundleURL = Bundle.main.url(forResource: "phrases", withExtension: "db") else {
            throw NSError(domain: "Radix", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing phrases.db in app bundle."])
        }
        if sqlite3_open_v2(bundleURL.path, &baseDb, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
            throw NSError(domain: "Radix", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to open bundle db"])
        }
    }

    func close() {
        if let baseDb { sqlite3_close(baseDb) }
        if let addDb { sqlite3_close(addDb) }
        baseDb = nil
        addDb = nil
        invalidateReadCaches()
        addDBLocationManager.stopAccessingActiveSecurityScope()
    }

    // MARK: - Writes (Add DB only)

    @discardableResult
    func createAddDatabaseSnapshot(reason: String) throws -> RadixDatabaseSnapshotMetadata {
        guard let addDb else {
            throw NSError(domain: "Radix", code: 120, userInfo: [NSLocalizedDescriptionKey: "Add phrases database is not open"])
        }
        let date = Date()
        let destinationURL = try RadixDatabaseSnapshotStore.destinationURL(kind: .addedPhrases, date: date)
        try backup(database: addDb, to: destinationURL)
        return RadixDatabaseSnapshotStore.record(kind: .addedPhrases, reason: reason, at: destinationURL, date: date)
    }

    func exportAddDatabaseData() throws -> Data {
        guard let addDb else {
            throw NSError(domain: "Radix", code: 120, userInfo: [NSLocalizedDescriptionKey: "Add phrases database is not open"])
        }
        let exportURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("radix_added_phrases_export_\(UUID().uuidString)")
            .appendingPathExtension("sqlite")
        defer { try? FileManager.default.removeItem(at: exportURL) }
        try backup(database: addDb, to: exportURL)
        return try Data(contentsOf: exportURL)
    }

    func importAddDatabase(from sourceURL: URL, mode: RestoreMode) throws -> Int {
        let sourcePhrases = try Self.addedPhrases(in: sourceURL)
        switch mode {
        case .additive:
            try addPhrasesAdditively(sourcePhrases)
        case .complete:
            try restoreAddDatabase(from: sourceURL)
        }
        return sourcePhrases.count
    }

    func restoreAddDatabaseSnapshot(_ snapshot: RadixDatabaseSnapshotMetadata) throws {
        guard snapshot.kind == .addedPhrases else {
            throw NSError(domain: "Radix", code: 121, userInfo: [NSLocalizedDescriptionKey: "This snapshot is not an added-phrases database snapshot."])
        }
        guard let addDb else {
            throw NSError(domain: "Radix", code: 120, userInfo: [NSLocalizedDescriptionKey: "Add phrases database is not open"])
        }
        let sourceURL = URL(fileURLWithPath: snapshot.path)
        guard FileManager.default.isReadableFile(atPath: sourceURL.path) else {
            throw NSError(domain: "Radix", code: 122, userInfo: [NSLocalizedDescriptionKey: "Added-phrases snapshot is not readable."])
        }
        var sourceDB: OpaquePointer?
        guard sqlite3_open_v2(sourceURL.path, &sourceDB, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let sourceDB
        else {
            let message = sourceDB.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            if let sourceDB { sqlite3_close(sourceDB) }
            throw NSError(domain: "Radix", code: 123, userInfo: [NSLocalizedDescriptionKey: "Failed to open added-phrases snapshot: \(message)"])
        }
        defer { sqlite3_close(sourceDB) }

        guard let backup = sqlite3_backup_init(addDb, "main", sourceDB, "main") else {
            throw queryRunner.phraseWriteError(code: 124, prefix: "Added-phrases restore failed", db: addDb, currentAddDBPath: currentAddDBPath)
        }
        let stepResult = sqlite3_backup_step(backup, -1)
        let finishResult = sqlite3_backup_finish(backup)
        guard stepResult == SQLITE_DONE, finishResult == SQLITE_OK else {
            throw queryRunner.phraseWriteError(code: 125, prefix: "Added-phrases restore failed", db: addDb, currentAddDBPath: currentAddDBPath)
        }
        try ensureAddTable()
        try addDBLocationManager.syncWorkingAddDBToCustomSourceIfNeeded()
        invalidateReadCaches()
    }

    func addOrUpdatePhrase(word: String, pinyin: String, meanings: String, notes: String? = nil) throws {
        guard let addDb else {
            throw NSError(domain: "Radix", code: 12, userInfo: [NSLocalizedDescriptionKey: "Add phrases database is not open"])
        }
        let updateSQL = notes == nil
            ? "UPDATE phrases SET pinyin = ?, meanings = ? WHERE word = ?"
            : "UPDATE phrases SET pinyin = ?, meanings = ?, notes = ? WHERE word = ?"
        var updateStmt: OpaquePointer?
        if sqlite3_prepare_v2(addDb, updateSQL, -1, &updateStmt, nil) != SQLITE_OK {
            throw queryRunner.phraseWriteError(code: 4, prefix: "Prepare failed", db: addDb, currentAddDBPath: currentAddDBPath)
        }
        defer { sqlite3_finalize(updateStmt) }
        sqlite3_bind_text(updateStmt, 1, (pinyin as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(updateStmt, 2, (meanings as NSString).utf8String, -1, SQLITE_TRANSIENT)
        if let notes {
            sqlite3_bind_text(updateStmt, 3, (notes as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(updateStmt, 4, (word as NSString).utf8String, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_text(updateStmt, 3, (word as NSString).utf8String, -1, SQLITE_TRANSIENT)
        }
        if sqlite3_step(updateStmt) != SQLITE_DONE {
            throw queryRunner.phraseWriteError(code: 5, prefix: "Update failed", db: addDb, currentAddDBPath: currentAddDBPath)
        }

        if sqlite3_changes(addDb) == 0 {
            let insertSQL = "INSERT INTO phrases (word, pinyin, meanings, notes, added_at) VALUES (?, ?, ?, ?, ?)"
            var insertStmt: OpaquePointer?
            if sqlite3_prepare_v2(addDb, insertSQL, -1, &insertStmt, nil) != SQLITE_OK {
                throw queryRunner.phraseWriteError(code: 4, prefix: "Prepare failed", db: addDb, currentAddDBPath: currentAddDBPath)
            }
            defer { sqlite3_finalize(insertStmt) }
            sqlite3_bind_text(insertStmt, 1, (word as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(insertStmt, 2, (pinyin as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(insertStmt, 3, (meanings as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(insertStmt, 4, ((notes ?? "") as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(insertStmt, 5, Date().timeIntervalSince1970)
            if sqlite3_step(insertStmt) != SQLITE_DONE {
                throw queryRunner.phraseWriteError(code: 5, prefix: "Insert failed", db: addDb, currentAddDBPath: currentAddDBPath)
            }
        }
        try addDBLocationManager.syncWorkingAddDBToCustomSourceIfNeeded()
        invalidateReadCaches()
    }

    func updateReviewStatus(for word: String, status: PhraseReviewStatus?) throws {
        guard let addDb else {
            throw NSError(domain: "Radix", code: 12, userInfo: [NSLocalizedDescriptionKey: "Add phrases database is not open"])
        }
        let sql = "UPDATE phrases SET review_status = ?, last_reviewed_at = ? WHERE word = ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(addDb, sql, -1, &stmt, nil) != SQLITE_OK {
            throw queryRunner.phraseWriteError(code: 4, prefix: "Prepare failed", db: addDb, currentAddDBPath: currentAddDBPath)
        }
        defer { sqlite3_finalize(stmt) }
        if let status {
            sqlite3_bind_text(stmt, 1, (status.rawValue as NSString).utf8String, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 1)
        }
        sqlite3_bind_double(stmt, 2, Date().timeIntervalSince1970)
        sqlite3_bind_text(stmt, 3, (word as NSString).utf8String, -1, SQLITE_TRANSIENT)
        if sqlite3_step(stmt) != SQLITE_DONE {
            throw queryRunner.phraseWriteError(code: 5, prefix: "Review status update failed", db: addDb, currentAddDBPath: currentAddDBPath)
        }
        try addDBLocationManager.syncWorkingAddDBToCustomSourceIfNeeded()
        invalidateReadCaches()
    }

    func deletePhrase(word: String) throws {
        guard let addDb else {
            throw NSError(domain: "Radix", code: 12, userInfo: [NSLocalizedDescriptionKey: "Add phrases database is not open"])
        }
        let sql = "DELETE FROM phrases WHERE word = ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(addDb, sql, -1, &stmt, nil) != SQLITE_OK {
            throw NSError(domain: "Radix", code: 6, userInfo: [NSLocalizedDescriptionKey: "Prepare failed: \(String(cString: sqlite3_errmsg(addDb)))"])
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (word as NSString).utf8String, -1, SQLITE_TRANSIENT)
        if sqlite3_step(stmt) != SQLITE_DONE {
            throw NSError(domain: "Radix", code: 7, userInfo: [NSLocalizedDescriptionKey: "Step failed: \(String(cString: sqlite3_errmsg(addDb)))"])
        }
        if sqlite3_changes(addDb) == 0 {
            throw NSError(domain: "Radix", code: 13, userInfo: [NSLocalizedDescriptionKey: "Phrase not found in add DB"])
        }
        try addDBLocationManager.syncWorkingAddDBToCustomSourceIfNeeded()
        invalidateReadCaches()
    }

    // MARK: - Reads

    func fetchAllPhrases() -> [PhraseItem] {
        if let mergedPhrasesCache { return mergedPhrasesCache }
        let merged = queryRunner.mergedQueries(
            baseSQL: "SELECT word, pinyin, meanings FROM phrases",
            addSQL: "SELECT \(addPhraseColumns) FROM phrases WHERE \(visibleAddPhraseClause)"
        )
        mergedPhrasesCache = merged
        mergedPhraseLookup = Dictionary(uniqueKeysWithValues: merged.map { ($0.word, $0) })
        return merged
    }

    func fetchAddedPhrases() -> [PhraseItem] {
        queryRunner.runQuery(db: addDb, sql: "SELECT \(addPhraseColumns) FROM phrases ORDER BY added_at DESC")
    }

    func addedPhraseCount() -> Int {
        guard let addDb else { return 0 }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(addDb, "SELECT COUNT(*) FROM phrases WHERE \(visibleAddPhraseClause)", -1, &stmt, nil) == SQLITE_OK else {
            return 0
        }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    func addedPhraseDatabaseByteCount() -> Int64 {
        (((try? FileManager.default.attributesOfItem(atPath: currentAddDBURL.path)[.size]) as? NSNumber)?.int64Value) ?? 0
    }

    func fetchPhrase(for word: String) -> PhraseItem? {
        fetchPhrase(for: word, includeHidden: false)
    }

    func fetchPhrase(for word: String, includeHidden: Bool) -> PhraseItem? {
        if let cached = mergedPhraseLookup[word] {
            return cached
        }
        if mergedPhrasesCache != nil, !includeHidden {
            return nil
        }
        let addVisibilityClause = includeHidden ? activeAddPhraseClause : visibleAddPhraseClause
        let addSQL = "SELECT \(addPhraseColumns) FROM phrases WHERE word = ? AND \(addVisibilityClause) LIMIT 1"
        let baseSQL = "SELECT word, pinyin, meanings FROM phrases WHERE word = ? LIMIT 1"
        let binder: (OpaquePointer?) -> Void = { stmt in
            sqlite3_bind_text(stmt, 1, (word as NSString).utf8String, -1, SQLITE_TRANSIENT)
        }
        // Check add DB first, then base
        let fromAdd = queryRunner.runQuery(db: addDb, sql: addSQL, binder: binder).first
        if let p = fromAdd { return p }
        return queryRunner.runQuery(db: baseDb, sql: baseSQL, binder: binder).first
    }

    func fetchAddedPhrase(for word: String) -> PhraseItem? {
        let addSQL = "SELECT \(addPhraseColumns) FROM phrases WHERE word = ? LIMIT 1"
        let binder: (OpaquePointer?) -> Void = { stmt in
            sqlite3_bind_text(stmt, 1, (word as NSString).utf8String, -1, SQLITE_TRANSIENT)
        }
        return queryRunner.runQuery(db: addDb, sql: addSQL, binder: binder).first
    }

    func fetchBasePhrase(for word: String) -> PhraseItem? {
        let baseSQL = "SELECT word, pinyin, meanings FROM phrases WHERE word = ? LIMIT 1"
        let binder: (OpaquePointer?) -> Void = { stmt in
            sqlite3_bind_text(stmt, 1, (word as NSString).utf8String, -1, SQLITE_TRANSIENT)
        }
        return queryRunner.runQuery(db: baseDb, sql: baseSQL, binder: binder).first
    }

    func fetchPhrases(matching words: Set<String>, includeHidden: Bool = false) -> [PhraseItem] {
        guard !words.isEmpty else { return [] }
        var phraseByWord: [String: PhraseItem] = [:]
        let addVisibilityClause = includeHidden ? activeAddPhraseClause : visibleAddPhraseClause

        for chunk in phraseQueryChunks(from: words) {
            let placeholders = Array(repeating: "?", count: chunk.count).joined(separator: ",")
            let binder: (OpaquePointer?) -> Void = { stmt in
                guard let stmt else { return }
                for (index, word) in chunk.enumerated() {
                    sqlite3_bind_text(stmt, Int32(index + 1), (word as NSString).utf8String, -1, SQLITE_TRANSIENT)
                }
            }
            let baseSQL = "SELECT word, pinyin, meanings FROM phrases WHERE word IN (\(placeholders))"
            let addSQL = "SELECT \(addPhraseColumns) FROM phrases WHERE word IN (\(placeholders)) AND \(addVisibilityClause)"

            for phrase in queryRunner.runQuery(db: baseDb, sql: baseSQL, binder: binder) {
                phraseByWord[phrase.word] = phrase
            }
            for phrase in queryRunner.runQuery(db: addDb, sql: addSQL, binder: binder) {
                phraseByWord[phrase.word] = phrase
            }
        }

        return words.compactMap { phraseByWord[$0] }
    }

    private func phraseQueryChunks(from words: Set<String>, size: Int = 400) -> [[String]] {
        let orderedWords = Array(words)
        return stride(from: 0, to: orderedWords.count, by: size).map { start in
            Array(orderedWords[start..<min(start + size, orderedWords.count)])
        }
    }

    func phraseWordSet() -> Set<String> {
        Set(fetchAllPhrases().map(\.word))
    }

    func activeSentencePhraseLinkWords() -> [String] {
        var seen = Set<String>()
        return fetchAllPhrases().compactMap { phrase in
            let word = sentencePhraseLinkStorageWord(phrase.word)
            guard word.count >= 2, seen.insert(word).inserted else { return nil }
            return word
        }
    }

    func existingWords(in words: Set<String>) -> Set<String> {
        guard !words.isEmpty else { return [] }
        let activeLookup = phraseLookupCache()
        let addedLookup = Set(fetchAddedPhrases().map(\.word))
        return Set(words.filter { activeLookup[$0] != nil || addedLookup.contains($0) })
    }

    /// Additive import — inserts missing phrases and safely merges restored notes into existing overlay rows.
    func addPhrasesAdditively(_ phrases: [PhraseItem]) throws {
        guard let addDb else { return }
        guard !phrases.isEmpty else { return }
        if sqlite3_exec(addDb, "BEGIN IMMEDIATE TRANSACTION", nil, nil, nil) != SQLITE_OK {
            throw queryRunner.phraseWriteError(code: 19, prefix: "Begin amalgamation failed", db: addDb, currentAddDBPath: currentAddDBPath)
        }
        var shouldRollback = true
        defer {
            if shouldRollback {
                sqlite3_exec(addDb, "ROLLBACK", nil, nil, nil)
            }
        }

        let sql = "INSERT OR IGNORE INTO phrases (word, pinyin, meanings, notes, added_at, review_status, last_reviewed_at) VALUES (?, ?, ?, ?, ?, ?, ?)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(addDb, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw queryRunner.phraseWriteError(code: 20, prefix: "Prepare amalgamation failed", db: addDb, currentAddDBPath: currentAddDBPath)
        }
        defer { sqlite3_finalize(stmt) }
        let mergeSQL = """
            UPDATE phrases
            SET notes =
                CASE
                    WHEN ? = '' THEN COALESCE(notes, '')
                    WHEN notes IS NULL OR TRIM(notes) = '' THEN ?
                    WHEN notes = ? OR notes LIKE ? THEN notes
                    ELSE notes || char(10) || char(10) || ?
                END
            WHERE word = ?
        """
        var mergeStmt: OpaquePointer?
        guard sqlite3_prepare_v2(addDb, mergeSQL, -1, &mergeStmt, nil) == SQLITE_OK else {
            throw queryRunner.phraseWriteError(code: 21, prefix: "Prepare notes merge failed", db: addDb, currentAddDBPath: currentAddDBPath)
        }
        defer { sqlite3_finalize(mergeStmt) }
        let now = Date().timeIntervalSince1970
        for p in phrases {
            let restoredNotes = p.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            sqlite3_reset(stmt)
            sqlite3_clear_bindings(stmt)
            sqlite3_bind_text(stmt, 1, (p.word as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, (p.pinyin as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, (p.meanings as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 4, (p.notes as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(stmt, 5, p.addedAt?.timeIntervalSince1970 ?? now)
            if let reviewStatus = p.reviewStatus {
                sqlite3_bind_text(stmt, 6, (reviewStatus.rawValue as NSString).utf8String, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 6)
            }
            if let lastReviewedAt = p.lastReviewedAt {
                sqlite3_bind_double(stmt, 7, lastReviewedAt.timeIntervalSince1970)
            } else {
                sqlite3_bind_null(stmt, 7)
            }
            if sqlite3_step(stmt) != SQLITE_DONE {
                throw queryRunner.phraseWriteError(code: 22, prefix: "Amalgamation insert failed for \(p.word)", db: addDb, currentAddDBPath: currentAddDBPath)
            }

            sqlite3_reset(mergeStmt)
            sqlite3_clear_bindings(mergeStmt)
            sqlite3_bind_text(mergeStmt, 1, (restoredNotes as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(mergeStmt, 2, (restoredNotes as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(mergeStmt, 3, (restoredNotes as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(mergeStmt, 4, ("%\(restoredNotes)%" as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(mergeStmt, 5, (restoredNotes as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(mergeStmt, 6, (p.word as NSString).utf8String, -1, SQLITE_TRANSIENT)
            if sqlite3_step(mergeStmt) != SQLITE_DONE {
                throw queryRunner.phraseWriteError(code: 23, prefix: "Notes merge failed for \(p.word)", db: addDb, currentAddDBPath: currentAddDBPath)
            }
        }
        if sqlite3_exec(addDb, "COMMIT", nil, nil, nil) != SQLITE_OK {
            throw queryRunner.phraseWriteError(code: 24, prefix: "Commit amalgamation failed", db: addDb, currentAddDBPath: currentAddDBPath)
        }
        shouldRollback = false
        try addDBLocationManager.syncWorkingAddDBToCustomSourceIfNeeded()
        invalidateReadCaches()
    }

    /// Complete import — deletes all existing rows then inserts the backup phrases in full.
    func replaceAllPhrases(_ phrases: [PhraseItem]) throws {
        guard let addDb else { return }
        if sqlite3_exec(addDb, "BEGIN IMMEDIATE TRANSACTION", nil, nil, nil) != SQLITE_OK {
            throw queryRunner.phraseWriteError(code: 14, prefix: "Begin restore failed", db: addDb, currentAddDBPath: currentAddDBPath)
        }
        var shouldRollback = true
        defer {
            if shouldRollback {
                sqlite3_exec(addDb, "ROLLBACK", nil, nil, nil)
            }
        }

        if sqlite3_exec(addDb, "DELETE FROM phrases", nil, nil, nil) != SQLITE_OK {
            throw queryRunner.phraseWriteError(code: 15, prefix: "Delete-all failed", db: addDb, currentAddDBPath: currentAddDBPath)
        }
        let sql = "INSERT INTO phrases (word, pinyin, meanings, notes, added_at, review_status, last_reviewed_at) VALUES (?, ?, ?, ?, ?, ?, ?)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(addDb, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw queryRunner.phraseWriteError(code: 16, prefix: "Prepare failed", db: addDb, currentAddDBPath: currentAddDBPath)
        }
        defer { sqlite3_finalize(stmt) }
        let now = Date().timeIntervalSince1970
        for p in phrases {
            sqlite3_reset(stmt)
            sqlite3_clear_bindings(stmt)
            sqlite3_bind_text(stmt, 1, (p.word as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, (p.pinyin as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, (p.meanings as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 4, (p.notes as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(stmt, 5, p.addedAt?.timeIntervalSince1970 ?? now)
            if let reviewStatus = p.reviewStatus {
                sqlite3_bind_text(stmt, 6, (reviewStatus.rawValue as NSString).utf8String, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 6)
            }
            if let lastReviewedAt = p.lastReviewedAt {
                sqlite3_bind_double(stmt, 7, lastReviewedAt.timeIntervalSince1970)
            } else {
                sqlite3_bind_null(stmt, 7)
            }
            if sqlite3_step(stmt) != SQLITE_DONE {
                throw queryRunner.phraseWriteError(code: 17, prefix: "Insert failed for \(p.word)", db: addDb, currentAddDBPath: currentAddDBPath)
            }
        }
        if sqlite3_exec(addDb, "COMMIT", nil, nil, nil) != SQLITE_OK {
            throw queryRunner.phraseWriteError(code: 18, prefix: "Commit restore failed", db: addDb, currentAddDBPath: currentAddDBPath)
        }
        shouldRollback = false
        try addDBLocationManager.syncWorkingAddDBToCustomSourceIfNeeded()
        invalidateReadCaches()
    }

    func addedPhrases(containing character: String, limit: Int = 240) -> [PhraseItem] {
        let sql = "SELECT \(addPhraseColumns) FROM phrases WHERE word LIKE ? AND \(visibleAddPhraseClause) LIMIT ?"
        let binder: (OpaquePointer?) -> Void = { stmt in
            guard let stmt else { return }
            sqlite3_bind_text(stmt, 1, ("%\(character)%" as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt, 2, Int32(limit))
        }
        return queryRunner.runQuery(db: addDb, sql: sql, binder: binder).filter {
            $0.word.contains(character) && (2...4).contains($0.word.count)
        }
    }
    
    var currentAddDBPath: String {
        addDBLocationManager.currentDisplayPath
    }

    var currentAddDBURL: URL {
        addDBLocationManager.currentLocalURL
    }

    func phrases(containing character: String, length: Int, limit: Int? = nil, includeHidden: Bool = false) -> [PhraseItem] {
        let baseSQL = "SELECT word, pinyin, meanings FROM phrases WHERE word LIKE ? AND length(word) = ?" + (limit == nil ? "" : " LIMIT ?")
        let addVisibilityClause = includeHidden ? activeAddPhraseClause : visibleAddPhraseClause
        let addSQL = "SELECT \(addPhraseColumns) FROM phrases WHERE word LIKE ? AND length(word) = ? AND \(addVisibilityClause)" + (limit == nil ? "" : " LIMIT ?")
        let bind: (OpaquePointer?) -> Void = { stmt in
            guard let stmt else { return }
            sqlite3_bind_text(stmt, 1, ("%\(character)%" as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt, 2, Int32(length))
            if let limit {
                sqlite3_bind_int(stmt, 3, Int32(limit))
            }
        }
        let results = queryRunner.mergedQueries(baseSQL: baseSQL, addSQL: addSQL, binder: bind)
        return results.filter { $0.word.contains(character) }
    }

    func phrases(containingAll characters: [String], length: Int?, limit: Int? = nil) -> [PhraseItem] {
        let required = Array(Set(characters.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }))
        guard !required.isEmpty else { return [] }

        var results = fetchAllPhrases().filter { phrase in
            required.allSatisfy { phrase.word.contains($0) }
        }

        if let length {
            results = results.filter { $0.word.count == length }
        }

        results.sort {
            if $0.word.count != $1.word.count { return $0.word.count < $1.word.count }
            return $0.word < $1.word
        }

        if let limit {
            return Array(results.prefix(limit))
        }
        return results
    }

    func phrases(matchingPartsOf text: String, length: Int?, limit: Int? = nil) -> [PhraseItem] {
        let characters = text.map(String.init).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard characters.count > 1 else { return [] }
        let fullText = characters.joined()
        let allCharacterMatches = Set(characters)
        let segments = sequentialSegments(in: characters)

        var ranked: [(phrase: PhraseItem, rank: PhrasePartMatchRank)] = []
        for phrase in fetchAllPhrases() {
            if let length, phrase.word.count != length {
                continue
            }
            guard phrase.word != fullText else {
                ranked.append((phrase, PhrasePartMatchRank(category: 0, segmentLength: 0, start: 0, phraseLength: phrase.word.count)))
                continue
            }
            if let bestSegment = bestSequentialSegmentMatch(in: phrase.word, segments: segments) {
                ranked.append((phrase, PhrasePartMatchRank(category: 1, segmentLength: bestSegment.length, start: bestSegment.start, phraseLength: phrase.word.count)))
            } else if allCharacterMatches.allSatisfy({ phrase.word.contains($0) }) {
                ranked.append((phrase, PhrasePartMatchRank(category: 2, segmentLength: phrase.word.count, start: characters.count, phraseLength: phrase.word.count)))
            }
        }

        ranked.sort {
            if $0.rank != $1.rank { return $0.rank < $1.rank }
            return $0.phrase.word < $1.phrase.word
        }

        let results = ranked.map(\.phrase)
        if let limit {
            return Array(results.prefix(limit))
        }
        return results
    }

    private func sequentialSegments(in characters: [String]) -> [PhraseSequentialSegment] {
        guard characters.count > 1 else { return [] }
        var segments: [PhraseSequentialSegment] = []
        for length in 2...characters.count {
            for start in 0...(characters.count - length) {
                let segment = characters[start..<(start + length)].joined()
                segments.append(PhraseSequentialSegment(text: segment, start: start, length: length))
            }
        }
        return segments
    }

    private func bestSequentialSegmentMatch(in word: String, segments: [PhraseSequentialSegment]) -> PhraseSequentialSegment? {
        segments
            .filter { word.contains($0.text) }
            .min {
                if $0.length != $1.length { return $0.length < $1.length }
                return $0.start < $1.start
            }
    }

    func maxPhraseLength(default fallback: Int = 7) -> Int {
        max(maxPhraseLength(in: baseDb), maxPhraseLength(in: addDb), fallback)
    }

    private func maxPhraseLength(in db: OpaquePointer?) -> Int {
        guard let db else { return 0 }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT MAX(length(word)) FROM phrases", -1, &stmt, nil) == SQLITE_OK else {
            return 0
        }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(stmt, 0))
    }

    func searchByDefinition(term: String, limit: Int = 120, isStrict: Bool = false) -> [PhraseItem] {
        let normalized = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count >= 2 else { return [] }

        let sql: String
        let addSQL: String
        let pattern: String
        if isStrict {
            sql = "SELECT word, pinyin, meanings FROM phrases WHERE meanings = ? OR meanings LIKE ? OR meanings LIKE ? OR meanings LIKE ? LIMIT ?"
            addSQL = "SELECT \(addPhraseColumns) FROM phrases WHERE \(visibleAddPhraseClause) AND (meanings = ? OR notes = ? OR meanings LIKE ? OR notes LIKE ? OR meanings LIKE ? OR notes LIKE ? OR meanings LIKE ? OR notes LIKE ?) LIMIT ?"
            pattern = normalized
        } else {
            sql = "SELECT word, pinyin, meanings FROM phrases WHERE meanings LIKE ? LIMIT ?"
            addSQL = "SELECT \(addPhraseColumns) FROM phrases WHERE \(visibleAddPhraseClause) AND (meanings LIKE ? OR notes LIKE ?) LIMIT ?"
            pattern = "%\(normalized)%"
        }

        let binder: (OpaquePointer?) -> Void = { stmt in
            guard let stmt else { return }
            if isStrict {
                sqlite3_bind_text(stmt, 1, (normalized as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 2, ("% \(normalized) %" as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 3, ("\(normalized) %" as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 4, ("% \(normalized)" as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_int(stmt, 5, Int32(limit))
            } else {
                sqlite3_bind_text(stmt, 1, (pattern as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_int(stmt, 2, Int32(limit))
            }
        }
        let addBinder: (OpaquePointer?) -> Void = { stmt in
            guard let stmt else { return }
            if isStrict {
                sqlite3_bind_text(stmt, 1, (normalized as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 2, (normalized as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 3, ("% \(normalized) %" as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 4, ("% \(normalized) %" as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 5, ("\(normalized) %" as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 6, ("\(normalized) %" as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 7, ("% \(normalized)" as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 8, ("% \(normalized)" as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_int(stmt, 9, Int32(limit))
            } else {
                sqlite3_bind_text(stmt, 1, (pattern as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 2, (pattern as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_int(stmt, 3, Int32(limit))
            }
        }
        return queryRunner.mergedQueries(baseSQL: sql, addSQL: addSQL, baseBinder: binder, addBinder: addBinder)
    }

    func searchByPinyin(term: String, limit: Int = 120) -> [PhraseItem] {
        buildPinyinIndexIfNeeded()
        return pinyinSearchIndex.search(term: term, limit: limit)
    }

    func searchByCharacters(term: String, limit: Int = 120) -> [PhraseItem] {
        let normalized = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [] }
        let baseSQL = "SELECT word, pinyin, meanings FROM phrases WHERE word LIKE ? LIMIT ?"
        let addSQL = "SELECT \(addPhraseColumns) FROM phrases WHERE word LIKE ? AND \(visibleAddPhraseClause) LIMIT ?"
        let binder: (OpaquePointer?) -> Void = { stmt in
            guard let stmt else { return }
            let pattern = "%\(normalized)%"
            sqlite3_bind_text(stmt, 1, (pattern as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt, 2, Int32(limit))
        }
        return queryRunner.mergedQueries(baseSQL: baseSQL, addSQL: addSQL, binder: binder)
    }

    func isInBase(word: String) -> Bool {
        guard let baseDb else { return false }
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(baseDb, "SELECT 1 FROM phrases WHERE word = ? LIMIT 1", -1, &stmt, nil) != SQLITE_OK {
            return false
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (word as NSString).utf8String, -1, SQLITE_TRANSIENT)
        return sqlite3_step(stmt) == SQLITE_ROW
    }

    func isInAdd(word: String) -> Bool {
        guard let addDb else { return false }
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(addDb, "SELECT 1 FROM phrases WHERE word = ? LIMIT 1", -1, &stmt, nil) != SQLITE_OK {
            return false
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (word as NSString).utf8String, -1, SQLITE_TRANSIENT)
        return sqlite3_step(stmt) == SQLITE_ROW
    }

    // MARK: - Helpers

    private func ensureAddTable() throws {
        try PhraseAddDatabaseSchema.ensureTable(in: addDb)
    }

    private func sentencePhraseLinkStorageWord(_ word: String) -> String {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        let simplified = ScriptTextConverter.simplified(trimmed).trimmingCharacters(in: .whitespacesAndNewlines)
        return simplified.isEmpty ? trimmed : simplified
    }

    private func resolvedActiveAddDBURL(fileManager: FileManager) throws -> URL {
        try addDBLocationManager.resolvedActiveAddDBURL(fileManager: fileManager)
    }

    private func backup(database sourceDB: OpaquePointer, to destinationURL: URL) throws {
        try FileManager.default.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        var destinationDB: OpaquePointer?
        guard sqlite3_open_v2(destinationURL.path, &destinationDB, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK,
              let destinationDB
        else {
            let message = destinationDB.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            if let destinationDB { sqlite3_close(destinationDB) }
            throw NSError(domain: "Radix", code: 126, userInfo: [NSLocalizedDescriptionKey: "Failed to create added-phrases snapshot: \(message)"])
        }
        defer { sqlite3_close(destinationDB) }

        guard let backup = sqlite3_backup_init(destinationDB, "main", sourceDB, "main") else {
            throw NSError(domain: "Radix", code: 127, userInfo: [NSLocalizedDescriptionKey: "Failed to start added-phrases snapshot: \(String(cString: sqlite3_errmsg(destinationDB)))"])
        }
        let stepResult = sqlite3_backup_step(backup, -1)
        let finishResult = sqlite3_backup_finish(backup)
        guard stepResult == SQLITE_DONE, finishResult == SQLITE_OK else {
            throw NSError(domain: "Radix", code: 128, userInfo: [NSLocalizedDescriptionKey: "Failed to finish added-phrases snapshot: \(String(cString: sqlite3_errmsg(destinationDB)))"])
        }
    }

    private func restoreAddDatabase(from sourceURL: URL) throws {
        guard let addDb else {
            throw NSError(domain: "Radix", code: 120, userInfo: [NSLocalizedDescriptionKey: "Add phrases database is not open"])
        }
        var sourceDB: OpaquePointer?
        guard sqlite3_open_v2(sourceURL.path, &sourceDB, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let sourceDB
        else {
            let message = sourceDB.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            if let sourceDB { sqlite3_close(sourceDB) }
            throw NSError(domain: "Radix", code: 123, userInfo: [NSLocalizedDescriptionKey: "Failed to open added-phrases database: \(message)"])
        }
        defer { sqlite3_close(sourceDB) }

        guard let backup = sqlite3_backup_init(addDb, "main", sourceDB, "main") else {
            throw queryRunner.phraseWriteError(code: 124, prefix: "Added-phrases restore failed", db: addDb, currentAddDBPath: currentAddDBPath)
        }
        let stepResult = sqlite3_backup_step(backup, -1)
        let finishResult = sqlite3_backup_finish(backup)
        guard stepResult == SQLITE_DONE, finishResult == SQLITE_OK else {
            throw queryRunner.phraseWriteError(code: 125, prefix: "Added-phrases restore failed", db: addDb, currentAddDBPath: currentAddDBPath)
        }
        try ensureAddTable()
        try addDBLocationManager.syncWorkingAddDBToCustomSourceIfNeeded()
        invalidateReadCaches()
    }

    private static func addedPhrases(in sourceURL: URL) throws -> [PhraseItem] {
        var db: OpaquePointer?
        guard sqlite3_open_v2(sourceURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let db
        else {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            if let db { sqlite3_close(db) }
            throw NSError(domain: "Radix", code: 129, userInfo: [NSLocalizedDescriptionKey: "Failed to open added-phrases database: \(message)"])
        }
        defer { sqlite3_close(db) }

        let sql = "SELECT word, pinyin, meanings, notes, added_at, review_status, last_reviewed_at FROM phrases ORDER BY added_at DESC"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw NSError(domain: "Radix", code: 130, userInfo: [NSLocalizedDescriptionKey: "Failed to read added-phrases database."])
        }
        defer { sqlite3_finalize(stmt) }

        var phrases: [PhraseItem] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let statusText = stringColumn(stmt, 5)
            phrases.append(PhraseItem(
                word: stringColumn(stmt, 0),
                pinyin: stringColumn(stmt, 1),
                meanings: stringColumn(stmt, 2),
                notes: stringColumn(stmt, 3),
                addedAt: dateColumn(stmt, 4),
                reviewStatus: statusText.isEmpty ? nil : PhraseReviewStatus(rawValue: statusText),
                lastReviewedAt: dateColumn(stmt, 6)
            ))
        }
        return phrases
    }

    private static func stringColumn(_ stmt: OpaquePointer?, _ index: Int32) -> String {
        guard let ptr = sqlite3_column_text(stmt, index) else { return "" }
        return String(cString: ptr)
    }

    private static func dateColumn(_ stmt: OpaquePointer?, _ index: Int32) -> Date? {
        guard sqlite3_column_type(stmt, index) != SQLITE_NULL else { return nil }
        let timestamp = sqlite3_column_double(stmt, index)
        return timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
    }

    func restoreDefaultAddDB() throws {
        if let addDb { sqlite3_close(addDb) }
        addDb = nil
        addDBLocationManager.resetToDefault()

        let localURL = addDBLocationManager.currentLocalURL
        var newDb: OpaquePointer?
        if sqlite3_open_v2(localURL.path, &newDb, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) != SQLITE_OK {
            let err = String(cString: sqlite3_errmsg(newDb))
            throw NSError(domain: "Radix", code: 11, userInfo: [NSLocalizedDescriptionKey: "Failed to open default phrases_add.db: \(err)"])
        }
        addDb = newDb
        try ensureAddTable()
        invalidateReadCaches()
    }

    func setAddDBOverride(_ url: URL) throws {
        // Close current add DB
        if let addDb { sqlite3_close(addDb) }
        addDb = nil

        let localURL = try addDBLocationManager.applyOverride(url)

        var newDb: OpaquePointer?
        if sqlite3_open_v2(localURL.path, &newDb, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) != SQLITE_OK {
            let err = String(cString: sqlite3_errmsg(newDb))
            throw NSError(domain: "Radix", code: 11, userInfo: [NSLocalizedDescriptionKey: "Failed to open custom phrases db: \(err)"])
        }
        addDb = newDb
        try ensureAddTable()
        invalidateReadCaches()
    }

    private func buildPinyinIndexIfNeeded() {
        guard !pinyinSearchIndex.isBuilt else { return }
        pinyinSearchIndex.rebuild(with: fetchAllPhrases())
    }

    private func invalidateReadCaches() {
        pinyinSearchIndex.reset()
        mergedPhrasesCache = nil
        mergedPhraseLookup = [:]
    }

    private func phraseLookupCache() -> [String: PhraseItem] {
        if mergedPhrasesCache == nil {
            _ = fetchAllPhrases()
        }
        return mergedPhraseLookup
    }
}
