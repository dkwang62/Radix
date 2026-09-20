import Foundation

func insertBoundedCacheValue<Key: Hashable, Value>(
    _ value: Value,
    for key: Key,
    in cache: inout [Key: Value],
    limit: Int
) {
    cache[key] = value
    guard cache.count > limit else { return }
    if let evictionKey = cache.keys.first(where: { $0 != key }) {
        cache.removeValue(forKey: evictionKey)
    }
}
