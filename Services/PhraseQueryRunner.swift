import Foundation
import SQLite3

/*
 PHRASE QUERY RUNNER
 ===================
 Stateless SQLite plumbing shared by PhraseRepository.
 Handles row decoding, dual-DB merged queries, and write-error formatting.
 All methods are pure functions of their inputs — no stored state.
*/

// Mirrors the file-private constant in PhraseRepository.
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

struct PhraseQueryRunner {
    let baseDb: OpaquePointer?
    let addDb: OpaquePointer?

    // MARK: - Row decoding

    func runQuery(db: OpaquePointer?, sql: String, binder: ((OpaquePointer?) -> Void)? = nil) -> [PhraseItem] {
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
            let statusText = colCount > 5 ? (sqlite3_column_text(stmt, 5).map { String(cString: $0) } ?? "") : ""
            let reviewStatus = PhraseReviewStatus(rawValue: statusText)
            var lastReviewedAt: Date? = nil
            if colCount > 6 && sqlite3_column_type(stmt, 6) != SQLITE_NULL {
                lastReviewedAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 6))
            }
            out.append(
                PhraseItem(
                    word: word,
                    pinyin: pinyin,
                    meanings: meanings,
                    notes: notes,
                    addedAt: addedAt,
                    reviewStatus: reviewStatus,
                    lastReviewedAt: lastReviewedAt
                )
            )
        }
        return out
    }

    // MARK: - Dual-DB merge

    /// Convenience overload — uses the same binder for both DBs.
    func mergedQueries(baseSQL: String, addSQL: String, binder: ((OpaquePointer?) -> Void)? = nil) -> [PhraseItem] {
        mergedQueries(baseSQL: baseSQL, addSQL: addSQL, baseBinder: binder, addBinder: binder)
    }

    func mergedQueries(baseSQL: String, addSQL: String, baseBinder: ((OpaquePointer?) -> Void)? = nil, addBinder: ((OpaquePointer?) -> Void)? = nil) -> [PhraseItem] {
        var map: [String: PhraseItem] = [:]
        for item in runQuery(db: baseDb, sql: baseSQL, binder: baseBinder) { map[item.word] = item }
        for item in runQuery(db: addDb, sql: addSQL, binder: addBinder) { map[item.word] = item } // add overrides
        return Array(map.values)
    }

    // MARK: - Error formatting

    func phraseWriteError(code: Int, prefix: String, db: OpaquePointer?, currentAddDBPath: String) -> NSError {
        let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
        let errCode = db.map { sqlite3_errcode($0) } ?? -1
        let extendedCode = db.map { sqlite3_extended_errcode($0) } ?? -1
        let readonly = db.map { sqlite3_db_readonly($0, "main") } ?? -1
        let details = "\(prefix): \(message) [errcode=\(errCode) extended=\(extendedCode) readonly=\(readonly) path=\(currentAddDBPath)]"
        return NSError(domain: "Radix", code: code, userInfo: [NSLocalizedDescriptionKey: details])
    }
}
