import Foundation
import SQLite3

/*
 PHRASE REPOSITORY (Dual-DB)
 ===========================
 - Base DB (phrases.db in app bundle): read-only, never mutated.
 - Add DB (phrases_add.db in Documents): all user-created/edited phrases.
 - Queries return the union, with Add DB overriding on word collisions.
*/

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class PhraseRepository {
    private var baseDb: OpaquePointer?
    private var addDb: OpaquePointer?
    private var pinyinIndex: [(item: PhraseItem, normalized: String, compact: String)] = []
    private var pinyinIndexBuilt = false
    private var mergedPhrasesCache: [PhraseItem]?
    private var mergedPhraseLookup: [String: PhraseItem] = [:]
    private var addOverrideURL: URL?
    private let addOverrideKey = "radix.phrasesAddOverridePath"
    private let addOverrideBookmarkKey = "radix.phrasesAddOverrideBookmark"
    private var activeSecurityScopedURL: URL?

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
        stopAccessingActiveSecurityScope()
    }

    // MARK: - Writes (Add DB only)

    func addOrUpdatePhrase(word: String, pinyin: String, meanings: String, notes: String? = nil) throws {
        guard let addDb else {
            throw NSError(domain: "Radix", code: 12, userInfo: [NSLocalizedDescriptionKey: "Add phrases database is not open"])
        }
        let updateSQL = notes == nil
            ? "UPDATE phrases SET pinyin = ?, meanings = ? WHERE word = ?"
            : "UPDATE phrases SET pinyin = ?, meanings = ?, notes = ? WHERE word = ?"
        var updateStmt: OpaquePointer?
        if sqlite3_prepare_v2(addDb, updateSQL, -1, &updateStmt, nil) != SQLITE_OK {
            throw phraseWriteError(code: 4, prefix: "Prepare failed", db: addDb)
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
            throw phraseWriteError(code: 5, prefix: "Update failed", db: addDb)
        }

        if sqlite3_changes(addDb) == 0 {
            let insertSQL = "INSERT INTO phrases (word, pinyin, meanings, notes, added_at) VALUES (?, ?, ?, ?, ?)"
            var insertStmt: OpaquePointer?
            if sqlite3_prepare_v2(addDb, insertSQL, -1, &insertStmt, nil) != SQLITE_OK {
                throw phraseWriteError(code: 4, prefix: "Prepare failed", db: addDb)
            }
            defer { sqlite3_finalize(insertStmt) }
            sqlite3_bind_text(insertStmt, 1, (word as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(insertStmt, 2, (pinyin as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(insertStmt, 3, (meanings as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(insertStmt, 4, ((notes ?? "") as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(insertStmt, 5, Date().timeIntervalSince1970)
            if sqlite3_step(insertStmt) != SQLITE_DONE {
                throw phraseWriteError(code: 5, prefix: "Insert failed", db: addDb)
            }
        }
        try syncWorkingAddDBToCustomSourceIfNeeded()
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
        try syncWorkingAddDBToCustomSourceIfNeeded()
        invalidateReadCaches()
    }

    // MARK: - Reads

    func fetchAllPhrases() -> [PhraseItem] {
        if let mergedPhrasesCache { return mergedPhrasesCache }
        let merged = mergedQueries(
            baseSQL: "SELECT word, pinyin, meanings FROM phrases",
            addSQL: "SELECT word, pinyin, meanings, added_at, notes FROM phrases"
        )
        mergedPhrasesCache = merged
        mergedPhraseLookup = Dictionary(uniqueKeysWithValues: merged.map { ($0.word, $0) })
        return merged
    }

    func fetchAddedPhrases() -> [PhraseItem] {
        runQuery(db: addDb, sql: "SELECT word, pinyin, meanings, added_at, notes FROM phrases ORDER BY added_at DESC")
    }

    func fetchPhrase(for word: String) -> PhraseItem? {
        if let cached = mergedPhraseLookup[word] {
            return cached
        }
        if mergedPhrasesCache != nil {
            return nil
        }
        let addSQL = "SELECT word, pinyin, meanings, added_at, notes FROM phrases WHERE word = ? LIMIT 1"
        let baseSQL = "SELECT word, pinyin, meanings FROM phrases WHERE word = ? LIMIT 1"
        let binder: (OpaquePointer?) -> Void = { stmt in
            sqlite3_bind_text(stmt, 1, (word as NSString).utf8String, -1, SQLITE_TRANSIENT)
        }
        // Check add DB first, then base
        let fromAdd = runQuery(db: addDb, sql: addSQL, binder: binder).first
        if let p = fromAdd { return p }
        return runQuery(db: baseDb, sql: baseSQL, binder: binder).first
    }

    func fetchPhrases(matching words: Set<String>) -> [PhraseItem] {
        guard !words.isEmpty else { return [] }
        let lookup = phraseLookupCache()
        return words.compactMap { lookup[$0] }
    }

    func phraseWordSet() -> Set<String> {
        Set(fetchAllPhrases().map(\.word))
    }

    func existingWords(in words: Set<String>) -> Set<String> {
        guard !words.isEmpty else { return [] }
        let lookup = phraseLookupCache()
        return Set(words.filter { lookup[$0] != nil })
    }

    /// Additive import — inserts missing phrases and safely merges restored notes into existing overlay rows.
    func addPhrasesAdditively(_ phrases: [PhraseItem]) throws {
        guard let addDb else { return }
        let sql = "INSERT OR IGNORE INTO phrases (word, pinyin, meanings, notes, added_at) VALUES (?, ?, ?, ?, ?)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(addDb, sql, -1, &stmt, nil) == SQLITE_OK else { return }
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
        guard sqlite3_prepare_v2(addDb, mergeSQL, -1, &mergeStmt, nil) == SQLITE_OK else { return }
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
            sqlite3_bind_double(stmt, 5, now)
            sqlite3_step(stmt)

            sqlite3_reset(mergeStmt)
            sqlite3_clear_bindings(mergeStmt)
            sqlite3_bind_text(mergeStmt, 1, (restoredNotes as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(mergeStmt, 2, (restoredNotes as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(mergeStmt, 3, (restoredNotes as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(mergeStmt, 4, ("%\(restoredNotes)%" as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(mergeStmt, 5, (restoredNotes as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(mergeStmt, 6, (p.word as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_step(mergeStmt)
        }
        try syncWorkingAddDBToCustomSourceIfNeeded()
        invalidateReadCaches()
    }

    /// Complete import — deletes all existing rows then inserts the backup phrases in full.
    func replaceAllPhrases(_ phrases: [PhraseItem]) throws {
        guard let addDb else { return }
        if sqlite3_exec(addDb, "BEGIN IMMEDIATE TRANSACTION", nil, nil, nil) != SQLITE_OK {
            throw phraseWriteError(code: 14, prefix: "Begin restore failed", db: addDb)
        }
        var shouldRollback = true
        defer {
            if shouldRollback {
                sqlite3_exec(addDb, "ROLLBACK", nil, nil, nil)
            }
        }

        if sqlite3_exec(addDb, "DELETE FROM phrases", nil, nil, nil) != SQLITE_OK {
            throw phraseWriteError(code: 15, prefix: "Delete-all failed", db: addDb)
        }
        let sql = "INSERT INTO phrases (word, pinyin, meanings, notes, added_at) VALUES (?, ?, ?, ?, ?)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(addDb, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw phraseWriteError(code: 16, prefix: "Prepare failed", db: addDb)
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
            if sqlite3_step(stmt) != SQLITE_DONE {
                throw phraseWriteError(code: 17, prefix: "Insert failed for \(p.word)", db: addDb)
            }
        }
        if sqlite3_exec(addDb, "COMMIT", nil, nil, nil) != SQLITE_OK {
            throw phraseWriteError(code: 18, prefix: "Commit restore failed", db: addDb)
        }
        shouldRollback = false
        try syncWorkingAddDBToCustomSourceIfNeeded()
        invalidateReadCaches()
    }

    func addedPhrases(containing character: String, limit: Int = 240) -> [PhraseItem] {
        let sql = "SELECT word, pinyin, meanings, added_at, notes FROM phrases WHERE word LIKE ? LIMIT ?"
        let binder: (OpaquePointer?) -> Void = { stmt in
            guard let stmt else { return }
            sqlite3_bind_text(stmt, 1, ("%\(character)%" as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt, 2, Int32(limit))
        }
        return runQuery(db: addDb, sql: sql, binder: binder).filter {
            $0.word.contains(character) && (2...4).contains($0.word.count)
        }
    }
    
    var currentAddDBPath: String {
        if let addOverrideURL { return addOverrideURL.path }
        let fm = FileManager.default
        return resolvedAddDBURL(fileManager: fm).path
    }

    var currentAddDBURL: URL {
        return resolvedAddDBURL(fileManager: .default)
    }

    func phrases(containing character: String, length: Int, limit: Int = 120) -> [PhraseItem] {
        let baseSQL = "SELECT word, pinyin, meanings FROM phrases WHERE word LIKE ? AND length(word) = ? LIMIT ?"
        let addSQL = "SELECT word, pinyin, meanings, added_at, notes FROM phrases WHERE word LIKE ? AND length(word) = ? LIMIT ?"
        let bind: (OpaquePointer?) -> Void = { stmt in
            guard let stmt else { return }
            sqlite3_bind_text(stmt, 1, ("%\(character)%" as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt, 2, Int32(length))
            sqlite3_bind_int(stmt, 3, Int32(limit))
        }
        let results = mergedQueries(baseSQL: baseSQL, addSQL: addSQL, binder: bind)
        return results.filter { $0.word.contains(character) }
    }

    func searchByDefinition(term: String, limit: Int = 120, isStrict: Bool = false) -> [PhraseItem] {
        let normalized = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count >= 2 else { return [] }

        let sql: String
        let addSQL: String
        let pattern: String
        if isStrict {
            sql = "SELECT word, pinyin, meanings FROM phrases WHERE meanings = ? OR meanings LIKE ? OR meanings LIKE ? OR meanings LIKE ? LIMIT ?"
            addSQL = "SELECT word, pinyin, meanings, added_at, notes FROM phrases WHERE meanings = ? OR notes = ? OR meanings LIKE ? OR notes LIKE ? OR meanings LIKE ? OR notes LIKE ? OR meanings LIKE ? OR notes LIKE ? LIMIT ?"
            pattern = normalized
        } else {
            sql = "SELECT word, pinyin, meanings FROM phrases WHERE meanings LIKE ? LIMIT ?"
            addSQL = "SELECT word, pinyin, meanings, added_at, notes FROM phrases WHERE meanings LIKE ? OR notes LIKE ? LIMIT ?"
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
        return mergedQueries(baseSQL: sql, addSQL: addSQL, baseBinder: binder, addBinder: addBinder)
    }

    func searchByPinyin(term: String, limit: Int = 120) -> [PhraseItem] {
        let normalizedQuery = normalizePinyinLoose(term)
        let compactQuery = normalizedQuery.replacingOccurrences(of: " ", with: "")
        guard compactQuery.count >= 2 else { return [] }

        buildPinyinIndexIfNeeded()
        guard !pinyinIndex.isEmpty else { return [] }

        var out: [PhraseItem] = []
        out.reserveCapacity(min(limit, 200))
        for row in pinyinIndex {
            if row.normalized.contains(normalizedQuery) || row.compact.contains(compactQuery) {
                out.append(row.item)
                if out.count >= limit { break }
            }
        }
        return out
    }

    func searchByCharacters(term: String, limit: Int = 120) -> [PhraseItem] {
        let normalized = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [] }
        let baseSQL = "SELECT word, pinyin, meanings FROM phrases WHERE word LIKE ? LIMIT ?"
        let addSQL = "SELECT word, pinyin, meanings, added_at, notes FROM phrases WHERE word LIKE ? LIMIT ?"
        let binder: (OpaquePointer?) -> Void = { stmt in
            guard let stmt else { return }
            let pattern = "%\(normalized)%"
            sqlite3_bind_text(stmt, 1, (pattern as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt, 2, Int32(limit))
        }
        return mergedQueries(baseSQL: baseSQL, addSQL: addSQL, binder: binder)
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
        guard let addDb else { return }
        let sql = "CREATE TABLE IF NOT EXISTS phrases (word TEXT PRIMARY KEY, pinyin TEXT, meanings TEXT, notes TEXT, added_at REAL)"
        if sqlite3_exec(addDb, sql, nil, nil, nil) != SQLITE_OK {
            throw NSError(domain: "Radix", code: 10, userInfo: [NSLocalizedDescriptionKey: "Failed to create phrases_add table"])
        }
        // Idempotent migration: add added_at only if the column is missing.
        if !tableHasColumn(db: addDb, table: "phrases", column: "added_at") {
            if sqlite3_exec(addDb, "ALTER TABLE phrases ADD COLUMN added_at REAL", nil, nil, nil) != SQLITE_OK {
                throw NSError(domain: "Radix", code: 11, userInfo: [NSLocalizedDescriptionKey: "Failed to migrate phrases_add schema"])
            }
        }
        if !tableHasColumn(db: addDb, table: "phrases", column: "notes") {
            if sqlite3_exec(addDb, "ALTER TABLE phrases ADD COLUMN notes TEXT", nil, nil, nil) != SQLITE_OK {
                throw NSError(domain: "Radix", code: 11, userInfo: [NSLocalizedDescriptionKey: "Failed to migrate phrases_add notes schema"])
            }
        }
    }

    private func tableHasColumn(db: OpaquePointer?, table: String, column: String) -> Bool {
        guard let db else { return false }
        let escapedTable = table.replacingOccurrences(of: "\"", with: "\"\"")
        let sql = "PRAGMA table_info(\"\(escapedTable)\")"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return false
        }
        defer { sqlite3_finalize(stmt) }

        while sqlite3_step(stmt) == SQLITE_ROW {
            // PRAGMA table_info columns: cid, name, type, notnull, dflt_value, pk
            if let namePtr = sqlite3_column_text(stmt, 1) {
                let name = String(cString: namePtr)
                if name.caseInsensitiveCompare(column) == .orderedSame {
                    return true
                }
            }
        }
        return false
    }

    private func resolvedAddDBURL(fileManager: FileManager) -> URL {
        let localDocs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return localDocs.appendingPathComponent("phrases_add.db")
    }

    private func resolvedActiveAddDBURL(fileManager: FileManager) throws -> URL {
        let localURL = resolvedAddDBURL(fileManager: fileManager)
        if let addOverrideURL {
            try syncWorkingAddDBFromCustomSource(addOverrideURL, to: localURL)
            return localURL
        }
        if let bookmarkData = UserDefaults.standard.data(forKey: addOverrideBookmarkKey) {
            var isStale = false
            if let resolvedURL = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: bookmarkResolutionOptions,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                if fileManager.fileExists(atPath: resolvedURL.path) {
                    if beginAccessingSecurityScopeIfNeeded(for: resolvedURL) {
                        addOverrideURL = resolvedURL
                        if isStale {
                            persistSecurityScopedBookmark(for: resolvedURL)
                        }
                        UserDefaults.standard.set(resolvedURL.path, forKey: addOverrideKey)
                        try syncWorkingAddDBFromCustomSource(resolvedURL, to: localURL)
                        return localURL
                    }
                } else {
                    UserDefaults.standard.removeObject(forKey: addOverrideBookmarkKey)
                }
            }
        }
        if let saved = UserDefaults.standard.string(forKey: addOverrideKey) {
            let url = URL(fileURLWithPath: saved)
            if fileManager.fileExists(atPath: url.path) {
                addOverrideURL = url
                try syncWorkingAddDBFromCustomSource(url, to: localURL)
                return localURL
            }
            UserDefaults.standard.removeObject(forKey: addOverrideKey)
            UserDefaults.standard.removeObject(forKey: addOverrideBookmarkKey)
        }
        return localURL
    }

    func restoreDefaultAddDB() throws {
        if let addDb { sqlite3_close(addDb) }
        addDb = nil
        stopAccessingActiveSecurityScope()
        addOverrideURL = nil
        UserDefaults.standard.removeObject(forKey: addOverrideKey)
        UserDefaults.standard.removeObject(forKey: addOverrideBookmarkKey)

        let localURL = resolvedAddDBURL(fileManager: .default)
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
        stopAccessingActiveSecurityScope()

        _ = beginAccessingSecurityScopeIfNeeded(for: url)
        addOverrideURL = url
        UserDefaults.standard.set(url.path, forKey: addOverrideKey)
        persistSecurityScopedBookmark(for: url)

        let localURL = resolvedAddDBURL(fileManager: .default)
        try syncWorkingAddDBFromCustomSource(url, to: localURL)

        var newDb: OpaquePointer?
        if sqlite3_open_v2(localURL.path, &newDb, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) != SQLITE_OK {
            let err = String(cString: sqlite3_errmsg(newDb))
            throw NSError(domain: "Radix", code: 11, userInfo: [NSLocalizedDescriptionKey: "Failed to open custom phrases db: \(err)"])
        }
        addDb = newDb
        try ensureAddTable()
        invalidateReadCaches()
    }

    private func beginAccessingSecurityScopeIfNeeded(for url: URL) -> Bool {
        if activeSecurityScopedURL?.path == url.path {
            return true
        }
        stopAccessingActiveSecurityScope()
        if url.startAccessingSecurityScopedResource() {
            activeSecurityScopedURL = url
            return true
        }
        return false
    }

    private func stopAccessingActiveSecurityScope() {
        guard let activeSecurityScopedURL else { return }
        activeSecurityScopedURL.stopAccessingSecurityScopedResource()
        self.activeSecurityScopedURL = nil
    }

    private func persistSecurityScopedBookmark(for url: URL) {
        guard let bookmarkData = try? url.bookmarkData(options: bookmarkCreationOptions, includingResourceValuesForKeys: nil, relativeTo: nil) else {
            UserDefaults.standard.removeObject(forKey: addOverrideBookmarkKey)
            return
        }
        UserDefaults.standard.set(bookmarkData, forKey: addOverrideBookmarkKey)
    }

    private var bookmarkCreationOptions: URL.BookmarkCreationOptions {
        #if targetEnvironment(macCatalyst)
        return [.withSecurityScope]
        #else
        return []
        #endif
    }

    private var bookmarkResolutionOptions: URL.BookmarkResolutionOptions {
        #if targetEnvironment(macCatalyst)
        return [.withSecurityScope]
        #else
        return []
        #endif
    }

    private func runQuery(db: OpaquePointer?, sql: String, binder: ((OpaquePointer?) -> Void)? = nil) -> [PhraseItem] {
        guard let db else { return [] }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        binder?(stmt)
        var out: [PhraseItem] = []
        let colCount = sqlite3_column_count(stmt)
        while sqlite3_step(stmt) == SQLITE_ROW {
            let word = String(cString: sqlite3_column_text(stmt, 0))
            let pinyin = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""
            let meanings = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? ""
            var addedAt: Date? = nil
            if colCount > 3 && sqlite3_column_type(stmt, 3) != SQLITE_NULL {
                addedAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 3))
            }
            let notes = colCount > 4 ? (sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? "") : ""
            out.append(PhraseItem(word: word, pinyin: pinyin, meanings: meanings, notes: notes, addedAt: addedAt))
        }
        return out
    }

    private func phraseWriteError(code: Int, prefix: String, db: OpaquePointer?) -> NSError {
        let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
        let errCode = db.map { sqlite3_errcode($0) } ?? -1
        let extendedCode = db.map { sqlite3_extended_errcode($0) } ?? -1
        let readonly = db.map { sqlite3_db_readonly($0, "main") } ?? -1
        let details = "\(prefix): \(message) [errcode=\(errCode) extended=\(extendedCode) readonly=\(readonly) path=\(currentAddDBPath)]"
        return NSError(domain: "Radix", code: code, userInfo: [NSLocalizedDescriptionKey: details])
    }

    private func syncWorkingAddDBFromCustomSource(_ sourceURL: URL, to localURL: URL) throws {
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var copied = false
        var readError: NSError?

        coordinator.coordinate(readingItemAt: sourceURL, options: [], error: &coordinationError) { coordinatedURL in
            do {
                let data = try Data(contentsOf: coordinatedURL)
                let dir = localURL.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
                try data.write(to: localURL, options: .atomic)
                copied = true
            } catch {
                readError = error as NSError
            }
        }

        if let readError {
            throw readError
        }
        if let coordinationError {
            throw coordinationError
        }
        if !copied {
            throw NSError(domain: "Radix", code: 14, userInfo: [NSLocalizedDescriptionKey: "Failed to load custom phrases file."])
        }
    }

    private func syncWorkingAddDBToCustomSourceIfNeeded() throws {
        guard let sourceURL = addOverrideURL else { return }
        let localURL = resolvedAddDBURL(fileManager: .default)
        let data = try Data(contentsOf: localURL)
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var writeError: NSError?

        coordinator.coordinate(writingItemAt: sourceURL, options: .forReplacing, error: &coordinationError) { coordinatedURL in
            do {
                try data.write(to: coordinatedURL, options: .atomic)
            } catch {
                writeError = error as NSError
            }
        }

        if let writeError {
            throw writeError
        }
        if let coordinationError {
            throw coordinationError
        }
    }

    private func mergedQueries(baseSQL: String, addSQL: String, binder: ((OpaquePointer?) -> Void)? = nil) -> [PhraseItem] {
        mergedQueries(baseSQL: baseSQL, addSQL: addSQL, baseBinder: binder, addBinder: binder)
    }

    private func mergedQueries(baseSQL: String, addSQL: String, baseBinder: ((OpaquePointer?) -> Void)? = nil, addBinder: ((OpaquePointer?) -> Void)? = nil) -> [PhraseItem] {
        var map: [String: PhraseItem] = [:]
        for item in runQuery(db: baseDb, sql: baseSQL, binder: baseBinder) { map[item.word] = item }
        for item in runQuery(db: addDb, sql: addSQL, binder: addBinder) { map[item.word] = item } // add overrides
        return Array(map.values)
    }

    private func normalizePinyinForSearch(_ value: String) -> String {
        let mutable = NSMutableString(string: value.lowercased()) as CFMutableString
        CFStringTransform(mutable, nil, kCFStringTransformStripDiacritics, false)
        let stripped = mutable as String
        return stripped.filter { $0.isLetter || $0.isNumber }
    }

    private func normalizePinyinLoose(_ value: String) -> String {
        let mutable = NSMutableString(string: value.lowercased()) as CFMutableString
        CFStringTransform(mutable, nil, kCFStringTransformStripDiacritics, false)
        let stripped = mutable as String
        return stripped
            .map { ch -> Character in
                (ch.isLetter || ch.isNumber || ch == " ") ? ch : " "
            }
            .reduce(into: "") { partial, ch in
                if ch == " " {
                    if partial.last != " " { partial.append(ch) }
                } else {
                    partial.append(ch)
                }
            }
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func buildPinyinIndexIfNeeded() {
        guard !pinyinIndexBuilt else { return }
        pinyinIndexBuilt = true
        let merged = fetchAllPhrases()
        var built: [(item: PhraseItem, normalized: String, compact: String)] = []
        built.reserveCapacity(merged.count)
        for item in merged {
            let normalized = normalizePinyinLoose(item.pinyin)
            let compact = normalizePinyinForSearch(item.pinyin)
            if !compact.isEmpty {
                built.append((item, normalized, compact))
            }
        }
        built.sort { lhs, rhs in
            if lhs.item.word.count != rhs.item.word.count { return lhs.item.word.count < rhs.item.word.count }
            return lhs.item.word < rhs.item.word
        }
        pinyinIndex = built
    }

    private func invalidateReadCaches() {
        pinyinIndex = []
        pinyinIndexBuilt = false
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
