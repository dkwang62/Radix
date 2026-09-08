import Foundation

/// Platform-neutral key/value boundary for persisted app preferences.
/// Apple uses UserDefaults through RadixPreferences; Android can supply an
/// adapter backed by SharedPreferences or DataStore without changing callers.
protocol RadixPreferenceStore {
    func data(forKey key: String) -> Data?
    func string(forKey key: String) -> String?
    func bool(forKey key: String) -> Bool
    func integer(forKey key: String) -> Int
    func double(forKey key: String) -> Double
    func array(forKey key: String) -> [Any]?
    func dictionary(forKey key: String) -> [String: Any]?
    func object(forKey key: String) -> Any?
    func set(_ value: Any?, forKey key: String)
    func removeObject(forKey key: String)
    func flushPageDeletion() throws
}

extension RadixPreferenceStore {
    func flushPageDeletion() throws {
        throw NSError(domain: "Radix.PageDeletion", code: 2, userInfo: [
            NSLocalizedDescriptionKey: "This preference store cannot confirm a durable page deletion."
        ])
    }
}
