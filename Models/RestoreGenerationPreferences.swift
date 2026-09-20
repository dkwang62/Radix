import Foundation

final class RestoreGenerationPreferences: @unchecked Sendable {
    static let shared = RestoreGenerationPreferences()

    private struct Envelope: Codable {
        var values: [String: Data]
        var removedKeys: Set<String>
    }

    private let lock = NSRecursiveLock()
    private let generationStore: RestoreGenerationStore
    private let fallbackDefaults: UserDefaults
    private var loadedURL: URL?
    private var envelope = Envelope(values: [:], removedKeys: [])
    private var batchDepth = 0
    private var mutationRevision = 0
    private var persistedRevision = 0

    init(
        generationStore: RestoreGenerationStore = .shared,
        fallbackDefaults: UserDefaults = .standard
    ) {
        self.generationStore = generationStore
        self.fallbackDefaults = fallbackDefaults
    }

    func object(forKey key: String) -> Any? {
        lock.lock()
        defer { lock.unlock() }
        loadIfNeeded()
        if envelope.removedKeys.contains(key) { return nil }
        guard let data = envelope.values[key] else { return fallbackDefaults.object(forKey: key) }
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
        mutationRevision += 1
        if batchDepth == 0 {
            try? persistLocked()
        }
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

    func beginBatch() {
        lock.lock()
        defer { lock.unlock() }
        loadIfNeeded()
        batchDepth += 1
    }

    func finishBatch() throws {
        lock.lock()
        defer { lock.unlock() }
        guard batchDepth > 0 else { return }
        batchDepth -= 1
        if batchDepth == 0 {
            try persistLocked()
        }
    }

    func abandonBatch() {
        lock.lock()
        defer { lock.unlock() }
        batchDepth = 0
        loadedURL = nil
        envelope = Envelope(values: [:], removedKeys: [])
        mutationRevision = 0
        persistedRevision = 0
    }

    private func removeObjectLocked(forKey key: String) {
        envelope.values.removeValue(forKey: key)
        envelope.removedKeys.insert(key)
        mutationRevision += 1
        if batchDepth == 0 {
            try? persistLocked()
        }
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
        mutationRevision = 0
        persistedRevision = 0
    }

    private func persistLocked() throws {
        let url = try preferencesURL()
        guard mutationRevision != persistedRevision || !FileManager.default.fileExists(atPath: url.path) else {
            return
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try PropertyListEncoder().encode(envelope).write(to: url, options: .atomic)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.synchronize()
        loadedURL = url.resolvingSymlinksInPath()
        persistedRevision = mutationRevision
    }

    private func preferencesURL() throws -> URL {
        try generationStore.activeItemURL("preferences.plist")
    }
}
