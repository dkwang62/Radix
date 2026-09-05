import Foundation
import SQLite3

private let SQLITE_TRANSIENT_SENTENCE_EXAMPLES = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum SentenceExampleQueryScope: Equatable {
    case all
    case favorites
    case pageLinked
    case practice
    case sourceType(SentenceExampleSourceType)
    case page(UUID, SentenceExampleSourceType?)
}

struct SentenceExampleQuery: Equatable {
    var scope: SentenceExampleQueryScope = .all
    var searchText = ""
    var minimumCharacterCount = 0
    var offset = 0
    var limit: Int? = nil
}

struct SentenceExampleQueryResult: Equatable {
    var records: [SentenceExampleRecord]
    var totalCount: Int
}

struct SentenceExampleOptimizationStats: Equatable, Sendable {
    var count: Int
    var latestCreatedAt: TimeInterval
    var latestUpdatedAt: TimeInterval
    var normalizedKeyHash: String
}

struct SentenceExampleStorageStats: Equatable, Sendable {
    var count: Int
    var byteCount: Int64
}

final class SentenceLibraryStore: @unchecked Sendable {
    private let databaseURL: URL
    private let canonicalize: ([SentenceExampleRecord]) -> [SentenceExampleRecord]
    private let simplify: (String) -> String
    private let matchesSearchText: (SentenceExampleRecord, String) -> Bool
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let lock = NSRecursiveLock()
    private var db: OpaquePointer?
    private var fallbackRecords: [SentenceExampleRecord]?

    init(
        databaseURL: URL? = nil,
        canonicalize: @escaping ([SentenceExampleRecord]) -> [SentenceExampleRecord],
        simplify: @escaping (String) -> String,
        matchesSearchText: @escaping (SentenceExampleRecord, String) -> Bool
    ) {
        self.databaseURL = databaseURL ?? Self.defaultDatabaseURL()
        self.canonicalize = canonicalize
        self.simplify = simplify
        self.matchesSearchText = matchesSearchText
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
                let legacy = canonicalize(legacyProvider())
                self.fallbackRecords = legacy
                return legacy
            }
            return fallbackRecords
        }

        do {
            try openIfNeeded()
            let records = try fetchAllUnlocked()
            if !records.isEmpty {
                let canonicalRecords = canonicalize(records)
                if canonicalRecords != records {
                    try replaceAllUnlocked(canonicalRecords)
                }
                return canonicalRecords
            }
            let legacy = canonicalize(legacyProvider())
            if !legacy.isEmpty {
                try replaceAllUnlocked(legacy)
            }
            return legacy
        } catch {
            let legacy = canonicalize(legacyProvider())
            fallbackRecords = legacy
            return legacy
        }
    }

    func optimizationStats(migratingLegacy legacyProvider: () -> [SentenceExampleRecord]) -> SentenceExampleOptimizationStats {
        lock.lock()
        defer { lock.unlock() }

        if let fallbackRecords {
            return optimizationStats(for: fallbackRecords)
        }

        do {
            try openIfNeeded()
            try migrateLegacyIfNeededUnlocked(legacyProvider)
            return try optimizationStatsUnlocked()
        } catch {
            let legacy = canonicalize(legacyProvider())
            fallbackRecords = legacy
            return optimizationStats(for: legacy)
        }
    }

    func databaseByteCount() -> Int64 {
        (((try? FileManager.default.attributesOfItem(atPath: databaseURL.path)[.size]) as? NSNumber)?.int64Value) ?? 0
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
            let legacy = canonicalize(legacyProvider())
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
            let legacy = canonicalize(legacyProvider())
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
            let legacy = canonicalize(legacyProvider())
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
            let legacy = canonicalize(legacyProvider())
            fallbackRecords = legacy
            return recordsByNormalizedKey(legacy, matching: keys)
        }
    }

    func replaceAll(_ records: [SentenceExampleRecord]) {
        lock.lock()
        defer { lock.unlock() }

        let records = canonicalize(records)
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
            self.fallbackRecords = canonicalize(
                fallbackRecords + records
            )
            return
        }

        do {
            try openIfNeeded()
            let records = canonicalize(records)
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
            fallbackRecords = canonicalize(records)
        }
    }

    func replace(_ records: [SentenceExampleRecord]) {
        guard !records.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }

        let records = canonicalize(records)
        if let fallbackRecords {
            var updatedByID = Dictionary(uniqueKeysWithValues: fallbackRecords.map { ($0.id, $0) })
            for record in records {
                updatedByID[record.id] = record
            }
            var seenIDs = Set<UUID>()
            let replaced = fallbackRecords.compactMap { record -> SentenceExampleRecord? in
                guard let updated = updatedByID[record.id] else { return record }
                seenIDs.insert(record.id)
                return updated
            }
            let appended = records.filter { !seenIDs.contains($0.id) }
            self.fallbackRecords = canonicalize(replaced + appended)
            return
        }

        do {
            try openIfNeeded()
            try insertUnlocked(records)
        } catch {
            return
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

    func backupDatabase(to destinationURL: URL) throws {
        lock.lock()
        defer { lock.unlock() }

        guard fallbackRecords == nil else {
            throw NSError(domain: "Radix", code: 3130, userInfo: [NSLocalizedDescriptionKey: "Sentence database is using in-memory fallback storage."])
        }

        try openIfNeeded()
        guard let db else {
            throw NSError(domain: "Radix", code: 3138, userInfo: [NSLocalizedDescriptionKey: "Sentence database is not open."])
        }
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
            throw NSError(domain: "Radix", code: 3131, userInfo: [NSLocalizedDescriptionKey: "Failed to create sentence snapshot: \(message)"])
        }
        defer { sqlite3_close(destinationDB) }

        guard let backup = sqlite3_backup_init(destinationDB, "main", db, "main") else {
            throw NSError(domain: "Radix", code: 3132, userInfo: [NSLocalizedDescriptionKey: "Failed to start sentence snapshot: \(String(cString: sqlite3_errmsg(destinationDB)))"])
        }
        let stepResult = sqlite3_backup_step(backup, -1)
        let finishResult = sqlite3_backup_finish(backup)
        guard stepResult == SQLITE_DONE, finishResult == SQLITE_OK else {
            throw NSError(domain: "Radix", code: 3133, userInfo: [NSLocalizedDescriptionKey: "Failed to finish sentence snapshot: \(String(cString: sqlite3_errmsg(destinationDB)))"])
        }
    }

    static func validateSentenceDatabase(at sourceURL: URL) throws {
        guard FileManager.default.isReadableFile(atPath: sourceURL.path) else {
            throw NSError(domain: "Radix", code: 3141, userInfo: [NSLocalizedDescriptionKey: "Sentence database file is not readable."])
        }

        var sourceDB: OpaquePointer?
        guard sqlite3_open_v2(sourceURL.path, &sourceDB, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let sourceDB
        else {
            let message = sourceDB.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            if let sourceDB { sqlite3_close(sourceDB) }
            throw NSError(domain: "Radix", code: 3142, userInfo: [NSLocalizedDescriptionKey: "Failed to open sentence database: \(message)"])
        }
        defer { sqlite3_close(sourceDB) }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(sourceDB, "PRAGMA table_info(sentence_examples)", -1, &statement, nil) == SQLITE_OK else {
            throw NSError(domain: "Radix", code: 3143, userInfo: [NSLocalizedDescriptionKey: "Failed to inspect sentence database."])
        }
        defer { sqlite3_finalize(statement) }

        var columns = Set<String>()
        while sqlite3_step(statement) == SQLITE_ROW {
            if let nameText = sqlite3_column_text(statement, 1) {
                columns.insert(String(cString: nameText))
            }
        }
        let requiredColumns: Set<String> = ["id", "normalized_key", "record_json"]
        guard requiredColumns.isSubset(of: columns) else {
            throw NSError(domain: "Radix", code: 3144, userInfo: [NSLocalizedDescriptionKey: "This is not a Radix sentence database."])
        }
    }

    func restoreDatabase(from sourceURL: URL) throws {
        lock.lock()
        defer { lock.unlock() }

        guard FileManager.default.isReadableFile(atPath: sourceURL.path) else {
            throw NSError(domain: "Radix", code: 3134, userInfo: [NSLocalizedDescriptionKey: "Sentence snapshot is not readable."])
        }

        try openIfNeeded()
        guard let db else {
            throw NSError(domain: "Radix", code: 3138, userInfo: [NSLocalizedDescriptionKey: "Sentence database is not open."])
        }
        var sourceDB: OpaquePointer?
        guard sqlite3_open_v2(sourceURL.path, &sourceDB, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let sourceDB
        else {
            let message = sourceDB.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            if let sourceDB { sqlite3_close(sourceDB) }
            throw NSError(domain: "Radix", code: 3135, userInfo: [NSLocalizedDescriptionKey: "Failed to open sentence snapshot: \(message)"])
        }
        defer { sqlite3_close(sourceDB) }

        guard let backup = sqlite3_backup_init(db, "main", sourceDB, "main") else {
            throw sqliteError(code: 3136, message: "Failed to start sentence restore")
        }
        let stepResult = sqlite3_backup_step(backup, -1)
        let finishResult = sqlite3_backup_finish(backup)
        guard stepResult == SQLITE_DONE, finishResult == SQLITE_OK else {
            throw sqliteError(code: 3137, message: "Failed to finish sentence restore")
        }
        fallbackRecords = nil
        try ensureSchema()
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
        let legacy = canonicalize(legacyProvider())
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

    private func optimizationStatsUnlocked() throws -> SentenceExampleOptimizationStats {
        guard let db else {
            return SentenceExampleOptimizationStats(count: 0, latestCreatedAt: 0, latestUpdatedAt: 0, normalizedKeyHash: "0")
        }
        let sql = """
        SELECT normalized_key, created_at, COALESCE(updated_at, 0)
        FROM sentence_examples
        ORDER BY normalized_key
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw sqliteError(code: 3141, message: "Failed to prepare sentence optimization stats")
        }
        defer { sqlite3_finalize(statement) }

        var count = 0
        var latestCreatedAt: TimeInterval = 0
        var latestUpdatedAt: TimeInterval = 0
        var hash: UInt64 = 14_695_981_039_346_656_037
        while sqlite3_step(statement) == SQLITE_ROW {
            count += 1
            let key = sqlite3_column_text(statement, 0).map { String(cString: $0) } ?? ""
            hash = Self.stableHash(hash, key)
            latestCreatedAt = max(latestCreatedAt, sqlite3_column_double(statement, 1))
            latestUpdatedAt = max(latestUpdatedAt, sqlite3_column_double(statement, 2))
        }
        return SentenceExampleOptimizationStats(
            count: count,
            latestCreatedAt: latestCreatedAt,
            latestUpdatedAt: latestUpdatedAt,
            normalizedKeyHash: String(hash, radix: 16)
        )
    }

    private func optimizationStats(for records: [SentenceExampleRecord]) -> SentenceExampleOptimizationStats {
        var hash: UInt64 = 14_695_981_039_346_656_037
        var latestCreatedAt: TimeInterval = 0
        var latestUpdatedAt: TimeInterval = 0
        for record in records.sorted(by: { $0.normalizedChineseKey < $1.normalizedChineseKey }) {
            hash = Self.stableHash(hash, record.normalizedChineseKey)
            latestCreatedAt = max(latestCreatedAt, record.createdAt.timeIntervalSince1970)
            latestUpdatedAt = max(latestUpdatedAt, record.lastUsedAt?.timeIntervalSince1970 ?? 0)
        }
        return SentenceExampleOptimizationStats(
            count: records.count,
            latestCreatedAt: latestCreatedAt,
            latestUpdatedAt: latestUpdatedAt,
            normalizedKeyHash: String(hash, radix: 16)
        )
    }

    private static func stableHash(_ seed: UInt64, _ value: String) -> UInt64 {
        value.utf8.reduce(seed) { ($0 ^ UInt64($1)) &* 1_099_511_628_211 }
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
        case .sourceType(let sourceType):
            clauses.append("is_hidden = 0")
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
        let minimumCharacterCount = max(0, query.minimumCharacterCount)
        if minimumCharacterCount > 0 {
            clauses.append("length(normalized_key) >= \(minimumCharacterCount)")
        }

        return (clauses.isEmpty ? "" : "WHERE \(clauses.joined(separator: " AND "))", bindings)
    }

    private func searchPatterns(for query: String) -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let simplified = simplify(trimmed).trimmingCharacters(in: .whitespacesAndNewlines)
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
            case .sourceType(let sourceType):
                guard record.hasSourceType(sourceType) else { return false }
            case .page(let pageID, let sourceType):
                guard record.isLinked(toPageID: pageID) else { return false }
                if let sourceType, !record.hasSourceType(sourceType) {
                    return false
                }
            }
            guard record.normalizedChineseKey.count >= query.minimumCharacterCount else { return false }
            return matchesSearchText(record, query.searchText)
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
            bind(searchText(for: record), to: 6, in: statement)
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

    private func searchText(for record: SentenceExampleRecord) -> String {
        let values = [
            record.chinese,
            simplify(record.chinese),
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
        return Self.foldedSearchText(values.joined(separator: " "))
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
