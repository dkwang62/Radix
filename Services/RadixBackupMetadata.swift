import Foundation

struct RadixBackupMetadata {
    var path: String
    var timestamp: TimeInterval

    var hasBackup: Bool {
        !path.isEmpty && timestamp > 0
    }
}

enum RadixBackupMetadataStore {
    private static let pathKey = "dataEditLastOtherDeviceBackupPath"
    private static let dateKey = "dataEditLastOtherDeviceBackupDate"
    private static let preferences = RadixPreferences.standard

    static var latest: RadixBackupMetadata {
        RadixBackupMetadata(
            path: preferences.string(forKey: pathKey) ?? "",
            timestamp: preferences.double(forKey: dateKey)
        )
    }

    @discardableResult
    static func recordBackup(at url: URL, date: Date = Date()) -> RadixBackupMetadata {
        let metadata = RadixBackupMetadata(path: url.path, timestamp: date.timeIntervalSince1970)
        preferences.set(metadata.path, forKey: pathKey)
        preferences.set(metadata.timestamp, forKey: dateKey)
        return metadata
    }
}
