import Foundation
import ImageIO

#if canImport(PhotosUI)
import PhotosUI
import SwiftUI
#endif

enum CaptureImageThumbnailer {
    static func makeJPEGData(from image: CapturedImage, maxDimension: CGFloat = 240) -> Data? {
        guard let source = CGImageSourceCreateWithData(image.data as CFData, nil) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxDimension)
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, thumbnail, [
            kCGImageDestinationLossyCompressionQuality: 0.65
        ] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}

enum CaptureImageLoader {
    #if canImport(PhotosUI)
    static func capturedImage(from item: PhotosPickerItem) async throws -> CapturedImage {
        guard let data = try await item.loadTransferable(type: Data.self) else {
            throw NSError(domain: "Radix", code: 3002, userInfo: [NSLocalizedDescriptionKey: "The selected image could not be loaded."])
        }
        return try CapturedImage(data: data)
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

        let data = try Data(contentsOf: url)
        do {
            return try CapturedImage(data: data)
        } catch {
            throw NSError(domain: "Radix", code: 3003, userInfo: [NSLocalizedDescriptionKey: "The selected file is not a readable image."])
        }
    }
}
