import Foundation
import SwiftUI

enum HanziSVGPathParser {
    static func parse(_ path: String) -> CGPath? {
        let tokens = tokenize(path)
        guard !tokens.isEmpty else { return nil }

        let mutablePath = CGMutablePath()
        var index = 0
        var command: String?
        var current = CGPoint.zero
        var firstPoint = CGPoint.zero

        while index < tokens.count {
            if tokens[index].isSVGCommand {
                command = tokens[index]
                index += 1
            }

            guard let activeCommand = command else { break }

            switch activeCommand {
            case "M", "m":
                guard let point = readPoint(tokens, &index, relativeTo: activeCommand == "m" ? current : nil) else { return mutablePath }
                mutablePath.move(to: point)
                current = point
                firstPoint = point
                if activeCommand == "M" { command = "L" } else { command = "l" }
            case "L", "l":
                guard let point = readPoint(tokens, &index, relativeTo: activeCommand == "l" ? current : nil) else { return mutablePath }
                mutablePath.addLine(to: point)
                current = point
            case "Q", "q":
                guard let control = readPoint(tokens, &index, relativeTo: activeCommand == "q" ? current : nil),
                      let end = readPoint(tokens, &index, relativeTo: activeCommand == "q" ? current : nil) else { return mutablePath }
                mutablePath.addQuadCurve(to: end, control: control)
                current = end
            case "C", "c":
                guard let control1 = readPoint(tokens, &index, relativeTo: activeCommand == "c" ? current : nil),
                      let control2 = readPoint(tokens, &index, relativeTo: activeCommand == "c" ? current : nil),
                      let end = readPoint(tokens, &index, relativeTo: activeCommand == "c" ? current : nil) else { return mutablePath }
                mutablePath.addCurve(to: end, control1: control1, control2: control2)
                current = end
            case "Z", "z":
                mutablePath.closeSubpath()
                current = firstPoint
            default:
                return mutablePath
            }
        }

        return mutablePath
    }

    private static func tokenize(_ path: String) -> [String] {
        let pattern = "[A-Za-z]|[-+]?(?:\\d*\\.\\d+|\\d+)(?:[eE][-+]?\\d+)?"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(path.startIndex..<path.endIndex, in: path)
        return regex.matches(in: path, range: range).compactMap { match in
            guard let tokenRange = Range(match.range, in: path) else { return nil }
            return String(path[tokenRange])
        }
    }

    private static func readPoint(_ tokens: [String], _ index: inout Int, relativeTo origin: CGPoint?) -> CGPoint? {
        guard index + 1 < tokens.count,
              let x = Double(tokens[index]),
              let y = Double(tokens[index + 1]) else {
            return nil
        }
        index += 2

        if let origin {
            return CGPoint(x: origin.x + x, y: origin.y + y)
        }
        return CGPoint(x: x, y: y)
    }
}

private extension String {
    var isSVGCommand: Bool {
        count == 1 && range(of: "[A-Za-z]", options: .regularExpression) != nil
    }
}
