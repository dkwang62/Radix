import Foundation

struct ComponentDecompositionParser {
    private static let idcCharacters: Set<Character> = ["⿰", "⿱", "⿲", "⿳", "⿴", "⿵", "⿶", "⿷", "⿸", "⿹", "⿺", "⿻"]

    private struct PartsCacheKey: Hashable {
        let decomposition: String
        let excluding: String
    }

    private var partsCache: [PartsCacheKey: [String]] = [:]

    mutating func reset() {
        partsCache.removeAll()
    }

    func structureKey(for decomposition: String) -> String {
        guard let first = decomposition.first, Self.idcCharacters.contains(first) else {
            return "None"
        }
        return String(first)
    }

    mutating func parts(from decomposition: String, excluding character: String, knownCharacters: Set<String>) -> [String] {
        let key = PartsCacheKey(decomposition: decomposition, excluding: character)
        if let cached = partsCache[key] {
            return cached
        }

        var out: [String] = []
        for ch in decomposition {
            guard !Self.idcCharacters.contains(ch) else { continue }
            let token = String(ch)
            guard token != character, token != "?", token != "—", knownCharacters.contains(token) else { continue }
            if !out.contains(token) {
                out.append(token)
            }
        }
        partsCache[key] = out
        return out
    }

    static func usedComponents(from data: [String: ComponentItem]) -> Set<String> {
        var used: Set<String> = []
        for item in data.values {
            for ch in item.decomposition where !idcCharacters.contains(ch) {
                used.insert(String(ch))
            }
        }
        return used
    }
}
