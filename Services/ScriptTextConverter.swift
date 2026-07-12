import Foundation

enum ScriptTextConverter {
    private static let cacheLimit = 4_000
    private static let lock = NSLock()
    nonisolated(unsafe) private static var simplifiedCache: [String: String] = [:]
    nonisolated(unsafe) private static var traditionalCache: [String: String] = [:]

    static func simplified(_ value: String) -> String {
        cachedConvert(
            value,
            direction: .simplified,
            transforms: ["Hant-Hans", "Traditional-Simplified", "Any-Hans"]
        )
    }

    static func traditional(_ value: String) -> String {
        cachedConvert(
            value,
            direction: .traditional,
            transforms: ["Hans-Hant", "Simplified-Traditional", "Any-Hant"]
        )
    }

    private enum Direction {
        case simplified
        case traditional
    }

    private static func convert(_ value: String, transform: String) -> String {
        let mutable = NSMutableString(string: value)
        if CFStringTransform(mutable, nil, transform as CFString, false) {
            return String(mutable)
        }
        return value
    }

    private static func convertWithFallback(_ value: String, transforms: [String]) -> String {
        for transform in transforms {
            let converted = convert(value, transform: transform)
            if converted != value {
                return converted
            }
        }
        return value
    }

    private static func cachedConvert(
        _ value: String,
        direction: Direction,
        transforms: [String]
    ) -> String {
        guard !value.isEmpty else { return value }

        lock.lock()
        let cached = switch direction {
        case .simplified: simplifiedCache[value]
        case .traditional: traditionalCache[value]
        }
        if let cached {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let converted = convertWithFallback(value, transforms: transforms)

        lock.lock()
        switch direction {
        case .simplified:
            if simplifiedCache.count >= cacheLimit {
                simplifiedCache.removeAll(keepingCapacity: true)
            }
            simplifiedCache[value] = converted
        case .traditional:
            if traditionalCache.count >= cacheLimit {
                traditionalCache.removeAll(keepingCapacity: true)
            }
            traditionalCache[value] = converted
        }
        lock.unlock()

        return converted
    }
}
