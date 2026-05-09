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

enum SynthesisLayout {
    case leftRight
    case topBottom
    case leftMiddleRight
    case topMiddleBottom

    init?(_ symbol: Character) {
        switch symbol {
        case "⿰": self = .leftRight
        case "⿱": self = .topBottom
        case "⿲": self = .leftMiddleRight
        case "⿳": self = .topMiddleBottom
        default: return nil
        }
    }

    func slots(for children: [StrokeDecomposition]) -> [StrokeSlot] {
        switch self {
        case .leftRight:
            let firstComponent = children.first?.directCharacter
            if firstComponent == "馬" {
                return [
                    StrokeSlot(minX: 28, maxX: 500, minY: -84, maxY: 860),
                    StrokeSlot(minX: 548, maxX: 988, minY: -84, maxY: 860)
                ]
            }
            if Self.narrowLeftComponents.contains(firstComponent ?? "") {
                return [
                    StrokeSlot(minX: 36, maxX: 360, minY: -84, maxY: 860),
                    StrokeSlot(minX: 456, maxX: 988, minY: -84, maxY: 860)
                ]
            }
            return [
                StrokeSlot(minX: 36, maxX: 480, minY: -84, maxY: 860),
                StrokeSlot(minX: 544, maxX: 988, minY: -84, maxY: 860)
            ]
        case .topBottom:
            return [
                StrokeSlot(minX: 160, maxX: 864, minY: 520, maxY: 868),
                StrokeSlot(minX: 96, maxX: 928, minY: -92, maxY: 560)
            ]
        case .leftMiddleRight:
            return [
                StrokeSlot(minX: 32, maxX: 336, minY: -84, maxY: 860),
                StrokeSlot(minX: 360, maxX: 664, minY: -84, maxY: 860),
                StrokeSlot(minX: 688, maxX: 992, minY: -84, maxY: 860)
            ]
        case .topMiddleBottom:
            return [
                StrokeSlot(minX: 220, maxX: 804, minY: 512, maxY: 868),
                StrokeSlot(minX: 128, maxX: 896, minY: 184, maxY: 560),
                StrokeSlot(minX: 128, maxX: 896, minY: -92, maxY: 284)
            ]
        }
    }

    private static let narrowLeftComponents: Set<String> = [
        "亻", "彳", "氵", "扌", "忄", "山", "口", "女", "木", "日", "月", "讠", "言"
    ]
}

struct StrokeSlot {
    let minX: Double
    let maxX: Double
    let minY: Double
    let maxY: Double

    func transform(_ point: StrokePoint, from sourceBounds: StrokeBounds) -> StrokePoint {
        let x = minX + ((point.x - sourceBounds.minX) / sourceBounds.width) * (maxX - minX)
        let y = minY + ((point.y - sourceBounds.minY) / sourceBounds.height) * (maxY - minY)
        return StrokePoint(x: x, y: y)
    }
}

struct StrokeBounds {
    var minX: Double
    var maxX: Double
    var minY: Double
    var maxY: Double

    static let defaultCanvas = StrokeBounds(minX: 0, maxX: 1024, minY: -124, maxY: 900)

    var width: Double {
        max(maxX - minX, 1)
    }

    var height: Double {
        max(maxY - minY, 1)
    }

    mutating func include(_ point: StrokePoint) {
        minX = min(minX, point.x)
        maxX = max(maxX, point.x)
        minY = min(minY, point.y)
        maxY = max(maxY, point.y)
    }
}

struct StrokeCharacterData: Codable, Equatable {
    var character: String
    var strokes: [String]
    var medians: [[[Double]]]
    var radStrokes: [Int]?

    init(character: String, strokes: [String], medians: [[[Double]]], radStrokes: [Int]?) {
        self.character = character
        self.strokes = strokes
        self.medians = medians
        self.radStrokes = radStrokes
    }

    init?(jsonString: String) {
        guard let data = jsonString.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(StrokeCharacterData.self, from: data),
              decoded.strokes.count == decoded.medians.count else {
            return nil
        }
        self = decoded
    }

    var jsonString: String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    mutating func append(_ other: StrokeCharacterData) {
        let offset = strokes.count
        strokes.append(contentsOf: other.strokes)
        medians.append(contentsOf: other.medians)
        if let otherRadStrokes = other.radStrokes, !otherRadStrokes.isEmpty {
            var merged = radStrokes ?? []
            merged.append(contentsOf: otherRadStrokes.map { $0 + offset })
            radStrokes = merged
        }
    }

    func transformed(to slot: StrokeSlot) -> StrokeCharacterData {
        let bounds = sourceBounds ?? .defaultCanvas
        return StrokeCharacterData(
            character: character,
            strokes: strokes.map { StrokePathTransformer.transform(path: $0, to: slot, sourceBounds: bounds) },
            medians: medians.map { stroke in
                stroke.map { pair in
                    guard pair.count >= 2 else { return pair }
                    let transformed = slot.transform(StrokePoint(x: pair[0], y: pair[1]), from: bounds)
                    return [transformed.x, transformed.y]
                }
            },
            radStrokes: radStrokes
        )
    }

    private var sourceBounds: StrokeBounds? {
        var bounds: StrokeBounds?

        func include(_ point: StrokePoint) {
            if bounds == nil {
                bounds = StrokeBounds(minX: point.x, maxX: point.x, minY: point.y, maxY: point.y)
            } else {
                bounds?.include(point)
            }
        }

        for path in strokes {
            StrokePathTransformer.points(in: path).forEach(include)
        }

        for stroke in medians {
            for pair in stroke where pair.count >= 2 {
                include(StrokePoint(x: pair[0], y: pair[1]))
            }
        }

        return bounds
    }
}

struct StrokePoint {
    let x: Double
    let y: Double
}

enum StrokePathTransformer {
    private static let commandArities: [String: Int] = [
        "M": 2, "L": 2, "Q": 4, "C": 6, "Z": 0
    ]

    static func transform(path: String, to slot: StrokeSlot, sourceBounds: StrokeBounds) -> String {
        let tokens = tokenize(path)
        var output: [String] = []
        var index = 0

        while index < tokens.count {
            let token = tokens[index]
            guard let arity = commandArities[token] else {
                output.append(token)
                index += 1
                continue
            }

            output.append(token)
            index += 1
            guard arity > 0 else { continue }

            var values: [Double] = []
            for _ in 0..<arity where index < tokens.count {
                values.append(Double(tokens[index]) ?? 0)
                index += 1
            }

            var transformed: [String] = []
            var valueIndex = 0
            while valueIndex + 1 < values.count {
                let point = slot.transform(StrokePoint(x: values[valueIndex], y: values[valueIndex + 1]), from: sourceBounds)
                transformed.append(format(point.x))
                transformed.append(format(point.y))
                valueIndex += 2
            }
            output.append(contentsOf: transformed)
        }

        return output.joined(separator: " ")
    }

    static func points(in path: String) -> [StrokePoint] {
        let tokens = tokenize(path)
        var points: [StrokePoint] = []
        var index = 0

        while index < tokens.count {
            let token = tokens[index]
            guard let arity = commandArities[token] else {
                index += 1
                continue
            }

            index += 1
            guard arity > 0 else { continue }

            var values: [Double] = []
            for _ in 0..<arity where index < tokens.count {
                values.append(Double(tokens[index]) ?? 0)
                index += 1
            }

            var valueIndex = 0
            while valueIndex + 1 < values.count {
                points.append(StrokePoint(x: values[valueIndex], y: values[valueIndex + 1]))
                valueIndex += 2
            }
        }

        return points
    }

    private static func tokenize(_ path: String) -> [String] {
        var tokens: [String] = []
        var current = ""

        func flush() {
            guard !current.isEmpty else { return }
            tokens.append(current)
            current = ""
        }

        for scalar in path.unicodeScalars {
            let char = Character(scalar)
            if scalar.properties.isAlphabetic {
                flush()
                tokens.append(String(char))
            } else if scalar.properties.isWhitespace || char == "," {
                flush()
            } else {
                current.append(char)
            }
        }
        flush()
        return tokens
    }

    private static func format(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded.rounded() == rounded {
            return String(Int(rounded))
        }
        return String(format: "%.1f", rounded)
    }
}

func strokeDebugLog(_ message: String) {
    #if DEBUG
    print("[StrokeAnimation] \(message)")
    #endif
}
