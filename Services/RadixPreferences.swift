import Foundation

struct RadixPreferences: RadixPreferenceStore, @unchecked Sendable {
    static let standard = RadixPreferences()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func data(forKey key: String) -> Data? {
        defaults.data(forKey: key)
    }

    func string(forKey key: String) -> String? {
        defaults.string(forKey: key)
    }

    func bool(forKey key: String) -> Bool {
        defaults.bool(forKey: key)
    }

    func integer(forKey key: String) -> Int {
        defaults.integer(forKey: key)
    }

    func double(forKey key: String) -> Double {
        defaults.double(forKey: key)
    }

    func array(forKey key: String) -> [Any]? {
        defaults.array(forKey: key)
    }

    func dictionary(forKey key: String) -> [String: Any]? {
        defaults.dictionary(forKey: key)
    }

    func object(forKey key: String) -> Any? {
        defaults.object(forKey: key)
    }

    func set(_ value: Any?, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    func removeObject(forKey key: String) {
        defaults.removeObject(forKey: key)
    }
}
