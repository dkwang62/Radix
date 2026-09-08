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

    @Test("Page queries correlate page and source type on the same source")
    func pageQueriesCorrelateSourceRelationships() throws {
        try withTemporaryDirectory { directory in
            let pageA = UUID(uuidString: "00000000-0000-0000-0000-000000000611")!
            let pageB = UUID(uuidString: "00000000-0000-0000-0000-000000000612")!
            let source: (UUID, SentenceExampleSourceType) -> SentenceExampleSourceReference = { pageID, type in
                SentenceExampleSourceReference(
                    sourceType: type,
                    sourceID: pageID.uuidString,
                    sourceTitle: type.rawValue,
                    sourcePageID: pageID,
                    practicePackID: nil,
                    practiceItemID: nil
                )
            }
            let record = SentenceExampleRecord(
                chinese: "同一句话来自两个不同页面。",
                sources: [source(pageA, .ocrSource), source(pageB, .aiCleanedPage)]
            )
            let store = makeStore(at: directory.appendingPathComponent("sentences.sqlite"))
            try store.replaceAll([record])

            let cases: [(UUID, SentenceExampleSourceType?, Bool)] = [
                (pageA, nil, true),
                (pageA, .ocrSource, true),
                (pageA, .aiCleanedPage, false),
                (pageB, nil, true),
                (pageB, .ocrSource, false),
                (pageB, .aiCleanedPage, true)
            ]
            for (pageID, sourceType, shouldMatch) in cases {
                let result = store.query(
                    SentenceExampleQuery(scope: .page(pageID, sourceType)),
                    migratingLegacy: { [] }
                )
                #expect(result.records == (shouldMatch ? [record] : []))
                #expect(result.totalCount == (shouldMatch ? 1 : 0))
            }
        }
    }

    @Test("Paged queries clamp before fetching after result-count changes")
    func pagedQueriesReturnAValidPageAndCountTogether() throws {
        try withTemporaryDirectory { directory in
            let store = makeStore(at: directory.appendingPathComponent("sentences.sqlite"))
            var records = (1...20).map { index in
                sentence(
                    chinese: "测试句子\(index)。",
                    english: "Sentence \(index).",
                    isFavorited: index <= 11
                )
            }
            try store.replaceAll(records)

            func page(scope: SentenceExampleQueryScope, requestedIndex: Int) -> SentenceExamplePageQueryResult {
                store.queryPage(
                    SentenceExampleQuery(scope: scope),
                    requestedPageIndex: requestedIndex,
                    pageSize: 10,
                    migratingLegacy: { [] }
                )
            }

            #expect(page(scope: .favorites, requestedIndex: 1).pageIndex == 1)
            #expect(page(scope: .favorites, requestedIndex: 1).records.count == 1)
            #expect(page(scope: .all, requestedIndex: 1).records.count == 10)

            records[10].isFavorited = false
            try store.replace([records[10]])
            let afterUnfavorite = page(scope: .favorites, requestedIndex: 1)
            #expect(afterUnfavorite.pageIndex == 0)
            #expect(afterUnfavorite.totalCount == 10)
            #expect(afterUnfavorite.records.count == 10)

            try store.delete(id: records[19].id)
            let afterDelete = page(scope: .all, requestedIndex: 1)
            #expect(afterDelete.pageIndex == 1)
            #expect(afterDelete.totalCount == 19)
            #expect(afterDelete.records.count == 9)

            try store.replaceAll(Array(records.prefix(11)))
            try store.delete(id: records[10].id)
            let afterBoundaryDelete = page(scope: .all, requestedIndex: 1)
            #expect(afterBoundaryDelete.pageIndex == 0)
            #expect(afterBoundaryDelete.totalCount == 10)
            #expect(afterBoundaryDelete.records.count == 10)

            for total in [0, 1, 10, 11, 20] {
                try store.replaceAll(Array(records.prefix(total)))
                let result = page(scope: .all, requestedIndex: 2)
                let expectedIndex = total > 10 ? (total - 1) / 10 : 0
                #expect(result.pageIndex == expectedIndex)
                #expect(result.totalCount == total)
                #expect(result.records.count == min(10, max(0, total - expectedIndex * 10)))
            }
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

    @Test("Deleting pages reconciles sentence sources atomically")
    func deletingPagesReconcilesSentenceSources() throws {
        try withTemporaryDirectory { directory in
            let store = makeStore(at: directory.appendingPathComponent("sentences.sqlite"))
            let rootID = UUID(uuidString: "00000000-0000-0000-0000-000000000120")!
            let descendantID = UUID(uuidString: "00000000-0000-0000-0000-000000000121")!
            let survivingID = UUID(uuidString: "00000000-0000-0000-0000-000000000122")!
            let source: (UUID, String) -> SentenceExampleSourceReference = { pageID, title in
                SentenceExampleSourceReference(
                    sourceType: .aiCleanedPage,
                    sourceID: pageID.uuidString,
                    sourceTitle: title,
                    sourcePageID: pageID,
                    practicePackID: nil,
                    practiceItemID: nil
                )
            }
            let rootOnly = SentenceExampleRecord(chinese: "只来自原始页面。", sources: [source(rootID, "Root")])
            let descendantOnly = SentenceExampleRecord(chinese: "只来自更正页面。", sources: [source(descendantID, "Corrected")])
            let shared = SentenceExampleRecord(
                chinese: "也来自保留页面。",
                sources: [source(rootID, "Root"), source(survivingID, "Survivor")]
            )
            let favorite = SentenceExampleRecord(
                chinese: "收藏句子会保留。",
                sources: [source(descendantID, "Corrected")],
                isFavorited: true
            )
            try store.replaceAll([rootOnly, descendantOnly, shared, favorite])

            let result = try store.reconcileSources(
                removingPageIDs: [rootID, descendantID],
                migratingLegacy: { [] }
            )

            #expect(result == SentencePageSourceReconciliationResult(updatedCount: 2, deletedCount: 2))
            #expect(store.fetch(id: rootOnly.id, migratingLegacy: { [] }) == nil)
            #expect(store.fetch(id: descendantOnly.id, migratingLegacy: { [] }) == nil)
            #expect(store.fetch(id: shared.id, migratingLegacy: { [] })?.sources == [source(survivingID, "Survivor")])
            #expect(store.fetch(id: favorite.id, migratingLegacy: { [] })?.sources.isEmpty == true)
            #expect(store.fetch(id: favorite.id, migratingLegacy: { [] })?.isFavorited == true)
            #expect(shared.firstAvailableSourcePageID(in: [survivingID]) == survivingID)
        }
    }

    @Test("Page-source cleanup batches IDs, includes hidden sentences and deduplicates shared matches")
    func deletingManyPagesIncludesHiddenRecords() throws {
        try withTemporaryDirectory { directory in
            let store = makeStore(at: directory.appendingPathComponent("sentences.sqlite"))
            let ids = (0..<121).map { _ in UUID() }
            let survivor = UUID()
            func source(_ id: UUID) -> SentenceExampleSourceReference {
                SentenceExampleSourceReference(sourceType: .aiCleanedPage, sourceID: id.uuidString,
                    sourceTitle: nil, sourcePageID: id, practicePackID: nil, practiceItemID: nil)
            }
            let singles = ids.enumerated().map { index, id in
                SentenceExampleRecord(chinese: "Sentence \(index)", sources: [source(id)],
                    isFavorited: index == 0, isHidden: index < 2)
            }
            let shared = SentenceExampleRecord(chinese: "Shared", sources: ids.map(source) + [source(survivor)])
            let unrelated = SentenceExampleRecord(chinese: "Unrelated", sources: [source(survivor)])
            try store.replaceAll(singles + [shared, unrelated])
            let result = try store.reconcileSources(removingPageIDs: Set(ids), migratingLegacy: { [] })
            #expect(result == SentencePageSourceReconciliationResult(updatedCount: 2, deletedCount: 120))
            #expect(store.fetchAll(migratingLegacy: { [] }).count == 3)
            #expect(store.fetch(id: singles[0].id, migratingLegacy: { [] })?.isHidden == true)
            #expect(store.fetch(id: singles[0].id, migratingLegacy: { [] })?.isFavorited == true)
            #expect(store.fetch(id: singles[0].id, migratingLegacy: { [] })?.sources.isEmpty == true)
            #expect(store.fetch(id: singles[1].id, migratingLegacy: { [] }) == nil)
            #expect(store.fetch(id: shared.id, migratingLegacy: { [] })?.sources == [source(survivor)])
            #expect(store.fetch(id: unrelated.id, migratingLegacy: { [] }) == unrelated)
            #expect(try store.reconcileSources(removingPageIDs: Set(ids), migratingLegacy: { [] }) ==
                SentencePageSourceReconciliationResult(updatedCount: 0, deletedCount: 0))
        }
    }

    @Test("Complete AI-cleaned replacement removes obsolete sources and preserves retained sentences")
    func completeAICleanedReplacementReconcilesSentenceSources() throws {
        try withTemporaryDirectory { directory in
            let store = makeStore(at: directory.appendingPathComponent("sentences.sqlite"))
            let oldPage = UUID(uuidString: "00000000-0000-0000-0000-000000000701")!
            let otherOldPage = UUID(uuidString: "00000000-0000-0000-0000-000000000702")!
            let newPage = UUID(uuidString: "00000000-0000-0000-0000-000000000703")!
            let source: (UUID, SentenceExampleSourceType) -> SentenceExampleSourceReference = { pageID, type in
                SentenceExampleSourceReference(
                    sourceType: type,
                    sourceID: pageID.uuidString,
                    sourceTitle: type.rawValue,
                    sourcePageID: pageID,
                    practicePackID: nil,
                    practiceItemID: nil
                )
            }
            let obsolete = SentenceExampleRecord(chinese: "旧页面独有。", sources: [source(oldPage, .aiCleanedPage)])
            let favorite = SentenceExampleRecord(
                chinese: "收藏句子保留。",
                sources: [source(otherOldPage, .aiCleanedPage)],
                isFavorited: true
            )
            let shared = SentenceExampleRecord(
                chinese: "其他来源保留。",
                sources: [source(oldPage, .aiCleanedPage), source(oldPage, .ocrSource)]
            )
            let unrelated = SentenceExampleRecord(chinese: "普通句子不变。", sources: [source(oldPage, .userAdded)])
            let replacement = SentenceExampleRecord(chinese: "保留页面的新句子。", sources: [source(oldPage, .aiCleanedPage)])
            let differentReplacement = SentenceExampleRecord(chinese: "新页面句子。", sources: [source(newPage, .aiCleanedPage)])
            try store.replaceAll([obsolete, favorite, shared, unrelated])

            try store.replaceAICleanedPageSources(with: [replacement], migratingLegacy: { [] })

            #expect(store.fetch(id: obsolete.id, migratingLegacy: { [] }) == nil)
            #expect(store.fetch(id: favorite.id, migratingLegacy: { [] })?.sources.isEmpty == true)
            #expect(store.fetch(id: favorite.id, migratingLegacy: { [] })?.isFavorited == true)
            #expect(store.fetch(id: shared.id, migratingLegacy: { [] })?.sources == [source(oldPage, .ocrSource)])
            #expect(store.fetch(id: unrelated.id, migratingLegacy: { [] }) == unrelated)
            #expect(store.fetch(normalizedKey: replacement.normalizedChineseKey, migratingLegacy: { [] }) == replacement)

            try store.replaceAICleanedPageSources(with: [differentReplacement], migratingLegacy: { [] })

            #expect(store.fetch(normalizedKey: replacement.normalizedChineseKey, migratingLegacy: { [] }) == nil)
            #expect(store.fetch(normalizedKey: differentReplacement.normalizedChineseKey, migratingLegacy: { [] }) == differentReplacement)
            #expect(store.fetch(id: favorite.id, migratingLegacy: { [] })?.isFavorited == true)

            try store.replaceAICleanedPageSources(with: [], migratingLegacy: { [] })

            #expect(store.fetch(normalizedKey: differentReplacement.normalizedChineseKey, migratingLegacy: { [] }) == nil)
            #expect(store.fetch(id: favorite.id, migratingLegacy: { [] })?.isFavorited == true)
            #expect(store.fetch(id: shared.id, migratingLegacy: { [] })?.sources == [source(oldPage, .ocrSource)])
            #expect(store.fetch(id: unrelated.id, migratingLegacy: { [] }) == unrelated)
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
