import Foundation

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

func strokeDebugLog(_ message: String) {
    #if DEBUG
    print("[StrokeAnimation] \(message)")
    #endif
}
