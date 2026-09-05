import Foundation
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
            source.replaceAll(records)

            try source.backupDatabase(to: backupURL)
            try SentenceLibraryStore.validateSentenceDatabase(at: backupURL)

            let restored = makeStore(at: restoredURL)
            try restored.restoreDatabase(from: backupURL)
            #expect(Set(restored.fetchAll(migratingLegacy: { [] }).map(\.id)) == Set(records.map(\.id)))
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

    private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RadixSentenceLibraryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory)
    }
}
