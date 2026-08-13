import Foundation
import SQLite3

private let SQLITE_TRANSIENT_PHRASE_NOTE_OVERLAY = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

struct PhraseNoteOverlayStore {
    static let tableName = PhraseNoteOverlayRules.tableName

    let db: OpaquePointer?

    func apply(to phrase: PhraseItem) -> PhraseItem {
        guard let overlay = note(for: phrase.word), !overlay.isEmpty else {
            return phrase
        }
        return phrase.withNotes(PhraseNoteOverlayRules.mergeNotes(phrase.notes, overlay))
    }

    func apply(to phrases: [PhraseItem], chunkSize: Int = 400) -> [PhraseItem] {
        guard !phrases.isEmpty else { return [] }
        let overlays = notes(for: Set(phrases.map(\.word)), chunkSize: chunkSize)
        guard !overlays.isEmpty else { return phrases }
        return phrases.map { phrase in
            guard let overlay = overlays[phrase.word], !overlay.isEmpty else {
                return phrase
            }
            return phrase.withNotes(PhraseNoteOverlayRules.mergeNotes(phrase.notes, overlay))
        }
    }

    func note(for word: String) -> String? {
        guard let db else { return nil }
        let sql = "SELECT notes FROM \(Self.tableName) WHERE word = ? LIMIT 1"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (word as NSString).utf8String, -1, SQLITE_TRANSIENT_PHRASE_NOTE_OVERLAY)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return sqlite3_column_text(stmt, 0).map { String(cString: $0) }?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func notes(for words: Set<String>, chunkSize: Int = 400) -> [String: String] {
        guard let db, !words.isEmpty else { return [:] }
        let orderedWords = Array(words)
        var overlays: [String: String] = [:]
        for start in stride(from: 0, to: orderedWords.count, by: chunkSize) {
            let chunk = Array(orderedWords[start..<min(start + chunkSize, orderedWords.count)])
            let placeholders = Array(repeating: "?", count: chunk.count).joined(separator: ",")
            let sql = "SELECT word, notes FROM \(Self.tableName) WHERE word IN (\(placeholders))"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { continue }
            defer { sqlite3_finalize(stmt) }
            for (index, word) in chunk.enumerated() {
                sqlite3_bind_text(stmt, Int32(index + 1), (word as NSString).utf8String, -1, SQLITE_TRANSIENT_PHRASE_NOTE_OVERLAY)
            }
            while sqlite3_step(stmt) == SQLITE_ROW {
                guard let wordPtr = sqlite3_column_text(stmt, 0) else { continue }
                let word = String(cString: wordPtr)
                let notes = sqlite3_column_text(stmt, 1).map { String(cString: $0) }?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !notes.isEmpty {
                    overlays[word] = notes
                }
            }
        }
        return overlays
    }
}
