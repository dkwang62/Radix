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
}
