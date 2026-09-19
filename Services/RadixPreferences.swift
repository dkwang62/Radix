import Foundation

struct RadixPreferences: RadixPreferenceStore, @unchecked Sendable {
    static let standard = RadixPreferences(generationStorage: .shared)

    private let defaults: UserDefaults
    private let generationStorage: RestoreGenerationPreferences?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.generationStorage = nil
    }

    private init(generationStorage: RestoreGenerationPreferences) {
        self.defaults = .standard
        self.generationStorage = generationStorage
    }

    func data(forKey key: String) -> Data? {
        if let generationStorage { return generationStorage.object(forKey: key) as? Data }
        return defaults.data(forKey: key)
    }

    func string(forKey key: String) -> String? {
        if let generationStorage { return generationStorage.object(forKey: key) as? String }
        return defaults.string(forKey: key)
    }

    func bool(forKey key: String) -> Bool {
        if let generationStorage { return generationStorage.object(forKey: key) as? Bool ?? false }
        return defaults.bool(forKey: key)
    }

    func integer(forKey key: String) -> Int {
        if let generationStorage { return generationStorage.object(forKey: key) as? Int ?? 0 }
        return defaults.integer(forKey: key)
    }

    func double(forKey key: String) -> Double {
        if let generationStorage {
            if let value = generationStorage.object(forKey: key) as? Double { return value }
            return (generationStorage.object(forKey: key) as? NSNumber)?.doubleValue ?? 0
        }
        return defaults.double(forKey: key)
    }

    func array(forKey key: String) -> [Any]? {
        if let generationStorage { return generationStorage.object(forKey: key) as? [Any] }
        return defaults.array(forKey: key)
    }

    func dictionary(forKey key: String) -> [String: Any]? {
        if let generationStorage { return generationStorage.object(forKey: key) as? [String: Any] }
        return defaults.dictionary(forKey: key)
    }

    func object(forKey key: String) -> Any? {
        if let generationStorage { return generationStorage.object(forKey: key) }
        return defaults.object(forKey: key)
    }

    func set(_ value: Any?, forKey key: String) {
        if let generationStorage {
            generationStorage.set(value, forKey: key)
            return
        }
        defaults.set(value, forKey: key)
    }

    func removeObject(forKey key: String) {
        if let generationStorage {
            generationStorage.removeObject(forKey: key)
            return
        }
        defaults.removeObject(forKey: key)
    }

    func flushPageDeletion() throws {
        if let generationStorage {
            try generationStorage.flush()
            return
        }
        guard defaults.synchronize() else {
            throw NSError(domain: "Radix.PageDeletion", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Page deletion could not be saved. Free up storage and retry."
            ])
        }
    }
}

private final class RestoreGenerationPreferences: @unchecked Sendable {
    static let shared = RestoreGenerationPreferences()

    private struct Envelope: Codable {
        var values: [String: Data]
        var removedKeys: Set<String>
    }

    private let lock = NSRecursiveLock()
    private var loadedURL: URL?
    private var envelope = Envelope(values: [:], removedKeys: [])

    func object(forKey key: String) -> Any? {
        lock.lock()
        defer { lock.unlock() }
        loadIfNeeded()
        if envelope.removedKeys.contains(key) { return nil }
        guard let data = envelope.values[key] else { return UserDefaults.standard.object(forKey: key) }
        return try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)
    }

    func set(_ value: Any?, forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        loadIfNeeded()
        guard let value else {
            removeObjectLocked(forKey: key)
            return
        }
        guard let data = try? PropertyListSerialization.data(
            fromPropertyList: value,
            format: .binary,
            options: 0
        ) else { return }
        envelope.values[key] = data
        envelope.removedKeys.remove(key)
        try? persistLocked()
    }

    func removeObject(forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        loadIfNeeded()
        removeObjectLocked(forKey: key)
    }

    func flush() throws {
        lock.lock()
        defer { lock.unlock() }
        loadIfNeeded()
        try persistLocked()
    }

    private func removeObjectLocked(forKey key: String) {
        envelope.values.removeValue(forKey: key)
        envelope.removedKeys.insert(key)
        try? persistLocked()
    }

    private func loadIfNeeded() {
        guard let url = try? preferencesURL() else { return }
        let resolvedURL = url.resolvingSymlinksInPath()
        guard loadedURL != resolvedURL else { return }
        loadedURL = resolvedURL
        if let data = try? Data(contentsOf: url),
           let decoded = try? PropertyListDecoder().decode(Envelope.self, from: data) {
            envelope = decoded
        } else {
            envelope = Envelope(values: [:], removedKeys: [])
        }
    }

    private func persistLocked() throws {
        let url = try preferencesURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try PropertyListEncoder().encode(envelope).write(to: url, options: .atomic)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.synchronize()
        loadedURL = url.resolvingSymlinksInPath()
    }

    private func preferencesURL() throws -> URL {
        try RestoreGenerationStore.shared.activeItemURL("preferences.plist")
    }
}
