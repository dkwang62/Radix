import Foundation
import SQLite3

private let SQLITE_TRANSIENT_STROKES = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

protocol StrokeDataLookup: AnyObject {
    func strokeJSON(for character: String) -> String?
}

final class CharacterStrokeRepository: StrokeDataLookup, @unchecked Sendable {
    private var db: OpaquePointer?
    private let lock = NSLock()

    init() {
        guard let url = Bundle.main.url(forResource: "character_strokes", withExtension: "db") else {
            strokeDebugLog("Missing bundled character_strokes.db")
            return
        }

        if sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
            strokeDebugLog("Unable to open character_strokes.db")
            db = nil
        }
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    func strokeJSON(for character: String) -> String? {
        let trimmed = character.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 1, let db else { return nil }
        lock.lock()
        defer { lock.unlock() }

        let sql = "SELECT data FROM strokes WHERE character = ? LIMIT 1"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, (trimmed as NSString).utf8String, -1, SQLITE_TRANSIENT_STROKES)

        guard sqlite3_step(statement) == SQLITE_ROW,
              let dataPointer = sqlite3_column_text(statement, 0) else {
            return nil
        }

        let json = String(cString: dataPointer)
        guard StrokeCharacterData(jsonString: json) != nil else {
            strokeDebugLog("Invalid stroke JSON for \(trimmed)")
            return nil
        }

        return json
    }
}

final class GeneratedStrokeRepository: StrokeDataLookup, @unchecked Sendable {
    private var db: OpaquePointer?
    private let lock = NSLock()

    init(fileManager: FileManager = .default) {
        guard let directory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            strokeDebugLog("Unable to locate Documents directory for generated stroke cache")
            return
        }

        let url = directory.appendingPathComponent("user_character_strokes.db")
        if sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) != SQLITE_OK {
            strokeDebugLog("Unable to open generated stroke cache at \(url.path)")
            db = nil
            return
        }

        createTableIfNeeded()
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    func strokeJSON(for character: String) -> String? {
        let trimmed = character.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 1, let db else { return nil }
        lock.lock()
        defer { lock.unlock() }

        let sql = "SELECT data FROM strokes WHERE character = ? LIMIT 1"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            strokeDebugLog("Unable to prepare generated stroke lookup")
            return nil
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, (trimmed as NSString).utf8String, -1, SQLITE_TRANSIENT_STROKES)

        guard sqlite3_step(statement) == SQLITE_ROW,
              let dataPointer = sqlite3_column_text(statement, 0) else {
            return nil
        }

        let json = String(cString: dataPointer)
        guard StrokeCharacterData(jsonString: json) != nil else {
            strokeDebugLog("Invalid generated stroke JSON for \(trimmed)")
            return nil
        }

        return json
    }

    func storeStrokeJSON(_ json: String, for character: String) {
        let trimmed = character.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 1,
              StrokeCharacterData(jsonString: json) != nil,
              let db else {
            return
        }

        lock.lock()
        defer { lock.unlock() }

        let sql = """
        INSERT OR REPLACE INTO strokes(character, data, generated_at)
        VALUES (?, ?, ?)
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            strokeDebugLog("Unable to prepare generated stroke insert")
            return
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, (trimmed as NSString).utf8String, -1, SQLITE_TRANSIENT_STROKES)
        sqlite3_bind_text(statement, 2, (json as NSString).utf8String, -1, SQLITE_TRANSIENT_STROKES)
        sqlite3_bind_double(statement, 3, Date().timeIntervalSince1970)

        if sqlite3_step(statement) != SQLITE_DONE {
            strokeDebugLog("Unable to store generated stroke JSON for \(trimmed)")
        }
    }

    private func createTableIfNeeded() {
        guard let db else { return }
        let sql = """
        CREATE TABLE IF NOT EXISTS strokes (
            character TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            generated_at REAL NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_generated_strokes_character ON strokes(character);
        """
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            strokeDebugLog("Unable to create generated stroke cache table")
        }
    }
}

final class CompositeStrokeRepository: StrokeDataLookup {
    private let bundledRepository: CharacterStrokeRepository
    private let generatedRepository: GeneratedStrokeRepository

    init(bundledRepository: CharacterStrokeRepository, generatedRepository: GeneratedStrokeRepository) {
        self.bundledRepository = bundledRepository
        self.generatedRepository = generatedRepository
    }

    func strokeJSON(for character: String) -> String? {
        bundledRepository.strokeJSON(for: character) ?? generatedRepository.strokeJSON(for: character)
    }
}
