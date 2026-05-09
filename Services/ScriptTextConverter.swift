import Foundation

enum ScriptTextConverter {
    static func simplified(_ value: String) -> String {
        convertWithFallback(value, transforms: ["Hant-Hans", "Traditional-Simplified", "Any-Hans"])
    }

    static func traditional(_ value: String) -> String {
        convertWithFallback(value, transforms: ["Hans-Hant", "Simplified-Traditional", "Any-Hant"])
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
}
