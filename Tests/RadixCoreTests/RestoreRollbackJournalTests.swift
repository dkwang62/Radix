import Foundation
import Testing
@testable import RadixCore

@Suite("Full restore rollback journal")
struct RestoreRollbackJournalTests {
    enum Interruption: Error { case stopped }

    @Test("Intent becomes pending only after a validated durable snapshot")
    func beginOrdering() throws {
        try withRestoreJournalDirectory { directory in
            let journal = RestoreRollbackJournal(directoryURL: directory.appendingPathComponent("restore"))
            #expect(throws: Interruption.self) {
                try journal.begin(snapshotData: Data("valid".utf8), validate: { data in
                    if data != Data("valid".utf8) { throw Interruption.stopped }
                }, afterStage: { if $0 == .snapshot { throw Interruption.stopped } })
            }
            #expect(!journal.isPending)

            try journal.begin(snapshotData: Data("valid".utf8), validate: { _ in })
            #expect(journal.isPending)
            #expect(try journal.rollbackData() == Data("valid".utf8))
            #expect(throws: (any Error).self) {
                try journal.begin(snapshotData: Data(), validate: { _ in })
            }
        }
    }

    @Test("Interrupted rollback remains retryable until durable restore finishes")
    func rollbackRetry() throws {
        try withRestoreJournalDirectory { directory in
            let journal = RestoreRollbackJournal(directoryURL: directory.appendingPathComponent("restore"))
            let original = Data("original-state".utf8)
            try journal.begin(snapshotData: original, validate: { _ in })

            #expect(throws: Interruption.self) {
                _ = try journal.rollbackData()
                throw Interruption.stopped
            }
            #expect(journal.isPending)
            #expect(try journal.rollbackData() == original)
            #expect(throws: Interruption.self) {
                try journal.finish { if $0 == .restored { throw Interruption.stopped } }
            }
            #expect(journal.isPending)
            try journal.finish()
            #expect(!journal.isPending)
            try journal.finish()
        }
    }

    @Test("Interruption after intent preserves the rollback document")
    func interruptionAfterIntent() throws {
        try withRestoreJournalDirectory { directory in
            let journal = RestoreRollbackJournal(directoryURL: directory.appendingPathComponent("restore"))
            let original = Data("original-state".utf8)
            #expect(throws: Interruption.self) {
                try journal.begin(snapshotData: original, validate: { _ in }) {
                    if $0 == .intent { throw Interruption.stopped }
                }
            }
            #expect(journal.isPending)
            let recovered = try journal.rollbackData()
            #expect(recovered == original)
        }
    }

    @Test("Corrupt intent or missing snapshot fails closed")
    func corruptState() throws {
        try withRestoreJournalDirectory { directory in
            let journalDirectory = directory.appendingPathComponent("restore")
            let journal = RestoreRollbackJournal(directoryURL: journalDirectory)
            try journal.begin(snapshotData: Data("snapshot".utf8), validate: { _ in })
            try FileManager.default.removeItem(at: journalDirectory.appendingPathComponent("rollback.radixbackup"))
            #expect(throws: (any Error).self) { try journal.rollbackData() }
            #expect(journal.isPending)
        }
    }
}

private func withRestoreJournalDirectory<T>(_ body: (URL) throws -> T) throws -> T {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("radix_restore_journal_tests_\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: url) }
    return try body(url)
}
