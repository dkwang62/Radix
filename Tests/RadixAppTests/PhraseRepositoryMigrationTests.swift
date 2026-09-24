import Foundation
import SQLite3
import XCTest
@testable import Radix

final class PhraseRepositoryMigrationTests: XCTestCase {
    func testOpeningLegacyDatabaseMergesTraditionalAndSimplifiedDuplicates() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let databaseURL = directory.appendingPathComponent("phrases_add.db")
        try createLegacyDatabase(at: databaseURL)

        let repository = PhraseRepository()
        try repository.openForTesting(at: databaseURL)
        defer { repository.close() }

        let phrases = repository.fetchAddedPhrases()
        XCTAssertEqual(phrases.count, 1)
        XCTAssertEqual(phrases[0].word, "关键时刻")
        XCTAssertEqual(phrases[0].notes, "Newer note\n\nOlder note")
        XCTAssertEqual(phrases[0].reviewStatus, .checked)
        XCTAssertEqual(phrases[0].lastReviewedAt, Date(timeIntervalSince1970: 40))
        XCTAssertEqual(phrases[0].addedAt, Date(timeIntervalSince1970: 10))
    }

    private func createLegacyDatabase(at url: URL) throws {
        var database: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil), SQLITE_OK)
        guard let database else { return }
        defer { sqlite3_close(database) }
        XCTAssertEqual(sqlite3_exec(database, "CREATE TABLE phrases (word TEXT PRIMARY KEY, pinyin TEXT, meanings TEXT, notes TEXT, added_at REAL, review_status TEXT, last_reviewed_at REAL)", nil, nil, nil), SQLITE_OK)
        XCTAssertEqual(sqlite3_exec(database, "INSERT INTO phrases VALUES ('關鍵時刻', 'guān jiàn shí kè', 'critical moment', 'Older note', 10, 'hidden', 20)", nil, nil, nil), SQLITE_OK)
        XCTAssertEqual(sqlite3_exec(database, "INSERT INTO phrases VALUES ('关键时刻', 'guān jiàn shí kè', 'turning point', 'Newer note', 30, 'checked', 40)", nil, nil, nil), SQLITE_OK)
    }
}
