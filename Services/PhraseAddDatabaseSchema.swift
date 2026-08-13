import Foundation
import SQLite3

enum PhraseAddDatabaseSchema {
    static func ensureTable(in db: OpaquePointer?) throws {
        guard let db else { return }
        let sql = "CREATE TABLE IF NOT EXISTS phrases (word TEXT PRIMARY KEY, pinyin TEXT, meanings TEXT, notes TEXT, added_at REAL, review_status TEXT, last_reviewed_at REAL)"
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            throw NSError(domain: "Radix", code: 10, userInfo: [NSLocalizedDescriptionKey: "Failed to create phrases_add table"])
        }
        // Idempotent migration: add added_at only if the column is missing.
        if !tableHasColumn(db: db, table: "phrases", column: "added_at") {
            if sqlite3_exec(db, "ALTER TABLE phrases ADD COLUMN added_at REAL", nil, nil, nil) != SQLITE_OK {
                throw NSError(domain: "Radix", code: 11, userInfo: [NSLocalizedDescriptionKey: "Failed to migrate phrases_add schema"])
            }
        }
        if !tableHasColumn(db: db, table: "phrases", column: "notes") {
            if sqlite3_exec(db, "ALTER TABLE phrases ADD COLUMN notes TEXT", nil, nil, nil) != SQLITE_OK {
                throw NSError(domain: "Radix", code: 11, userInfo: [NSLocalizedDescriptionKey: "Failed to migrate phrases_add notes schema"])
            }
        }
        if !tableHasColumn(db: db, table: "phrases", column: "review_status") {
            if sqlite3_exec(db, "ALTER TABLE phrases ADD COLUMN review_status TEXT", nil, nil, nil) != SQLITE_OK {
                throw NSError(domain: "Radix", code: 11, userInfo: [NSLocalizedDescriptionKey: "Failed to migrate phrases_add review schema"])
            }
        }
        if !tableHasColumn(db: db, table: "phrases", column: "last_reviewed_at") {
            if sqlite3_exec(db, "ALTER TABLE phrases ADD COLUMN last_reviewed_at REAL", nil, nil, nil) != SQLITE_OK {
                throw NSError(domain: "Radix", code: 11, userInfo: [NSLocalizedDescriptionKey: "Failed to migrate phrases_add review date schema"])
            }
        }

        let notesSQL = """
            CREATE TABLE IF NOT EXISTS \(PhraseNoteOverlayStore.tableName) (
                word TEXT PRIMARY KEY,
                notes TEXT NOT NULL DEFAULT '',
                updated_at REAL,
                source TEXT
            )
        """
        if sqlite3_exec(db, notesSQL, nil, nil, nil) != SQLITE_OK {
            throw NSError(domain: "Radix", code: 10, userInfo: [NSLocalizedDescriptionKey: "Failed to create phrase notes overlay table"])
        }
    }

    private static func tableHasColumn(db: OpaquePointer?, table: String, column: String) -> Bool {
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
}
