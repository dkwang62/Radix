import Foundation

struct RadixBackupMetadata: Codable, Identifiable {
    var path: String
    var timestamp: TimeInterval

    var id: String { "\(path)|\(timestamp)" }

    var hasBackup: Bool {
        !path.isEmpty && timestamp > 0
    }
}

enum RadixBackupMetadataStore {
    private static let pathKey = "dataEditLastOtherDeviceBackupPath"
    private static let dateKey = "dataEditLastOtherDeviceBackupDate"
    private static let historyKey = "dataEditOtherDeviceBackupHistoryV1"
    private static let preferences = RadixPreferences.standard

    static var latest: RadixBackupMetadata {
        history.first ?? RadixBackupMetadata(
            path: preferences.string(forKey: pathKey) ?? "",
            timestamp: preferences.double(forKey: dateKey)
        )
    }

    static var history: [RadixBackupMetadata] {
        guard let data = preferences.data(forKey: historyKey),
              let decoded = try? JSONDecoder().decode([RadixBackupMetadata].self, from: data)
        else {
            let legacy = RadixBackupMetadata(
                path: preferences.string(forKey: pathKey) ?? "",
                timestamp: preferences.double(forKey: dateKey)
            )
            return legacy.hasBackup ? [legacy] : []
        }
        return decoded.sorted { $0.timestamp > $1.timestamp }
    }

    @discardableResult
    static func recordBackup(at url: URL, date: Date = Date()) -> RadixBackupMetadata {
        let metadata = RadixBackupMetadata(path: url.path, timestamp: date.timeIntervalSince1970)
        preferences.set(metadata.path, forKey: pathKey)
        preferences.set(metadata.timestamp, forKey: dateKey)
        var updated = history.filter { $0.path != metadata.path }
        updated.insert(metadata, at: 0)
        if let encoded = try? JSONEncoder().encode(Array(updated.prefix(10))) {
            preferences.set(encoded, forKey: historyKey)
        }
        return metadata
    }

    static func isReadable(_ metadata: RadixBackupMetadata) -> Bool {
        FileManager.default.isReadableFile(atPath: metadata.path)
    }
}

enum RadixDatabaseSnapshotKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case sentenceExamples
    case addedPhrases

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sentenceExamples: return "Sentences"
        case .addedPhrases: return "Added Phrases"
        }
    }

    var filenamePrefix: String {
        switch self {
        case .sentenceExamples: return "sentence_examples"
        case .addedPhrases: return "phrases_add"
        }
    }

    var fileExtension: String {
        switch self {
        case .sentenceExamples: return "sqlite"
        case .addedPhrases: return "db"
        }
    }
}

struct RadixDatabaseSnapshotMetadata: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var kind: RadixDatabaseSnapshotKind
    var reason: String
    var path: String
    var timestamp: TimeInterval
    var byteCount: Int64

    var createdAt: Date { Date(timeIntervalSince1970: timestamp) }
}

enum RadixDatabaseSnapshotStore {
    private static let historyKey = "radix.databaseSnapshotHistory.v1"
    private static let preferences = RadixPreferences.standard
    private static let keepCountPerKind = 8

    static func snapshots(kind: RadixDatabaseSnapshotKind? = nil) -> [RadixDatabaseSnapshotMetadata] {
        let decoded: [RadixDatabaseSnapshotMetadata]
        if let data = preferences.data(forKey: historyKey),
           let history = try? JSONDecoder().decode([RadixDatabaseSnapshotMetadata].self, from: data) {
            decoded = history
        } else {
            decoded = []
        }
        let filtered = kind.map { selected in decoded.filter { $0.kind == selected } } ?? decoded
        return filtered.sorted { $0.timestamp > $1.timestamp }
    }

    static func latest(kind: RadixDatabaseSnapshotKind) -> RadixDatabaseSnapshotMetadata? {
        snapshots(kind: kind).first(where: isReadable(_:))
    }

    static func destinationURL(kind: RadixDatabaseSnapshotKind, date: Date = Date()) throws -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let suffix = UUID().uuidString.prefix(8)
        let filename = "\(kind.filenamePrefix)-\(formatter.string(from: date))-\(suffix).\(kind.fileExtension)"
        let directory = try snapshotsDirectory(kind: kind)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(filename)
    }

    @discardableResult
    static func record(kind: RadixDatabaseSnapshotKind, reason: String, at url: URL, date: Date = Date()) -> RadixDatabaseSnapshotMetadata {
        let byteCount = ((try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? NSNumber)?.int64Value ?? 0
        let metadata = RadixDatabaseSnapshotMetadata(
            id: "\(kind.rawValue)|\(date.timeIntervalSince1970)|\(url.lastPathComponent)",
            kind: kind,
            reason: reason,
            path: url.path,
            timestamp: date.timeIntervalSince1970,
            byteCount: byteCount
        )
        var updated = snapshots().filter { $0.id != metadata.id && FileManager.default.fileExists(atPath: $0.path) }
        updated.insert(metadata, at: 0)
        pruneFiles(for: updated)
        let pruned = prunedHistory(from: updated)
        if let encoded = try? JSONEncoder().encode(pruned) {
            preferences.set(encoded, forKey: historyKey)
        }
        return metadata
    }

    static func isReadable(_ metadata: RadixDatabaseSnapshotMetadata) -> Bool {
        FileManager.default.isReadableFile(atPath: metadata.path)
    }

    private static func snapshotsDirectory(kind: RadixDatabaseSnapshotKind) throws -> URL {
        let fileManager = FileManager.default
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return baseURL
            .appendingPathComponent("Radix", isDirectory: true)
            .appendingPathComponent("Database Snapshots", isDirectory: true)
            .appendingPathComponent(kind.rawValue, isDirectory: true)
    }

    private static func prunedHistory(from history: [RadixDatabaseSnapshotMetadata]) -> [RadixDatabaseSnapshotMetadata] {
        var counts: [RadixDatabaseSnapshotKind: Int] = [:]
        var kept: [RadixDatabaseSnapshotMetadata] = []
        for snapshot in history.sorted(by: { $0.timestamp > $1.timestamp }) {
            let count = counts[snapshot.kind, default: 0]
            guard count < keepCountPerKind else { continue }
            counts[snapshot.kind] = count + 1
            kept.append(snapshot)
        }
        return kept
    }

    private static func pruneFiles(for history: [RadixDatabaseSnapshotMetadata]) {
        let keep = Set(prunedHistory(from: history).map(\.path))
        for snapshot in history where !keep.contains(snapshot.path) {
            try? FileManager.default.removeItem(atPath: snapshot.path)
        }
    }
}
