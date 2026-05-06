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

struct SavedImageList: View {
    let collections: [CharacterCollection]
    let onOpen: (CharacterCollection) -> Void
    let onDelete: (CharacterCollection) -> Void

    var body: some View {
        CaptureSection("Images") {
            if collections.isEmpty {
                Text("No saved images.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            } else {
                LazyVStack(spacing: 6) {
                    ForEach(collections) { collection in
                        SavedImageRow(
                            collection: collection,
                            onOpen: { onOpen(collection) },
                            onDelete: { onDelete(collection) }
                        )
                    }
                }
            }
        }
    }
}

private struct SavedImageRow: View {
    let collection: CharacterCollection
    let onOpen: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onOpen) {
                HStack(spacing: 8) {
                    thumbnail

                    Text(collection.name)
                        .font(ResponsiveFont.body.weight(.semibold))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("\(collection.uniqueCharacters.count)/\(collection.characters.count)")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel("Delete \(collection.name)")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground).opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image = thumbnailImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 34, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            Image(systemName: "photo")
                .font(ResponsiveFont.body)
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
                .background(Color(.systemBackground).opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private var thumbnailImage: UIImage? {
        guard let data = collection.thumbnailJPEGData else { return nil }
        return UIImage(data: data)
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
