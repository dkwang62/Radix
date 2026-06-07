import SwiftUI

#if canImport(PhotosUI)
import PhotosUI

struct CapturePhotoImportButton: View {
    @State private var selectedPhoto: PhotosPickerItem?
    let title: String
    let subtitle: String
    let systemName: String
    let onImage: @MainActor (CapturedImage) -> Void
    let onError: @MainActor (Error) -> Void

    var body: some View {
        PhotosPicker(selection: $selectedPhoto, matching: .images) {
            CaptureImportButtonContent(title: title, subtitle: subtitle, systemName: systemName)
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                do {
                    let image = try await CaptureImageLoader.capturedImage(from: item)
                    await MainActor.run {
                        selectedPhoto = nil
                        onImage(image)
                    }
                } catch {
                    await MainActor.run {
                        selectedPhoto = nil
                        onError(error)
                    }
                }
            }
        }
    }
}

#else

struct CapturePhotoImportButton: View {
    let title: String
    let subtitle: String
    let systemName: String
    let onImage: @MainActor (CapturedImage) -> Void
    let onError: @MainActor (Error) -> Void

    var body: some View {
        Button {
            onError(CocoaError(.featureUnsupported))
        } label: {
            CaptureImportButtonContent(title: title, subtitle: subtitle, systemName: systemName)
        }
    }
}

#endif

private struct CaptureImportButtonContent: View, Sendable {
    let title: String
    let subtitle: String
    let systemName: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 34, height: 34)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ResponsiveFont.body.bold())
                    .lineLimit(1)
                Text(subtitle)
                    .font(ResponsiveFont.caption)
                    .opacity(0.82)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .foregroundStyle(Color.primary)
        .background(RadixTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(RadixTheme.separator.opacity(0.35), lineWidth: 1)
        )
    }
}
