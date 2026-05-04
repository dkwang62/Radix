import SwiftUI
import PhotosUI
import UIKit

struct CaptureHeaderView: View {
    @Binding var selectedPhoto: PhotosPickerItem?
    let isProcessing: Bool
    let filePickerTitle: String
    let onCamera: () -> Void
    let onFiles: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Extract Chinese text from images using Apple Vision", systemImage: "camera")
                .font(ResponsiveFont.subheadline)
                .foregroundStyle(.secondary)

            HStack(alignment: .center, spacing: 10) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("Album", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isProcessing)

                Button(action: onCamera) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isProcessing)

                Button(action: onFiles) {
                    Label(filePickerTitle, systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isProcessing)
            }
        }
    }
}

struct CaptureImagePreview: View {
    let image: UIImage?

    var body: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 260)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct CaptureStatusMessages: View {
    let errorMessage: String?
    let statusMessage: String?

    var body: some View {
        if let errorMessage {
            Text(errorMessage)
                .font(ResponsiveFont.caption)
                .foregroundStyle(.red)
        }
        if let statusMessage {
            Text(statusMessage)
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct CaptureSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(ResponsiveFont.caption.bold())
                .foregroundStyle(.secondary)
            content()
        }
    }
}

struct ImageWorkbenchPanel<Footer: View>: View {
    let isBrowseDisabled: Bool
    let onBrowseSavedImages: () -> Void
    @ViewBuilder let footer: () -> Footer

    init(
        isBrowseDisabled: Bool,
        onBrowseSavedImages: @escaping () -> Void,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.isBrowseDisabled = isBrowseDisabled
        self.onBrowseSavedImages = onBrowseSavedImages
        self.footer = footer
    }

    var body: some View {
        CaptureSection("Image Workbench") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Create and process images here. Browse saved image characters in Browse.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)

                Button(action: onBrowseSavedImages) {
                    Label("Browse Saved Images", systemImage: "square.grid.2x2")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isBrowseDisabled)

                footer()
            }
        }
    }
}

struct CaptureCharactersSection: View {
    let characters: [String]
    let characterItems: [ComponentItem]
    @Binding var currentPage: Int
    @Binding var charactersText: String
    let onReadAloud: () -> Void
    let onClear: () -> Void
    let onPreview: (String) -> Void
    let onSelect: () -> Void

    var body: some View {
        CaptureSection("Characters") {
            HStack(spacing: 10) {
                Button(action: onReadAloud) {
                    Label("Read Aloud", systemImage: "speaker.wave.2")
                }
                .buttonStyle(.bordered)
                .disabled(characters.isEmpty)

                Button("Clear", action: onClear)
                    .buttonStyle(.bordered)
            }

            if characterItems.isEmpty {
                Text("No Chinese characters found yet.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            } else {
                SmartResultsGrid(
                    items: characterItems,
                    currentPage: $currentPage,
                    onPreview: onPreview,
                    onSelect: onSelect,
                    readOnTap: true
                )
            }

            TextEditor(text: $charactersText)
                .font(ResponsiveFont.body)
                .frame(minHeight: 70)
                .padding(6)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
