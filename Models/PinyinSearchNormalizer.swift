import Foundation

enum PinyinSearchNormalizer {
    private static let canonicalInitialMappings: [(source: String, target: String)] = [
        ("zh", "z"),
        ("sh", "s"),
        ("ch", "c")
    ]

    static func normalize(_ value: String, preservingSpaces: Bool = false, fuzzyInitials: Bool = true) -> String {
        let mutable = NSMutableString(string: value.lowercased()) as CFMutableString
        CFStringTransform(mutable, nil, kCFStringTransformStripDiacritics, false)

        let words = (mutable as String)
            .map { ch -> Character in
                (ch.isLetter || ch.isNumber) ? ch : " "
            }
            .reduce(into: "") { partial, ch in
                if ch == " " {
                    if partial.last != " " { partial.append(ch) }
                } else {
                    partial.append(ch)
                }
            }
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .map(String.init)

        let normalizedWords = fuzzyInitials ? words.map(applyCanonicalInitialMappings) : words
        return preservingSpaces ? normalizedWords.joined(separator: " ") : normalizedWords.joined()
    }

    private static func applyCanonicalInitialMappings(_ syllable: String) -> String {
        for mapping in canonicalInitialMappings {
            if syllable.hasPrefix(mapping.source) {
                return mapping.target + syllable.dropFirst(mapping.source.count)
            }
        }
        return syllable
    }
}
