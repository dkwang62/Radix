import Foundation

/// Keeps a verified pre-restore document until the restore or its rollback is durable.
struct RestoreRollbackJournal {
    private struct Entry: Codable {
        var version = 1
        let snapshotFilename: String
    }

    enum Stage: Sendable {
        case snapshot, intent, restored, retired
    }

    let directoryURL: URL
    var fileManager: FileManager = .default

    private var intentURL: URL { directoryURL.appendingPathComponent("intent.json") }
    private var snapshotURL: URL { directoryURL.appendingPathComponent("rollback.radixbackup") }

    var isPending: Bool { fileManager.fileExists(atPath: intentURL.path) }

    func requireNoPendingRestore() throws {
        guard !isPending else {
            throw failure("Finish recovering the interrupted backup restore before changing data.")
        }
    }

    func begin(snapshotData: Data, validate: (Data) throws -> Void,
               afterStage: (Stage) throws -> Void = { _ in }) throws {
        try requireNoPendingRestore()
        try validate(snapshotData)
        if fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.removeItem(at: directoryURL)
        }
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try snapshotData.write(to: snapshotURL, options: .atomic)
        try synchronize(snapshotURL)
        try validate(Data(contentsOf: snapshotURL, options: .mappedIfSafe))
        try afterStage(.snapshot)

        let entry = Entry(snapshotFilename: snapshotURL.lastPathComponent)
        try JSONEncoder().encode(entry).write(to: intentURL, options: .atomic)
        try synchronize(intentURL)
        try afterStage(.intent)
    }

    func rollbackData() throws -> Data {
        let entry = try readEntry()
        let url = directoryURL.appendingPathComponent(entry.snapshotFilename)
        guard url.standardizedFileURL.deletingLastPathComponent() == directoryURL.standardizedFileURL,
              fileManager.fileExists(atPath: url.path) else {
            throw failure("The interrupted restore recovery document is missing.")
        }
        return try Data(contentsOf: url, options: .mappedIfSafe)
    }

    func finish(afterStage: (Stage) throws -> Void = { _ in }) throws {
        guard isPending else { return }
        try afterStage(.restored)
        try fileManager.removeItem(at: intentURL)
        try afterStage(.retired)
        try? fileManager.removeItem(at: snapshotURL)
        try? fileManager.removeItem(at: directoryURL)
    }

    private func readEntry() throws -> Entry {
        guard isPending else { throw failure("No interrupted backup restore needs recovery.") }
        let entry = try JSONDecoder().decode(Entry.self, from: Data(contentsOf: intentURL))
        guard entry.version == 1, entry.snapshotFilename == snapshotURL.lastPathComponent else {
            throw failure("The interrupted restore recovery record is invalid.")
        }
        return entry
    }

    private func synchronize(_ url: URL) throws {
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.synchronize()
    }

    private func failure(_ message: String) -> NSError {
        NSError(domain: "Radix.RestoreRollback", code: 1,
                userInfo: [NSLocalizedDescriptionKey: message])
    }
}
