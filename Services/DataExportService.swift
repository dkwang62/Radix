import Foundation
import SQLite3

private let SQLITE_TRANSIENT_DATA_EXPORT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

struct DictionaryExportRecord {
    let character: String
    let entry: RawComponentEntry
    let pinyin: String
    let definition: String
    let decomposition: String
    let radical: String
    let strokes: Int?
}

struct DataExportService {
    func exportPortableBackup(_ package: UnifiedPackage) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(package)
    }

    func exportFullDataset(_ package: FullDatasetExportPackage) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(package)
    }

    func exportMergedDictionaryDatabase(records: [DictionaryExportRecord]) throws -> Data {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("db")
        defer { try? FileManager.default.removeItem(at: url) }

        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK else {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            if let db { sqlite3_close(db) }
            throw NSError(domain: "Radix", code: 2001, userInfo: [NSLocalizedDescriptionKey: "Failed to create dictionary export DB: \(message)"])
        }
        defer { sqlite3_close(db) }

        let createSQL = """
        CREATE TABLE dictionary (
            character TEXT PRIMARY KEY,
            pinyin TEXT,
            definition TEXT,
            decomposition TEXT,
            radical TEXT,
            strokes INTEGER,
            raw_json TEXT NOT NULL
        );
        """
        guard sqlite3_exec(db, createSQL, nil, nil, nil) == SQLITE_OK else {
            throw NSError(domain: "Radix", code: 2002, userInfo: [NSLocalizedDescriptionKey: "Failed to create dictionary table: \(String(cString: sqlite3_errmsg(db)))"])
        }

        let insertSQL = "INSERT INTO dictionary (character, pinyin, definition, decomposition, radical, strokes, raw_json) VALUES (?, ?, ?, ?, ?, ?, ?)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil) == SQLITE_OK else {
            throw NSError(domain: "Radix", code: 2003, userInfo: [NSLocalizedDescriptionKey: "Failed to prepare dictionary insert: \(String(cString: sqlite3_errmsg(db)))"])
        }
        defer { sqlite3_finalize(stmt) }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]

        for record in records {
            let rawJSON = try String(data: encoder.encode(record.entry), encoding: .utf8) ?? ""
            sqlite3_reset(stmt)
            sqlite3_clear_bindings(stmt)
            sqlite3_bind_text(stmt, 1, (record.character as NSString).utf8String, -1, SQLITE_TRANSIENT_DATA_EXPORT)
            sqlite3_bind_text(stmt, 2, (record.pinyin as NSString).utf8String, -1, SQLITE_TRANSIENT_DATA_EXPORT)
            sqlite3_bind_text(stmt, 3, (record.definition as NSString).utf8String, -1, SQLITE_TRANSIENT_DATA_EXPORT)
            sqlite3_bind_text(stmt, 4, (record.decomposition as NSString).utf8String, -1, SQLITE_TRANSIENT_DATA_EXPORT)
            sqlite3_bind_text(stmt, 5, (record.radical as NSString).utf8String, -1, SQLITE_TRANSIENT_DATA_EXPORT)
            if let strokes = record.strokes {
                sqlite3_bind_int(stmt, 6, Int32(strokes))
            } else {
                sqlite3_bind_null(stmt, 6)
            }
            sqlite3_bind_text(stmt, 7, (rawJSON as NSString).utf8String, -1, SQLITE_TRANSIENT_DATA_EXPORT)
            guard sqlite3_step(stmt) == SQLITE_DONE else {
                throw NSError(domain: "Radix", code: 2004, userInfo: [NSLocalizedDescriptionKey: "Failed to insert dictionary row for \(record.character): \(String(cString: sqlite3_errmsg(db)))"])
            }
        }

        return try Data(contentsOf: url)
    }

    func exportMergedPhrasesDatabase(phrases: [PhraseItem]) throws -> Data {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("db")
        defer { try? FileManager.default.removeItem(at: url) }

        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK else {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            if let db { sqlite3_close(db) }
            throw NSError(domain: "Radix", code: 2011, userInfo: [NSLocalizedDescriptionKey: "Failed to create phrase export DB: \(message)"])
        }
        defer { sqlite3_close(db) }

        let createSQL = "CREATE TABLE phrases (word TEXT PRIMARY KEY, pinyin TEXT, meanings TEXT, notes TEXT)"
        guard sqlite3_exec(db, createSQL, nil, nil, nil) == SQLITE_OK else {
            throw NSError(domain: "Radix", code: 2012, userInfo: [NSLocalizedDescriptionKey: "Failed to create phrases table: \(String(cString: sqlite3_errmsg(db)))"])
        }

        let insertSQL = "INSERT INTO phrases (word, pinyin, meanings, notes) VALUES (?, ?, ?, ?)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil) == SQLITE_OK else {
            throw NSError(domain: "Radix", code: 2013, userInfo: [NSLocalizedDescriptionKey: "Failed to prepare phrase insert: \(String(cString: sqlite3_errmsg(db)))"])
        }
        defer { sqlite3_finalize(stmt) }

        for phrase in phrases {
            sqlite3_reset(stmt)
            sqlite3_clear_bindings(stmt)
            sqlite3_bind_text(stmt, 1, (phrase.word as NSString).utf8String, -1, SQLITE_TRANSIENT_DATA_EXPORT)
            sqlite3_bind_text(stmt, 2, (phrase.pinyin as NSString).utf8String, -1, SQLITE_TRANSIENT_DATA_EXPORT)
            sqlite3_bind_text(stmt, 3, (phrase.meanings as NSString).utf8String, -1, SQLITE_TRANSIENT_DATA_EXPORT)
            sqlite3_bind_text(stmt, 4, (phrase.notes as NSString).utf8String, -1, SQLITE_TRANSIENT_DATA_EXPORT)
            guard sqlite3_step(stmt) == SQLITE_DONE else {
                throw NSError(domain: "Radix", code: 2014, userInfo: [NSLocalizedDescriptionKey: "Failed to insert phrase row for \(phrase.word): \(String(cString: sqlite3_errmsg(db)))"])
            }
        }

        return try Data(contentsOf: url)
    }
}
