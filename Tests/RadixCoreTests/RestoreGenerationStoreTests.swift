import Foundation
import Testing
@testable import RadixCore

@Suite("Staged restore generations")
struct RestoreGenerationStoreTests {
    @Test("Interrupted staging restores the previous complete generation")
    func interruptedStagingRollsBack() throws {
        try withGenerationStore { store in
            let original = try store.currentItemURL("preferences.plist")
            try Data("old".utf8).write(to: original)

            _ = try store.beginStaging()
            try Data("new".utf8).write(to: try store.currentItemURL("preferences.plist"))
            try store.recoverPointerBeforeOpening()

            #expect(String(data: try Data(contentsOf: store.currentItemURL("preferences.plist")), encoding: .utf8) == "old")
            #expect(!store.isPending)
        }
    }

    @Test("Promoted staging survives interruption and retires the previous generation")
    func promotedGenerationFinishes() throws {
        try withGenerationStore { store in
            try Data("old".utf8).write(to: try store.currentItemURL("state"))
            _ = try store.beginStaging()
            try Data("new".utf8).write(to: try store.currentItemURL("state"))
            try store.markPromoted()

            try store.recoverPointerBeforeOpening()
            #expect(String(data: try Data(contentsOf: store.currentItemURL("state")), encoding: .utf8) == "new")
            #expect(store.isPending)
            try store.finishPromotion()
            #expect(!store.isPending)
            #expect(String(data: try Data(contentsOf: store.currentItemURL("state")), encoding: .utf8) == "new")
        }
    }

    @Test("Repeated recovery is deterministic")
    func repeatedRecovery() throws {
        try withGenerationStore { store in
            try Data("old".utf8).write(to: try store.currentItemURL("state"))
            _ = try store.beginStaging()
            try store.recoverPointerBeforeOpening()
            try store.recoverPointerBeforeOpening()
            #expect(String(data: try Data(contentsOf: store.currentItemURL("state")), encoding: .utf8) == "old")
        }
    }

    @Test("A missing promoted generation fails closed and retains recovery intent")
    func missingPromotedGenerationFailsClosed() throws {
        try withGenerationStore { store in
            _ = try store.beginStaging()
            try store.markPromoted()
            let staged = try store.activeDirectoryURL()
            try FileManager.default.removeItem(at: staged)

            #expect(throws: (any Error).self) {
                try store.recoverPointerBeforeOpening()
            }
            #expect(store.isPending)
        }
    }
}

private func withGenerationStore<T>(_ body: (RestoreGenerationStore) throws -> T) throws -> T {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("radix_restore_generation_tests_\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: url) }
    return try body(RestoreGenerationStore(rootURL: url))
}
