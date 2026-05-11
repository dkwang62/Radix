import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
#endif

enum HanziWriterGIFExporter {
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
        #if canImport(UIKit)
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
        #else
        fatalError("GIF export rendering requires UIKit")
        #endif
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
