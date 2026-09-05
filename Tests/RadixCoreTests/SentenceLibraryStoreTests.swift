import Foundation
import SQLite3
import Testing
@testable import RadixCore

@Suite("Sentence library SQLite persistence")
struct SentenceLibraryStoreTests {
    @Test("Legacy records migrate once and remain queryable from SQLite")
    func migratesLegacyRecords() throws {
        try withTemporaryDirectory { directory in
            let databaseURL = directory.appendingPathComponent("sentences.sqlite")
            let pageID = UUID(uuidString: "00000000-0000-0000-0000-000000000601")!
            let favorite = sentence(
                chinese: "我喜欢学习中文。",
                english: "I like studying Chinese.",
                isFavorited: true,
                source: SentenceExampleSourceReference(
                    sourceType: .aiCleanedPage,
                    sourceID: nil,
                    sourceTitle: "Lesson",
                    sourcePageID: pageID,
                    practicePackID: nil,
                    practiceItemID: nil
                )
            )
            let ordinary = sentence(chinese: "今天天气很好。", english: "The weather is good today.")
            var legacyReads = 0
            let store = makeStore(at: databaseURL)

            let migrated = store.fetchAll {
                legacyReads += 1
                return [favorite, ordinary]
            }

            #expect(migrated.count == 2)
            #expect(legacyReads == 1)
            #expect(store.query(
                SentenceExampleQuery(scope: .favorites, searchText: "Chinese"),
                migratingLegacy: { [] }
            ).records == [favorite])
            #expect(store.query(
                SentenceExampleQuery(scope: .page(pageID, .aiCleanedPage)),
                migratingLegacy: { [] }
            ).records == [favorite])

            let reopened = makeStore(at: databaseURL)
            #expect(reopened.fetchAll(migratingLegacy: { [] }).count == 2)
        }
    }

    @Test("Database backup restores the complete sentence records")
    func backupAndRestore() throws {
        try withTemporaryDirectory { directory in
            let sourceURL = directory.appendingPathComponent("source.sqlite")
            let backupURL = directory.appendingPathComponent("backup.sqlite")
            let restoredURL = directory.appendingPathComponent("restored.sqlite")
            let records = [
                sentence(chinese: "你好。", english: "Hello."),
                sentence(chinese: "再见。", english: "Goodbye.", isFavorited: true)
            ]
            let source = makeStore(at: sourceURL)
            try source.replaceAll(records)

            try source.backupDatabase(to: backupURL)
            try SentenceLibraryStore.validateSentenceDatabase(at: backupURL)

            let restored = makeStore(at: restoredURL)
            try restored.restoreDatabase(from: backupURL)
            #expect(Set(restored.fetchAll(migratingLegacy: { [] }).map(\.id)) == Set(records.map(\.id)))
        }
    }

    @Test("Malformed restore is rejected without changing the live library")
    func malformedRestorePreservesLibrary() throws {
        try withTemporaryDirectory { directory in
            let liveURL = directory.appendingPathComponent("live.sqlite")
            let malformedURL = directory.appendingPathComponent("malformed.sqlite")
            let live = makeStore(at: liveURL)
            let records = [
                sentence(chinese: "你好。", english: "Hello."),
                sentence(chinese: "再见。", english: "Goodbye.")
            ]
            try live.replaceAll(records)
            try createMalformedDatabase(at: malformedURL)

            #expect(throws: Error.self) {
                try SentenceLibraryStore.validateSentenceDatabase(at: malformedURL)
            }
            #expect(throws: Error.self) {
                try live.restoreDatabase(from: malformedURL)
            }
            #expect(Set(live.fetchAll(migratingLegacy: { [] }).map(\.id)) == Set(records.map(\.id)))
        }
    }

    @Test("Failed writes preserve the complete readable corpus")
    func failedWritePreservesCorpus() throws {
        try withTemporaryDirectory { directory in
            let databaseURL = directory.appendingPathComponent("sentences.sqlite")
            let store = makeStore(at: databaseURL)
            let records = [
                sentence(chinese: "你好。", english: "Hello."),
                sentence(chinese: "再见。", english: "Goodbye.")
            ]
            try store.replaceAll(records)

            var lockingDB: OpaquePointer?
            #expect(sqlite3_open_v2(databaseURL.path, &lockingDB, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK)
            guard let lockingDB else { return }
            defer { sqlite3_close(lockingDB) }
            #expect(sqlite3_exec(lockingDB, "BEGIN EXCLUSIVE", nil, nil, nil) == SQLITE_OK)

            #expect(throws: Error.self) {
                try store.upsert([sentence(chinese: "谢谢。", english: "Thanks.")])
            }
            sqlite3_exec(lockingDB, "ROLLBACK", nil, nil, nil)

            #expect(Set(store.fetchAll(migratingLegacy: { [] }).map(\.id)) == Set(records.map(\.id)))
        }
    }

    @Test("Changing a sentence key cannot replace another sentence")
    func normalizedKeyCollisionPreservesBothRecords() throws {
        try withTemporaryDirectory { directory in
            let store = makeStore(at: directory.appendingPathComponent("sentences.sqlite"))
            var first = sentence(chinese: "你好。", english: "Hello.")
            let second = sentence(chinese: "再见。", english: "Goodbye.", isFavorited: true)
            try store.replaceAll([first, second])

            first.chinese = second.chinese
            #expect(throws: Error.self) {
                try store.replace([first])
            }

            let remaining = store.fetchAll(migratingLegacy: { [] })
            #expect(Set(remaining.map(\.id)) == Set([first.id, second.id]))
            #expect(remaining.first(where: { $0.id == second.id })?.isFavorited == true)
        }
    }

    private func makeStore(at databaseURL: URL) -> SentenceLibraryStore {
        SentenceLibraryStore(
            databaseURL: databaseURL,
            canonicalize: { SentenceExampleRecord.upserting($0, into: []) },
            simplify: { $0 },
            matchesSearchText: { record, query in
                query.isEmpty || [record.chinese, record.english ?? ""]
                    .joined(separator: " ")
                    .localizedCaseInsensitiveContains(query)
            }
        )
    }

    private func sentence(
        chinese: String,
        english: String,
        isFavorited: Bool = false,
        source: SentenceExampleSourceReference? = nil
    ) -> SentenceExampleRecord {
        SentenceExampleRecord(
            chinese: chinese,
            english: english,
            sources: source.map { [$0] } ?? [],
            isFavorited: isFavorited
        )
    }

    private func createMalformedDatabase(at url: URL) throws {
        var database: OpaquePointer?
        guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK,
              let database
        else {
            throw NSError(domain: "RadixTests", code: 1)
        }
        defer { sqlite3_close(database) }
        guard sqlite3_exec(
            database,
            "CREATE TABLE sentence_examples (id TEXT, normalized_key TEXT, record_json BLOB)",
            nil,
            nil,
            nil
        ) == SQLITE_OK else {
            throw NSError(domain: "RadixTests", code: 2)
        }
    }

    private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RadixSentenceLibraryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory)
    }
}
