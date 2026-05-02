import Foundation
import PhotosUI
import SwiftUI
import UIKit
@preconcurrency import Vision
import ImageIO

final class CaptureOCRService {
    func recognizeText(in image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw NSError(domain: "Radix", code: 3001, userInfo: [NSLocalizedDescriptionKey: "The selected image could not be read."])
        }

        return try await withCheckedThrowingContinuation { continuation in
            let orientation = CGImagePropertyOrientation(image.imageOrientation)

            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest { request, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    let observations = (request.results as? [VNRecognizedTextObservation] ?? [])
                        .sorted {
                            // Vision boundingBox origin is bottom-left, so higher Y = higher on screen.
                            // Group lines by proximity (within 1% of image height) before sorting left-to-right.
                            let yDiff = abs($0.boundingBox.midY - $1.boundingBox.midY)
                            if yDiff > 0.01 {
                                return $0.boundingBox.midY > $1.boundingBox.midY  // top-to-bottom
                            }
                            return $0.boundingBox.minX < $1.boundingBox.minX      // left-to-right within same row
                        }
                    let lines = observations.compactMap { observation in
                        observation.topCandidates(1).first?.string
                    }
                    continuation.resume(returning: lines.joined(separator: "\n"))
                }

                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]

                let handler = VNImageRequestHandler(
                    cgImage: cgImage,
                    orientation: orientation,
                    options: [:]
                )

                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

enum CaptureImageThumbnailer {
    static func makeJPEGData(from image: UIImage, maxDimension: CGFloat = 240) -> Data? {
        let size = image.size
        guard size.width > 0, size.height > 0 else {
            return image.jpegData(compressionQuality: 0.65)
        }

        let scale = min(maxDimension / size.width, maxDimension / size.height, 1)
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return rendered.jpegData(compressionQuality: 0.65)
    }
}

enum CaptureImageLoader {
    static func image(from item: PhotosPickerItem) async throws -> UIImage {
        guard let data = try await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            throw NSError(domain: "Radix", code: 3002, userInfo: [NSLocalizedDescriptionKey: "The selected image could not be loaded."])
        }
        return image
    }

    static func image(from urls: [URL]) throws -> UIImage? {
        guard let url = urls.first else { return nil }
        let canAccess = url.startAccessingSecurityScopedResource()
        defer {
            if canAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url)
        guard let image = UIImage(data: data) else {
            throw NSError(domain: "Radix", code: 3003, userInfo: [NSLocalizedDescriptionKey: "The selected file is not a readable image."])
        }
        return image
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
