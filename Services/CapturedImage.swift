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

    init(data: Data, orientation: CGImagePropertyOrientation = .up) throws {
        guard let image = UIImage(data: data) else {
            throw NSError(domain: "Radix", code: 3002, userInfo: [NSLocalizedDescriptionKey: "The selected image could not be loaded."])
        }
        self.data = data
        self.orientation = orientation
        self.previewImage = image
    }

    init(image: UIImage) throws {
        guard let data = image.jpegData(compressionQuality: 0.95) ?? image.pngData() else {
            throw NSError(domain: "Radix", code: 3001, userInfo: [NSLocalizedDescriptionKey: "The selected image could not be read."])
        }
        self.data = data
        self.orientation = CGImagePropertyOrientation(image.imageOrientation)
        self.previewImage = image
    }
    #else
    init(data: Data, orientation: CGImagePropertyOrientation = .up) {
        self.data = data
        self.orientation = orientation
    }
    #endif
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
