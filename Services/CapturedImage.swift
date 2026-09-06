import Foundation
import ImageIO
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct CapturedImage {
    let data: Data
    let orientation: CGImagePropertyOrientation

    #if canImport(UIKit)
    let previewImage: UIImage

    init(data: Data, orientation: CGImagePropertyOrientation? = nil) throws {
        let properties = CGImageSourceCopyImageProperties(data)
        try CaptureImageResourceValidator.validate(
            encodedByteCount: data.count,
            pixelWidth: properties?.width ?? 0,
            pixelHeight: properties?.height ?? 0
        )
        let effectiveOrientation = orientation ?? properties?.orientation ?? .up
        let boundedData: Data
        if let properties,
           CaptureImageResourceBudget.requiresDownsampling(
               pixelWidth: properties.width,
               pixelHeight: properties.height
           ) {
            guard let downsampledData = CaptureImageDownsampler.makeJPEGData(
                from: data,
                maxDimension: CaptureImageResourceBudget.maximumRecognitionDimension,
                orientation: effectiveOrientation
            ) else {
                throw CaptureImageResourceError.unreadable
            }
            boundedData = downsampledData
        } else {
            boundedData = data
        }
        guard let image = UIImage(data: boundedData) else {
            throw NSError(domain: "Radix", code: 3002, userInfo: [NSLocalizedDescriptionKey: "The selected image could not be loaded."])
        }
        self.data = boundedData
        self.orientation = effectiveOrientation
        self.previewImage = image
    }

    init(image: UIImage) throws {
        let pixelWidth = Int(image.size.width * image.scale)
        let pixelHeight = Int(image.size.height * image.scale)
        try CaptureImageResourceValidator.validate(
            encodedByteCount: 0,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight
        )

        let preparedImage: UIImage
        let preparedOrientation: CGImagePropertyOrientation
        if CaptureImageResourceBudget.requiresDownsampling(
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight
        ) {
            let scale = min(
                CGFloat(CaptureImageResourceBudget.maximumRecognitionDimension) / CGFloat(pixelWidth),
                CGFloat(CaptureImageResourceBudget.maximumRecognitionDimension) / CGFloat(pixelHeight)
            )
            let targetSize = CGSize(
                width: max(1, CGFloat(pixelWidth) * scale),
                height: max(1, CGFloat(pixelHeight) * scale)
            )
            guard let thumbnail = image.preparingThumbnail(of: targetSize) else {
                throw CaptureImageResourceError.unreadable
            }
            preparedImage = thumbnail
            preparedOrientation = .up
        } else {
            preparedImage = image
            preparedOrientation = CGImagePropertyOrientation(image.imageOrientation)
        }

        guard let data = preparedImage.jpegData(compressionQuality: 0.95) ?? preparedImage.pngData() else {
            throw NSError(domain: "Radix", code: 3001, userInfo: [NSLocalizedDescriptionKey: "The selected image could not be read."])
        }
        try CaptureImageResourceValidator.validate(
            encodedByteCount: data.count,
            pixelWidth: Int(preparedImage.size.width * preparedImage.scale),
            pixelHeight: Int(preparedImage.size.height * preparedImage.scale)
        )
        self.data = data
        self.orientation = preparedOrientation
        self.previewImage = preparedImage
    }
    #else
    init(data: Data, orientation: CGImagePropertyOrientation? = nil) {
        self.data = data
        self.orientation = orientation ?? CaptureImageOrientationMetadata.orientation(in: data)
    }
    #endif
}

private struct CaptureImageProperties {
    let width: Int
    let height: Int
    let orientation: CGImagePropertyOrientation
}

private func CGImageSourceCopyImageProperties(_ data: Data) -> CaptureImageProperties? {
    guard let source = CGImageSourceCreateWithData(data as CFData, [
        kCGImageSourceShouldCache: false
    ] as CFDictionary),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
          let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue else {
        return nil
    }
    let rawOrientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.uint32Value
    return CaptureImageProperties(
        width: width,
        height: height,
        orientation: rawOrientation.flatMap(CGImagePropertyOrientation.init(rawValue:)) ?? .up
    )
}

enum CaptureImageResourceError: LocalizedError {
    case encodedBytes
    case pixels
    case unreadable

    var errorDescription: String? {
        switch self {
        case .encodedBytes:
            "This image file is larger than Radix can process safely (64 MB). Choose a smaller image or export a reduced copy and try again."
        case .pixels:
            "This image has more than 64 megapixels, which Radix cannot process safely. Choose a smaller image or export a reduced copy and try again."
        case .unreadable:
            "The selected image could not be loaded."
        }
    }
}

enum CaptureImageResourceValidator {
    static func validateFileSize(at url: URL) throws {
        let fileSize = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize
        if let fileSize, fileSize > CaptureImageResourceBudget.maximumEncodedByteCount {
            throw CaptureImageResourceError.encodedBytes
        }
    }

    static func validate(encodedByteCount: Int, pixelWidth: Int, pixelHeight: Int) throws {
        switch CaptureImageResourceBudget.violation(
            encodedByteCount: encodedByteCount,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight
        ) {
        case .encodedBytes:
            throw CaptureImageResourceError.encodedBytes
        case .pixels:
            throw CaptureImageResourceError.pixels
        case nil:
            return
        }
    }
}

extension CapturedImage {
    var preview: Image? {
        #if canImport(UIKit)
        Image(uiImage: previewImage)
        #else
        nil
        #endif
    }
}

#if canImport(UIKit)
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
#endif
