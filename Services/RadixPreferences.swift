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

    func beginStagedRestoreBatch() {
        generationStorage?.beginBatch()
    }

    func finishStagedRestoreBatch() throws {
        try generationStorage?.finishBatch()
    }

    func abandonStagedRestoreBatch() {
        generationStorage?.abandonBatch()
    }
}
