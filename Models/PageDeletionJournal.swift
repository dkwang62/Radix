import Foundation

/// A confirmed deletion is replayed to completion before normal work resumes.
/// Store only identities: replay must not overwrite unrelated, newer learning data.
struct PageDeletionJournal {
    struct Entry: Codable {
        var version = 1
        let pageIDs: Set<UUID>
        let practicePackIDs: Set<String>
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
            throw failure("Finish the interrupted page deletion using Retry before importing or restoring data.")
        }
    }

    func delete(pageIDs: Set<UUID>, afterStage: (Stage) throws -> Void = { _ in }) throws {
        try requireNoPendingDeletion()
        guard !pageIDs.isEmpty else { return }
        // Decode/encode every affected preference before committing the intent.
        _ = try preferenceChanges(removing: pageIDs)
        let packs = ConversationPracticeStore(preferences: studyPreferences).importedPacks
        let packIDs = Set(packs.filter { $0.sourceLink?.isLinked(toAnyPageID: pageIDs) == true }.map(\.packID))
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(Entry(pageIDs: pageIDs, practicePackIDs: packIDs)).write(to: url, options: .atomic)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.synchronize()
        try afterStage(.journal)
        try recover(afterStage: afterStage)
    }

    func recover(afterStage: (Stage) throws -> Void = { _ in }) throws {
        guard isPending else { return }
        let entry = try JSONDecoder().decode(Entry.self, from: Data(contentsOf: url))
        guard entry.version == 1, !entry.pageIDs.isEmpty else {
            throw failure("The pending page deletion record is invalid. Your remaining data has not been cleared.")
        }
        let changes = try preferenceChanges(removing: entry.pageIDs)
        try reconcileSentences(entry.pageIDs)
        try afterStage(.sentences)
        for (store, key, data) in changes { store.set(data, forKey: key) }
        if let value = preferences.string(forKey: RadixPreferenceKey.selectedAICollection),
           let id = UUID(uuidString: value), entry.pageIDs.contains(id) {
            preferences.removeObject(forKey: RadixPreferenceKey.selectedAICollection)
        }
        if let topic = preferences.string(forKey: RadixPreferenceKey.conversationPracticeTopic),
           entry.practicePackIDs.contains(topic) {
            preferences.set(ConversationPracticeTopic.generalGreetings.id, forKey: RadixPreferenceKey.conversationPracticeTopic)
        }
        // UserDefaults writes asynchronously. Never retire intent before its flush.
        try flushPreferences()
        try afterStage(.preferences)
        for id in entry.pageIDs { try removeImage(id) }
        try afterStage(.images)
        try FileManager.default.removeItem(at: url)
    }

    private func preferenceChanges(removing ids: Set<UUID>) throws -> [(any RadixPreferenceStore, String, Data)] {
        var changes: [(any RadixPreferenceStore, String, Data)] = []
        func filter<T: Codable>(_ type: T.Type, store: any RadixPreferenceStore, key: String,
                                removing shouldRemove: (T) -> Bool) throws {
            guard let value = store.object(forKey: key) else { return }
            guard let data = value as? Data else { throw failure("Saved page data could not be read (\(key)).") }
            let existing = try JSONDecoder().decode([T].self, from: data)
            let retained = existing.filter { !shouldRemove($0) }
            changes.append((store, key, try JSONEncoder().encode(retained)))
        }
        try filter(CharacterCollection.self, store: preferences, key: RadixPreferenceKey.collections) { ids.contains($0.id) }
        try filter(ConversationPracticePack.self, store: studyPreferences, key: RadixPreferenceKey.importedConversationPracticePacks) {
            $0.sourceLink?.isLinked(toAnyPageID: ids) == true
        }
        try filter(PagePhraseExtractionRecord.self, store: studyPreferences, key: RadixPreferenceKey.pagePhraseExtractions) {
            ids.contains($0.sourcePageID)
        }
        try filter(AICleanedPageRecord.self, store: studyPreferences, key: RadixPreferenceKey.aiCleanedPages) {
            ids.contains($0.sourcePageID)
        }
        return changes
    }

    private func failure(_ message: String) -> NSError {
        NSError(domain: "Radix.PageDeletion", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
