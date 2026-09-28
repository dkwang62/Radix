import Foundation
import SQLite3
import XCTest
@testable import Radix

final class PhraseRepositoryMigrationTests: XCTestCase {
    @MainActor
    func testBackgroundPageGridPreservesPhrasesAndInvalidatesAfterHiding() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let suite = "RadixPageGridTests-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
        }
        let store = RadixStore(preferences: RadixPreferences(defaults: defaults), savedPageImageStore: SavedPageImageStore(directoryURL: directory.appendingPathComponent("images")))
        try store.phraseRepo.openForTesting(at: directory.appendingPathComponent("phrases.sqlite"))
        try store.phraseRepo.addPhrasesAdditively([PhraseItem(word: "你好", pinyin: "nǐ hǎo", meanings: "hello")])
        let page = CharacterCollection(id: UUID(), name: "Page", characters: ["你", "好", "啊", "你", "好"], createdAt: Date(), sourceType: .manual, isFavorite: false)
        store.allCollections = [page]
        store.selectBrowseCollection(id: page.id)
        XCTAssertNil(store.browsePageGridItemCache[page.id])
        await store.prepareBrowsePageGrid(for: page.id)
        let prepared = try XCTUnwrap(store.browsePageGridItemCache[page.id])
        XCTAssertEqual(prepared.allItems.map(\.offset), [0, 2, 3])
        XCTAssertEqual(prepared.uniqueItems.map(\.offset), [0, 2])
        XCTAssertEqual(prepared.tiles[0]?.phrase.word, "你好")

        store.setCollectionPhraseHidden(collectionID: page.id, phraseWord: "你好", hidden: true)
        XCTAssertNil(store.browsePageGridItemCache[page.id])
        await store.prepareBrowsePageGrid(for: page.id)
        XCTAssertTrue(try XCTUnwrap(store.browsePageGridItemCache[page.id]).tiles.isEmpty)
        XCTAssertEqual(store.browsePageGridItemCache[page.id]?.allItems.map(\.offset), [0, 1, 2, 3, 4])
    }

    @MainActor
    func testDeferredViewSaveCannotOverwriteNewerPageEdit() async throws {
        let suite = "RadixPageViewTests-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = RadixStore(preferences: RadixPreferences(defaults: defaults))
        let page = CharacterCollection(id: UUID(), name: "Original", characters: ["你", "好"], createdAt: Date(), sourceType: .manual, isFavorite: false)
        store.allCollections = [page]
        store.persistCollections()
        store.selectBrowseCollection(id: page.id)
        XCTAssertNotNil(store.viewedCollectionsPersistenceTask)
        var edited = try XCTUnwrap(store.collection(id: page.id))
        edited.name = "Edited"
        store.saveCollection(edited)
        try await Task.sleep(for: .milliseconds(300))
        let data = try XCTUnwrap(defaults.data(forKey: RadixPreferenceKey.collections))
        let saved = try JSONDecoder().decode([CharacterCollection].self, from: data)
        XCTAssertEqual(saved.first?.name, "Edited")
        XCTAssertNotNil(saved.first?.lastViewedAt)
    }

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
