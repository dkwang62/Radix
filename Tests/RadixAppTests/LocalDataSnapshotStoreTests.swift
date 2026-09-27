import Foundation
import XCTest
@testable import Radix

final class LocalDataSnapshotStoreTests: XCTestCase {
    func testSavesCheckpointsUnderDocumentsDirectory() throws {
        let fixture = try SnapshotStoreFixture()
        defer { fixture.cleanup() }
        let store = fixture.store

        let snapshots = try store.save(Data("checkpoint".utf8), createdAt: Date(timeIntervalSince1970: 1_700_000_000))

        XCTAssertEqual(snapshots.count, 1)
        XCTAssertTrue(snapshots[0].url.path.hasPrefix(fixture.documentsURL.path))
        XCTAssertEqual(snapshots[0].url.pathExtension, "radixbackup")
        XCTAssertEqual(try Data(contentsOf: snapshots[0].url), Data("checkpoint".utf8))
    }

    func testMigratesLegacyApplicationSupportCheckpointsToDocumentsDirectory() throws {
        let fixture = try SnapshotStoreFixture()
        defer { fixture.cleanup() }
        let legacyDirectory = fixture.legacyURL.appendingPathComponent("Radix/LocalSnapshots", isDirectory: true)
        try FileManager.default.createDirectory(at: legacyDirectory, withIntermediateDirectories: true)
        let legacyURL = legacyDirectory.appendingPathComponent("radix-local-2026-09-27-101500.radixbackup")
        try Data("legacy".utf8).write(to: legacyURL)

        let snapshots = try fixture.store.snapshots()

        XCTAssertEqual(snapshots.count, 1)
        XCTAssertTrue(snapshots[0].url.path.hasPrefix(fixture.documentsURL.path))
        XCTAssertEqual(try Data(contentsOf: snapshots[0].url), Data("legacy".utf8))
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyURL.path))
    }
}

private struct SnapshotStoreFixture {
    let rootURL: URL
    let documentsURL: URL
    let legacyURL: URL
    let store: LocalDataSnapshotStore

    init() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        documentsURL = rootURL.appendingPathComponent("Documents", isDirectory: true)
        legacyURL = rootURL.appendingPathComponent("ApplicationSupport", isDirectory: true)
        try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: legacyURL, withIntermediateDirectories: true)
        store = LocalDataSnapshotStore(
            documentsBaseURL: documentsURL,
            legacyBaseURL: legacyURL
        )
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: rootURL)
    }
}
