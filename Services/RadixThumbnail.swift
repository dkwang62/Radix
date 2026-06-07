import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

struct RadixThumbnail: Equatable {
    let data: Data

    init?(jpegData: Data?) {
        guard let jpegData else { return nil }
        self.data = jpegData
    }

    var image: Image? {
        #if canImport(UIKit)
        guard let image = UIImage(data: data) else { return nil }
        return Image(uiImage: image)
        #elseif canImport(AppKit)
        guard let image = NSImage(data: data) else { return nil }
        return Image(nsImage: image)
        #else
        return nil
        #endif
    }
}

struct RadixThumbnailView: View {
    let thumbnail: RadixThumbnail?
    var size: CGFloat
    var cornerRadius: CGFloat
    var placeholderSystemImage: String = "photo"
    var placeholderColor: Color = .secondary

    var body: some View {
        if let image = thumbnail?.image {
            image
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            Image(systemName: placeholderSystemImage)
                .font(ResponsiveFont.body)
                .foregroundStyle(placeholderColor)
                .frame(width: size, height: size)
                .background(RadixTheme.background.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}
