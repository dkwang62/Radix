import Foundation

struct StrokeDecomposition {
    let operatorSymbol: Character
    let children: [StrokeDecomposition]
    let character: String?

    var directCharacter: String? {
        guard children.isEmpty else { return nil }
        return character
    }
}

struct IDSParser {
    let idcChars: Set<Character>

    func parse(_ value: String) -> StrokeDecomposition? {
        var iterator = Array(value).makeIterator()
        return parseNode(from: &iterator)
    }

    private func parseNode(from iterator: inout IndexingIterator<[Character]>) -> StrokeDecomposition? {
        guard let next = iterator.next() else { return nil }
        if idcChars.contains(next) {
            let arity = operandCount(for: next)
            var children: [StrokeDecomposition] = []
            for _ in 0..<arity {
                guard let child = parseNode(from: &iterator) else { return nil }
                children.append(child)
            }
            return StrokeDecomposition(operatorSymbol: next, children: children, character: nil)
        }
        return StrokeDecomposition(operatorSymbol: " ", children: [], character: String(next))
    }

    private func operandCount(for symbol: Character) -> Int {
        switch symbol {
        case "⿲", "⿳": return 3
        default: return 2
        }
    }
}
