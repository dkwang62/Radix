import Foundation
import SQLite3
import Testing
@testable import RadixCore

@Suite("Page deletion journal recovery")
struct PageDeletionJournalTests {
    enum Interruption: Error { case stopped }

    @Test("Restart finishes deletion after every durable boundary", arguments: PageDeletionJournal.Stage.allCases)
    func restart(stage: PageDeletionJournal.Stage) throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let journal = fixture.journal()
        #expect(throws: Interruption.self) {
            try journal.delete(pageIDs: fixture.deletedIDs) {
                if $0 == stage { throw Interruption.stopped }
            }
        }
        #expect(journal.isPending)
        #expect(throws: (any Error).self) { try journal.requireNoPendingDeletion() }
        // Discard volatile preferences and reopen SQLite, as a new process would.
        try fixture.preferences.reload()
        let reopened = fixture.journal()
        try reopened.recover()
        try reopened.recover()
        try fixture.verifyDeletion()
        #expect(!reopened.isPending)

        // An explicit restore may reintroduce the same UUID after completion.
        try fixture.preferences.save([fixture.root], key: RadixPreferenceKey.collections)
        try fixture.preferences.flushPageDeletion()
        try reopened.recover()
        #expect(try fixture.preferences.read([CharacterCollection].self, key: RadixPreferenceKey.collections) == [fixture.root])
    }

    @Test("Preference flush failure retains intent and repairs lost volatile writes")
    func flushFailure() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let journal = fixture.journal(flush: { throw Interruption.stopped })
        #expect(throws: Interruption.self) { try journal.delete(pageIDs: fixture.deletedIDs) }
        #expect(journal.isPending)
        try fixture.preferences.reload()
        #expect(try fixture.preferences.read([CharacterCollection].self, key: RadixPreferenceKey.collections).count == 3)
        try fixture.journal().recover()
        try fixture.verifyDeletion()
    }

    @Test("Partial image deletion is idempotent and preserves other images")
    func imageFailure() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        var attempts = 0
        let journal = fixture.journal(remove: { id in
            attempts += 1
            if attempts == 2 { throw Interruption.stopped }
            try fixture.removeImage(id)
        })
        #expect(throws: Interruption.self) { try journal.delete(pageIDs: fixture.deletedIDs) }
        #expect(journal.isPending)
        try fixture.preferences.reload()
        try fixture.journal().recover()
        try fixture.verifyDeletion()
    }

    @Test("SQLite lock leaves preferences and images unchanged and permits recovery")
    func sqliteFailure() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        var db: OpaquePointer?
        #expect(sqlite3_open(fixture.databaseURL.path, &db) == SQLITE_OK)
        defer { sqlite3_close(db) }
        #expect(sqlite3_exec(db, "BEGIN EXCLUSIVE", nil, nil, nil) == SQLITE_OK)
        let journal = fixture.journal()
        #expect(throws: (any Error).self) { try journal.delete(pageIDs: fixture.deletedIDs) }
        #expect(journal.isPending)
        #expect(try fixture.preferences.read([CharacterCollection].self, key: RadixPreferenceKey.collections).count == 3)
        #expect(FileManager.default.fileExists(atPath: fixture.imageURL(fixture.root.id).path))
        #expect(sqlite3_exec(db, "ROLLBACK", nil, nil, nil) == SQLITE_OK)
        try fixture.journal().recover()
        try fixture.verifyDeletion()
    }

    @Test("Invalid preferences fail before intent and corrupt journals are retained")
    func invalidData() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let journal = fixture.journal()
        fixture.preferences.set(Data("broken".utf8), forKey: RadixPreferenceKey.aiCleanedPages)
        #expect(throws: (any Error).self) { try journal.delete(pageIDs: fixture.deletedIDs) }
        #expect(!journal.isPending)
        #expect(fixture.sentences().fetchAll(migratingLegacy: { [] }).count == 4)
        try Data("broken".utf8).write(to: journal.url)
        #expect(throws: (any Error).self) { try journal.recover() }
        #expect(journal.isPending)
        #expect(fixture.sentences().fetchAll(migratingLegacy: { [] }).count == 4)
    }

    @Test("Journal creation failure cannot start deletion")
    func journalWriteFailure() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let blocker = fixture.directory.appendingPathComponent("file")
        try Data().write(to: blocker)
        var journal = fixture.journal()
        journal = PageDeletionJournal(url: blocker.appendingPathComponent("journal.json"),
            preferences: fixture.preferences, studyPreferences: fixture.preferences,
            reconcileSentences: { _ in Issue.record("Must not mutate SQLite") },
            flushPreferences: { Issue.record("Must not mutate preferences") },
            removeImage: { _ in Issue.record("Must not remove images") })
        #expect(throws: (any Error).self) { try journal.delete(pageIDs: fixture.deletedIDs) }
        #expect(fixture.sentences().fetchAll(migratingLegacy: { [] }).count == 4)
    }
}

private final class Fixture {
    let directory: URL
    let preferences: DiskPreferences
    let root: CharacterCollection
    let child: CharacterCollection
    let survivor: CharacterCollection
    let favorite: SentenceExampleRecord
    let shared: SentenceExampleRecord
    var deletedIDs: Set<UUID> { [root.id, child.id] }
    var databaseURL: URL { directory.appendingPathComponent("sentences.sqlite") }

    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        preferences = DiskPreferences(url: directory.appendingPathComponent("preferences.plist"))
        root = CharacterCollection(id: UUID(), name: "Root", characters: [], createdAt: Date(), sourceType: .manual, isFavorite: false)
        child = CharacterCollection(id: UUID(), name: "Child", characters: [], createdAt: Date(), sourceType: .manual, isFavorite: false, correctedFromCollectionID: root.id)
        survivor = CharacterCollection(id: UUID(), name: "Survivor", characters: [], createdAt: Date(), sourceType: .manual, isFavorite: true)
        func source(_ id: UUID) -> SentenceExampleSourceReference {
            SentenceExampleSourceReference(sourceType: .aiCleanedPage, sourceID: id.uuidString,
                sourceTitle: "Page", sourcePageID: id, practicePackID: nil, practiceItemID: nil)
        }
        favorite = SentenceExampleRecord(chinese: "Favorite", sources: [source(child.id)], isFavorited: true)
        shared = SentenceExampleRecord(chinese: "Shared", sources: [source(root.id), source(survivor.id)])
        try sentences().replaceAll([
            SentenceExampleRecord(chinese: "Root only", sources: [source(root.id)]),
            SentenceExampleRecord(chinese: "Child only", sources: [source(child.id)]), favorite, shared
        ])
        try preferences.save([root, child, survivor], key: RadixPreferenceKey.collections)
        preferences.set(child.id.uuidString, forKey: RadixPreferenceKey.selectedAICollection)
        preferences.set(child.id.uuidString, forKey: RadixPreferenceKey.conversationPracticeTopic)
        let artifacts = PageStudyArtifactStore(preferences: preferences)
        let packs = [root, child, survivor].map { page in
            ConversationPracticePack(packID: page.id.uuidString, version: "1", title: page.name,
                description: "", language: "zh-CN", sourceType: "test", createdFor: "Radix",
                sourceLink: .savedPage(id: page.id, title: page.name, createdAt: nil), entries: [])
        }
        ConversationPracticeStore(preferences: preferences).importedPacks = packs
        for page in [root, child, survivor] {
            artifacts.recordPhraseExtraction(pageID: page.id, title: page.name, words: ["word"], extractedAt: Date())
            artifacts.replaceCleanedPage(AICleanedPageRecord(sourcePageID: page.id, sourceTitle: page.name,
                cleanedTitle: page.name, cleanedChineseText: "text", sentences: [], createdAt: Date()))
            try Data([1, 2, 3]).write(to: imageURL(page.id))
        }
        preferences.set(Data([7]), forKey: RadixPreferenceKey.conversationPracticeProgress)
        preferences.set(Data([8]), forKey: "globalNotes")
        try preferences.flushPageDeletion()
    }

    func journal(flush: (() throws -> Void)? = nil, remove: ((UUID) throws -> Void)? = nil) -> PageDeletionJournal {
        let store = sentences()
        return PageDeletionJournal(url: directory.appendingPathComponent("journal.json"),
            preferences: preferences, studyPreferences: preferences,
            reconcileSentences: { _ = try store.reconcileSources(removingPageIDs: $0, migratingLegacy: { [] }) },
            flushPreferences: flush ?? { try self.preferences.flushPageDeletion() },
            removeImage: remove ?? { try self.removeImage($0) })
    }

    func sentences() -> SentenceLibraryStore {
        SentenceLibraryStore(databaseURL: databaseURL,
            canonicalize: { SentenceExampleRecord.upserting($0, into: []) }, simplify: { $0 },
            matchesSearchText: { _, _ in true })
    }

    func imageURL(_ id: UUID) -> URL { directory.appendingPathComponent("\(id).jpg") }
    func removeImage(_ id: UUID) throws {
        let url = imageURL(id)
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
    func cleanup() { try? FileManager.default.removeItem(at: directory) }

    func verifyDeletion() throws {
        try preferences.reload()
        #expect(try preferences.read([CharacterCollection].self, key: RadixPreferenceKey.collections) == [survivor])
        #expect(preferences.string(forKey: RadixPreferenceKey.selectedAICollection) == nil)
        #expect(preferences.string(forKey: RadixPreferenceKey.conversationPracticeTopic) == ConversationPracticeTopic.generalGreetings.id)
        #expect(PageStudyArtifactStore(preferences: preferences).cleanedPages.map(\.sourcePageID) == [survivor.id])
        #expect(PageStudyArtifactStore(preferences: preferences).phraseExtractions.map(\.sourcePageID) == [survivor.id])
        #expect(ConversationPracticeStore(preferences: preferences).importedPacks.map(\.packID) == [survivor.id.uuidString])
        #expect(preferences.data(forKey: RadixPreferenceKey.conversationPracticeProgress) == Data([7]))
        #expect(preferences.data(forKey: "globalNotes") == Data([8]))
        let store = sentences()
        #expect(store.fetchAll(migratingLegacy: { [] }).count == 2)
        #expect(store.fetch(id: favorite.id, migratingLegacy: { [] })?.isFavorited == true)
        #expect(store.fetch(id: favorite.id, migratingLegacy: { [] })?.sources == [])
        #expect(store.fetch(id: shared.id, migratingLegacy: { [] })?.sources.map(\.sourcePageID) == [survivor.id])
        for id in deletedIDs { #expect(!FileManager.default.fileExists(atPath: imageURL(id).path)) }
        #expect(FileManager.default.fileExists(atPath: imageURL(survivor.id).path))
    }
}

private final class DiskPreferences: RadixPreferenceStore {
    let url: URL
    private var values: [String: Any] = [:]
    init(url: URL) { self.url = url }
    func flushPageDeletion() throws {
        try PropertyListSerialization.data(fromPropertyList: values, format: .binary, options: 0).write(to: url, options: .atomic)
    }
    func reload() throws {
        values = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as! [String: Any]
    }
    func save<T: Encodable>(_ value: T, key: String) throws { set(try JSONEncoder().encode(value), forKey: key) }
    func read<T: Decodable>(_ type: T.Type, key: String) throws -> T { try JSONDecoder().decode(type, from: data(forKey: key)!) }
    func data(forKey key: String) -> Data? { values[key] as? Data }
    func string(forKey key: String) -> String? { values[key] as? String }
    func bool(forKey key: String) -> Bool { values[key] as? Bool ?? false }
    func integer(forKey key: String) -> Int { values[key] as? Int ?? 0 }
    func double(forKey key: String) -> Double { values[key] as? Double ?? 0 }
    func array(forKey key: String) -> [Any]? { values[key] as? [Any] }
    func dictionary(forKey key: String) -> [String: Any]? { values[key] as? [String: Any] }
    func object(forKey key: String) -> Any? { values[key] }
    func set(_ value: Any?, forKey key: String) { values[key] = value }
    func removeObject(forKey key: String) { values.removeValue(forKey: key) }
}
