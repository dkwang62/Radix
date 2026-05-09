import Foundation

enum ComponentScriptClass {
    case simplifiedOnly
    case traditionalOnly
    case both
}

struct ComponentScriptClassifier {
    private var cache: [String: ComponentScriptClass] = [:]

    mutating func reset() {
        cache.removeAll()
    }

    mutating func scriptClass(for value: String, in items: [String: ComponentItem]) -> ComponentScriptClass {
        if let cached = cache[value] {
            return cached
        }

        let resolved: ComponentScriptClass
        guard let item = items[value] else {
            resolved = scriptClassViaTextTransform(value)
            cache[value] = resolved
            return resolved
        }

        let variantChars = item.allVariants.filter { !$0.isEmpty && $0 != value }
        guard !variantChars.isEmpty else {
            cache[value] = .both
            return .both
        }

        guard let ownStrokes = item.strokes else {
            resolved = scriptClassViaTextTransform(value)
            cache[value] = resolved
            return resolved
        }

        let variantStrokes = variantChars.compactMap { items[$0]?.strokes }
        guard !variantStrokes.isEmpty else {
            resolved = scriptClassViaTextTransform(value)
            cache[value] = resolved
            return resolved
        }

        let minVariantStrokes = variantStrokes.min()!
        let maxVariantStrokes = variantStrokes.max()!

        if ownStrokes < minVariantStrokes {
            cache[value] = .simplifiedOnly
            return .simplifiedOnly
        }
        if ownStrokes > maxVariantStrokes {
            cache[value] = .traditionalOnly
            return .traditionalOnly
        }

        resolved = scriptClassViaTextTransform(value)
        cache[value] = resolved
        return resolved
    }

    func scriptClassViaTextTransform(_ value: String) -> ComponentScriptClass {
        let simplified = ScriptTextConverter.simplified(value)
        let traditional = ScriptTextConverter.traditional(value)
        if simplified == value && traditional != value { return .simplifiedOnly }
        if traditional == value && simplified != value { return .traditionalOnly }
        return .both
    }
}
