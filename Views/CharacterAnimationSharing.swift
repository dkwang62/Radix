import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

func copyToClipboard(_ value: String) {
    #if canImport(UIKit)
    UIPasteboard.general.string = value
    #elseif canImport(AppKit)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(value, forType: .string)
    #endif
}

@MainActor
func showPhraseTable(for character: String, using store: RadixStore) {
    store.preview(character: character, announce: false)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        NotificationCenter.default.post(name: .radixShowPhraseTable, object: character)
    }
}

func shareAnimation(for character: String) {
    let trimmed = character.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.isSingleChineseCharacter else {
        return
    }

    Task {
        do {
            let gifURL = try await HanziWriterGIFExporter.export(character: trimmed)
            await presentShareSheet(items: [gifURL])
        } catch {
            debugPrint("Could not create animation for \(trimmed): \(error)")
        }
    }
}

@MainActor
func openAnimationInBrowser(for character: String) {
    guard let url = hostedHanziWriterAnimationURL(for: character) else {
        return
    }

    #if canImport(UIKit)
    UIApplication.shared.open(url)
    #elseif canImport(AppKit)
    NSWorkspace.shared.open(url)
    #endif
}

func copyAnimationPlayerLink(for character: String) {
    guard let url = hostedHanziWriterAnimationURL(for: character) else {
        return
    }
    copyToClipboard(url.absoluteString)
}

func hostedHanziWriterAnimationURL(for character: String) -> URL? {
    let trimmed = character.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.isSingleChineseCharacter else {
        return nil
    }

    var components = URLComponents(string: "https://dkwang62.github.io/Radix/animate.html")
    components?.queryItems = [
        URLQueryItem(name: "char", value: trimmed)
    ]
    return components?.url
}

@MainActor
private func presentShareSheet(items: [Any]) {
    #if canImport(UIKit)
    guard let presenter = UIApplication.shared.radixTopMostViewController else { return }
    let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
    controller.popoverPresentationController?.sourceView = presenter.view
    controller.popoverPresentationController?.sourceRect = CGRect(
        x: presenter.view.bounds.midX,
        y: presenter.view.bounds.midY,
        width: 1,
        height: 1
    )
    presenter.present(controller, animated: true)
    #elseif canImport(AppKit)
    guard let window = NSApplication.shared.keyWindow,
          let view = window.contentView else { return }
    let picker = NSSharingServicePicker(items: items)
    picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
    #endif
}

private enum HanziWriterGIFExporter {
    private static let canvasSize = 360
    private static let padding: CGFloat = 28
    private static let strokeFrameDelay = 0.16
    private static let holdFrameDelay = 0.8

    static func export(character: String) async throws -> URL {
        let data = try await fetchStrokeData(for: character)
        let frames = renderFrames(from: data)
        let safeName = character.unicodeScalars.map { String(format: "%04X", $0.value) }.joined(separator: "-")
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Radix-\(safeName)-stroke-order.gif")

        try writeGIF(frames: frames, to: outputURL)
        return outputURL
    }

    private static func fetchStrokeData(for character: String) async throws -> HanziWriterStrokeData {
        guard let encodedCharacter = character.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://cdn.jsdelivr.net/npm/hanzi-writer-data@latest/\(encodedCharacter).json") else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(HanziWriterStrokeData.self, from: data)
    }

    private static func renderFrames(from data: HanziWriterStrokeData) -> [GIFFrame] {
        let paths = data.strokes.compactMap { HanziSVGPathParser.parse($0) }
        guard !paths.isEmpty else { return [] }

        var frames: [GIFFrame] = [
            GIFFrame(image: render(paths: paths, completedCount: 0), delay: strokeFrameDelay)
        ]

        for index in paths.indices {
            frames.append(GIFFrame(image: render(paths: paths, completedCount: index, activeIndex: index, activeAlpha: 0.5), delay: strokeFrameDelay))
            frames.append(GIFFrame(image: render(paths: paths, completedCount: index + 1), delay: strokeFrameDelay))
        }

        frames.append(GIFFrame(image: render(paths: paths, completedCount: paths.count), delay: holdFrameDelay))
        return frames
    }

    private static func render(paths: [CGPath], completedCount: Int, activeIndex: Int? = nil, activeAlpha: CGFloat = 1) -> CGImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 2
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: canvasSize, height: canvasSize), format: format)

        let image = renderer.image { context in
            let cgContext = context.cgContext
            UIColor.white.setFill()
            cgContext.fill(CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize))

            var transform = hanziTransform(size: CGFloat(canvasSize), padding: padding)

            UIColor(white: 0.88, alpha: 1).setFill()
            for path in paths {
                cgContext.addPath(path.copy(using: &transform) ?? path)
                cgContext.fillPath()
            }

            UIColor(white: 0.18, alpha: 1).setFill()
            for path in paths.prefix(completedCount) {
                cgContext.addPath(path.copy(using: &transform) ?? path)
                cgContext.fillPath()
            }

            if let activeIndex, paths.indices.contains(activeIndex) {
                UIColor(white: 0.18, alpha: activeAlpha).setFill()
                cgContext.addPath(paths[activeIndex].copy(using: &transform) ?? paths[activeIndex])
                cgContext.fillPath()
            }
        }

        return image.cgImage!
    }

    private static func hanziTransform(size: CGFloat, padding: CGFloat) -> CGAffineTransform {
        let minX: CGFloat = 0
        let minY: CGFloat = -124
        let hanziWidth: CGFloat = 1024
        let drawableSize = size - (padding * 2)
        let scale = drawableSize / hanziWidth
        let xOffset = padding - (minX * scale)
        let yOffset = padding - (minY * scale)

        return CGAffineTransform(a: scale, b: 0, c: 0, d: -scale, tx: xOffset, ty: size - yOffset)
    }

    private static func writeGIF(frames: [GIFFrame], to url: URL) throws {
        guard !frames.isEmpty else {
            throw CocoaError(.fileWriteUnknown)
        }

        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.gif.identifier as CFString,
            frames.count,
            nil
        ) else {
            throw CocoaError(.fileWriteUnknown)
        }

        let gifProperties = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFLoopCount: 0
            ]
        ] as CFDictionary
        CGImageDestinationSetProperties(destination, gifProperties)

        for frame in frames {
            let frameProperties = [
                kCGImagePropertyGIFDictionary: [
                    kCGImagePropertyGIFDelayTime: frame.delay
                ]
            ] as CFDictionary
            CGImageDestinationAddImage(destination, frame.image, frameProperties)
        }

        guard CGImageDestinationFinalize(destination) else {
            throw CocoaError(.fileWriteUnknown)
        }
    }
}

private struct HanziWriterStrokeData: Decodable {
    let strokes: [String]
}

private struct GIFFrame {
    let image: CGImage
    let delay: Double
}

private enum HanziSVGPathParser {
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

extension String {
    var isSingleChineseCharacter: Bool {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 1, let scalar = trimmed.unicodeScalars.first else { return false }
        return (0x3400...0x4DBF).contains(scalar.value)
            || (0x2E80...0x2EFF).contains(scalar.value)
            || (0x2F00...0x2FDF).contains(scalar.value)
            || (0x4E00...0x9FFF).contains(scalar.value)
            || (0x20000...0x2EBEF).contains(scalar.value)
    }
}

#if canImport(UIKit)
private extension UIApplication {
    var radixTopMostViewController: UIViewController? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController?
            .radixTopMostPresentedViewController
    }
}

private extension UIViewController {
    var radixTopMostPresentedViewController: UIViewController {
        if let presentedViewController {
            return presentedViewController.radixTopMostPresentedViewController
        }
        if let navigationController = self as? UINavigationController {
            return navigationController.visibleViewController?.radixTopMostPresentedViewController ?? navigationController
        }
        if let tabBarController = self as? UITabBarController {
            return tabBarController.selectedViewController?.radixTopMostPresentedViewController ?? tabBarController
        }
        return self
    }
}
#endif
