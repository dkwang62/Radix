import Foundation

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
