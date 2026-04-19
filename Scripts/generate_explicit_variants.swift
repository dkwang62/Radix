import Foundation

func convert(_ value: String, transform: String) -> String {
    let mutable = NSMutableString(string: value)
    if CFStringTransform(mutable, nil, transform as CFString, false) {
        return String(mutable)
    }
    return value
}

func convertWithFallback(_ value: String, transforms: [String]) -> String {
    for transform in transforms {
        let converted = convert(value, transform: transform)
        if converted != value {
            return converted
        }
    }
    return value
}

func toSimplified(_ value: String) -> String {
    convertWithFallback(value, transforms: ["Hant-Hans", "Traditional-Simplified", "Any-Hans"])
}

func toTraditional(_ value: String) -> String {
    convertWithFallback(value, transforms: ["Hans-Hant", "Simplified-Traditional", "Any-Hant"])
}

func directCounterpart(for character: String, knownCharacters: Set<String>) -> String? {
    let simplified = toSimplified(character)
    let traditional = toTraditional(character)

    if simplified != character, knownCharacters.contains(simplified) {
        return simplified
    }
    if traditional != character, knownCharacters.contains(traditional) {
        return traditional
    }
    return nil
}

func reverseCandidateMap(allCharacters: [String]) -> [String: [String]] {
    var out: [String: [String]] = [:]
    for candidate in allCharacters {
        let simplifiedCandidate = toSimplified(candidate)
        if simplifiedCandidate != candidate {
            out[simplifiedCandidate, default: []].append(candidate)
        }
        let traditionalCandidate = toTraditional(candidate)
        if traditionalCandidate != candidate, traditionalCandidate != simplifiedCandidate {
            out[traditionalCandidate, default: []].append(candidate)
        }
    }
    for key in out.keys {
        out[key]?.sort()
    }
    return out
}

let defaultPath = "/Users/desmondkwang/Library/Mobile Documents/com~apple~CloudDocs/Documents/Radix/enhanced_component_map_with_etymology.json"
let targetPath = CommandLine.arguments.dropFirst().first ?? defaultPath
let targetURL = URL(fileURLWithPath: targetPath)

let data = try Data(contentsOf: targetURL)
guard var root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
    throw NSError(domain: "Radix", code: 3001, userInfo: [NSLocalizedDescriptionKey: "Top-level JSON is not a dictionary."])
}

let allCharacters = root.keys.sorted()
let knownCharacters = Set(allCharacters)
let reverseCandidates = reverseCandidateMap(allCharacters: allCharacters)

var updated = 0
var cleared = 0

for character in allCharacters {
    guard var entry = root[character] as? [String: Any] else { continue }
    guard var meta = entry["meta"] as? [String: Any] else { continue }

    let generated = directCounterpart(for: character, knownCharacters: knownCharacters)
        ?? reverseCandidates[character]?.first(where: { $0 != character })
    let normalizedGenerated = generated?.trimmingCharacters(in: .whitespacesAndNewlines)
    let currentVariant = (meta["variant"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

    if let normalizedGenerated, !normalizedGenerated.isEmpty, normalizedGenerated != character {
        if currentVariant != normalizedGenerated {
            meta["variant"] = normalizedGenerated
            updated += 1
        }
    } else if meta["variant"] != nil {
        meta.removeValue(forKey: "variant")
        cleared += 1
    }

    entry["meta"] = meta
    root[character] = entry
}

let output = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
try output.write(to: targetURL, options: .atomic)

print("Updated explicit variants for \(updated) entries.")
if cleared > 0 {
    print("Cleared stale variants for \(cleared) entries.")
}
