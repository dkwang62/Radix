import Foundation
import Testing
@testable import RadixCore

@Suite("Staged restore generations")
struct RestoreGenerationStoreTests {
    @Test("Interrupted staging restores the previous complete generation")
    func interruptedStagingRollsBack() throws {
        try withGenerationStore { store in
            let names = ["preferences.plist", "sentences.sqlite", "phrases_add.db", "Saved Page Images/page.jpg"]
            try writeGeneration("old", names: names, store: store)

            _ = try store.beginStaging()
            try writeGeneration("new", names: names, store: store)
            try store.recoverPointerBeforeOpening()

            try expectGeneration("old", names: names, store: store)
            #expect(!store.isPending)
        }
    }

    @Test("Promoted staging survives interruption and retires the previous generation")
    func promotedGenerationFinishes() throws {
        try withGenerationStore { store in
            let names = ["preferences.plist", "sentences.sqlite", "phrases_add.db", "Saved Page Images/page.jpg"]
            try writeGeneration("old", names: names, store: store)
            _ = try store.beginStaging()
            try writeGeneration("new", names: names, store: store)
            try store.markPromoted()

            try store.recoverPointerBeforeOpening()
            try expectGeneration("new", names: names, store: store)
            #expect(store.isPending)
            try store.finishPromotion()
            #expect(!store.isPending)
            try expectGeneration("new", names: names, store: store)
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

private func writeGeneration(_ value: String, names: [String], store: RestoreGenerationStore) throws {
    for name in names {
        let url = try store.currentItemURL(name)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(value.utf8).write(to: url, options: .atomic)
    }
}

private func expectGeneration(_ value: String, names: [String], store: RestoreGenerationStore) throws {
    for name in names {
        let data = try Data(contentsOf: store.currentItemURL(name))
        #expect(String(data: data, encoding: .utf8) == value)
    }
}

private func withGenerationStore<T>(_ body: (RestoreGenerationStore) throws -> T) throws -> T {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("radix_restore_generation_tests_\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: url) }
    return try body(RestoreGenerationStore(rootURL: url))
}
