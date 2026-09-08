import Foundation

/// Confirmed deletion replays to completion; preparation never mutates stores.
struct PageDeletionJournal {
    struct Entry: Codable, Sendable {
        var version = 1
        let pageIDs: Set<UUID>
        let practicePackIDs: Set<String>
    }

    struct Value: Equatable, Sendable {
        let key: String
        let data: Data?
    }

    struct Snapshot: Equatable, Sendable {
        let app: [Value]
        let study: [Value]
    }

    struct PreparedDeletion: Sendable {
        fileprivate let entry: Entry
        fileprivate let snapshot: Snapshot
        fileprivate let appChanges: [Value]
        fileprivate let studyChanges: [Value]
        var removedPracticePackIDs: Set<String> { entry.practicePackIDs }
    }

    enum Stage: CaseIterable, Sendable {
        case journal, sentences, preferences, images
    }

    let url: URL
    let preferences: any RadixPreferenceStore
    let studyPreferences: any RadixPreferenceStore
    let reconcileSentences: (Set<UUID>) throws -> Void
    let flushPreferences: () throws -> Void
    let removeImage: (UUID) throws -> Void

    var isPending: Bool { FileManager.default.fileExists(atPath: url.path) }

    func requireNoPendingDeletion() throws {
        guard !isPending else {
            throw Self.failure("Finish the interrupted page deletion using Retry before importing or restoring data.")
        }
    }

    func captureSnapshot() throws -> Snapshot {
        func values(_ store: any RadixPreferenceStore, keys: [String]) throws -> [Value] {
            try keys.map { key in
                let object = store.object(forKey: key)
                guard object == nil || object is Data else {
                    throw Self.failure("Saved page data could not be read (\(key)).")
                }
                return Value(key: key, data: object as? Data)
            }
        }
        return try Snapshot(
            app: values(preferences, keys: [RadixPreferenceKey.collections]),
            study: values(studyPreferences, keys: [RadixPreferenceKey.importedConversationPracticePacks,
                RadixPreferenceKey.pagePhraseExtractions, RadixPreferenceKey.aiCleanedPages])
        )
    }

    /// Only immutable data crosses to a worker; UserDefaults and commit stay with the owner.
    static func prepare(pageIDs: Set<UUID>, snapshot: Snapshot, previousPackIDs: Set<String> = []) throws -> PreparedDeletion {
        var appChanges: [Value] = []
        var studyChanges: [Value] = []
        var packIDs = previousPackIDs
        func filter<T: Codable>(_ type: T.Type, values: [Value], key: String,
                                removing shouldRemove: (T) -> Bool) throws -> Value? {
            guard let data = values.first(where: { $0.key == key })?.data else { return nil }
            let existing = try JSONDecoder().decode([T].self, from: data)
            let retained = existing.filter { !shouldRemove($0) }
            guard retained.count != existing.count else { return nil }
            return Value(key: key, data: try JSONEncoder().encode(retained))
        }
        if let change = try filter(CharacterCollection.self, values: snapshot.app, key: RadixPreferenceKey.collections,
                                   removing: { pageIDs.contains($0.id) }) { appChanges.append(change) }
        if let change = try filter(ConversationPracticePack.self, values: snapshot.study,
                                   key: RadixPreferenceKey.importedConversationPracticePacks, removing: {
            let removed = $0.sourceLink?.isLinked(toAnyPageID: pageIDs) == true
            if removed { packIDs.insert($0.packID) }
            return removed
        }) { studyChanges.append(change) }
        if let change = try filter(PagePhraseExtractionRecord.self, values: snapshot.study,
                                   key: RadixPreferenceKey.pagePhraseExtractions,
                                   removing: { pageIDs.contains($0.sourcePageID) }) { studyChanges.append(change) }
        if let change = try filter(AICleanedPageRecord.self, values: snapshot.study,
                                   key: RadixPreferenceKey.aiCleanedPages,
                                   removing: { pageIDs.contains($0.sourcePageID) }) { studyChanges.append(change) }
        return PreparedDeletion(entry: Entry(pageIDs: pageIDs, practicePackIDs: packIDs), snapshot: snapshot,
                                appChanges: appChanges, studyChanges: studyChanges)
    }

    func delete(pageIDs: Set<UUID>, afterStage: (Stage) throws -> Void = { _ in }) throws {
        try requireNoPendingDeletion()
        guard !pageIDs.isEmpty else { return }
        try commit(Self.prepare(pageIDs: pageIDs, snapshot: captureSnapshot()), afterStage: afterStage)
    }

    func commit(_ prepared: PreparedDeletion, afterStage: (Stage) throws -> Void = { _ in }) throws {
        try requireNoPendingDeletion()
        guard !prepared.entry.pageIDs.isEmpty else { return }
        guard try captureSnapshot() == prepared.snapshot else {
            throw Self.failure("Page data changed while preparing deletion. Your changes were kept. Please retry.")
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(prepared.entry).write(to: url, options: .atomic)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.synchronize()
        try afterStage(.journal)
        try complete(prepared, afterStage: afterStage)
    }

    func recover(afterStage: (Stage) throws -> Void = { _ in }) throws {
        guard isPending else { return }
        let entry = try JSONDecoder().decode(Entry.self, from: Data(contentsOf: url))
        guard entry.version == 1, !entry.pageIDs.isEmpty else {
            throw Self.failure("The pending page deletion record is invalid. Your remaining data has not been cleared.")
        }
        let prepared = try Self.prepare(pageIDs: entry.pageIDs, snapshot: captureSnapshot(), previousPackIDs: entry.practicePackIDs)
        try complete(prepared, afterStage: afterStage)
    }

    private func complete(_ prepared: PreparedDeletion, afterStage: (Stage) throws -> Void) throws {
        let entry = prepared.entry
        try reconcileSentences(entry.pageIDs)
        try afterStage(.sentences)
        for change in prepared.appChanges { preferences.set(change.data, forKey: change.key) }
        for change in prepared.studyChanges { studyPreferences.set(change.data, forKey: change.key) }
        if let value = preferences.string(forKey: RadixPreferenceKey.selectedAICollection),
           let id = UUID(uuidString: value), entry.pageIDs.contains(id) {
            preferences.removeObject(forKey: RadixPreferenceKey.selectedAICollection)
        }
        if let topic = preferences.string(forKey: RadixPreferenceKey.conversationPracticeTopic),
           entry.practicePackIDs.contains(topic) {
            preferences.set(ConversationPracticeTopic.generalGreetings.id, forKey: RadixPreferenceKey.conversationPracticeTopic)
        }
        // Retire intent only after both stores acknowledge persistence.
        try flushPreferences()
        try afterStage(.preferences)
        for id in entry.pageIDs { try removeImage(id) }
        try afterStage(.images)
        try FileManager.default.removeItem(at: url)
    }

    private static func failure(_ message: String) -> NSError {
        NSError(domain: "Radix.PageDeletion", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
