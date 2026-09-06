import Foundation
import ImageIO

#if canImport(PhotosUI)
import CoreTransferable
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
#endif

enum CaptureImageThumbnailer {
    static func makeJPEGData(from image: CapturedImage, maxDimension: CGFloat = 240) -> Data? {
        CaptureImageDownsampler.makeJPEGData(
            from: image.data,
            maxDimension: Int(maxDimension),
            orientation: image.orientation,
            applyOrientationTransform: true,
            compressionQuality: 0.65
        )
    }
}

enum CaptureImageDownsampler {
    static func makeJPEGData(
        from data: Data,
        maxDimension: Int,
        orientation: CGImagePropertyOrientation,
        applyOrientationTransform: Bool = false,
        compressionQuality: Double = 0.85
    ) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [
            kCGImageSourceShouldCache: false
        ] as CFDictionary) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: applyOrientationTransform,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, thumbnail, [
            kCGImageDestinationLossyCompressionQuality: compressionQuality,
            kCGImagePropertyOrientation: applyOrientationTransform
                ? CGImagePropertyOrientation.up.rawValue
                : orientation.rawValue
        ] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}

enum CaptureImageLoader {
    #if canImport(PhotosUI)
    static func capturedImage(from item: PhotosPickerItem) async throws -> CapturedImage {
        try Task.checkCancellation()
        guard let transfer = try await item.loadTransferable(type: CaptureImageTransfer.self) else {
            throw NSError(domain: "Radix", code: 3002, userInfo: [NSLocalizedDescriptionKey: "The selected image could not be loaded."])
        }
        try Task.checkCancellation()
        return try CapturedImage(data: transfer.data)
    }
    #endif

    static func capturedImage(from urls: [URL]) throws -> CapturedImage? {
        guard let url = urls.first else { return nil }
        let canAccess = url.startAccessingSecurityScopedResource()
        defer {
            if canAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        try CaptureImageResourceValidator.validateFileSize(at: url)
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        try Task.checkCancellation()
        do {
            return try CapturedImage(data: data)
        } catch let error as CaptureImageResourceError {
            throw error
        } catch {
            throw NSError(domain: "Radix", code: 3003, userInfo: [NSLocalizedDescriptionKey: "The selected file is not a readable image."])
        }
    }
}

#if canImport(PhotosUI)
private struct CaptureImageTransfer: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            try CaptureImageResourceValidator.validateFileSize(at: received.file)
            return CaptureImageTransfer(
                data: try Data(contentsOf: received.file, options: .mappedIfSafe)
            )
        }
    }
}
#endif
