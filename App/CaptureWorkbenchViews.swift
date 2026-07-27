import SwiftUI

struct CaptureHeaderView: View {
    let isProcessing: Bool
    let filePickerTitle: String
    let isImportLocked: Bool
    let freeScanStatusText: String
    let onCamera: () -> Void
    let onLockedImport: () -> Void
    let onAlbumImage: @MainActor @Sendable (CapturedImage) -> Void
    let onAlbumError: @MainActor @Sendable (Error) -> Void
    let onFiles: () -> Void
    let onClipboard: () -> Void
    let onText: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if RadixPlatform.isPhone {
                RadixInlineHelpDisclosure(
                    title: "Scan help",
                    message: "Scan real-world Chinese text. Saved pages open in Browse.",
                    systemImage: RadixIcon.scan
                )
            } else {
                Text("Scan real-world Chinese text. Saved pages open in Browse.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            sourceButtons

            CaptureWorkflowHint()
        }
    }

    private var sourceButtons: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                cameraButton
                albumButton
                clipboardButton
                filesButton
                textButton
            }

            VStack(spacing: 10) {
                cameraButton
                albumButton
                clipboardButton
                filesButton
                textButton
            }
        }
    }

    private var cameraButton: some View {
        Button(action: onCamera) {
            CaptureSourceButton(
                title: "Camera",
                subtitle: freeScanStatusText,
                systemName: RadixIcon.scan,
                isPrimary: true
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Camera")
        .disabled(isProcessing)
    }

    @ViewBuilder
    private var albumButton: some View {
        if isImportLocked {
            Button(action: onLockedImport) {
                CaptureSourceButton(
                    title: "Album",
                    subtitle: "Radix Plus",
                    systemName: "photo.on.rectangle",
                    lockBadge: "Plus"
                )
            }
            .buttonStyle(.plain)
            .disabled(isProcessing)
        } else {
            CapturePhotoImportButton(
                title: "Album",
                subtitle: "Photos",
                systemName: "photo.on.rectangle",
                onImage: onAlbumImage,
                onError: onAlbumError
            )
            .buttonStyle(.plain)
            .disabled(isProcessing)
        }
    }

    private var filesButton: some View {
        Button(action: onFiles) {
            CaptureSourceButton(
                title: filePickerTitle,
                subtitle: isImportLocked ? "Radix Plus" : "Import",
                systemName: "folder",
                lockBadge: isImportLocked ? "Plus" : nil
            )
        }
        .buttonStyle(.plain)
        .disabled(isProcessing)
    }

    private var clipboardButton: some View {
        Button(action: onClipboard) {
            CaptureSourceButton(
                title: "Clipboard",
                subtitle: isImportLocked ? "Radix Plus" : "Image",
                systemName: "doc.on.clipboard",
                lockBadge: isImportLocked ? "Plus" : nil
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Image from Clipboard")
        .disabled(isProcessing)
    }

    private var textButton: some View {
        Button(action: onText) {
            CaptureSourceButton(
                title: "Text to Page",
                subtitle: freeScanStatusText,
                systemName: "doc.text"
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Text to Page")
        .disabled(isProcessing)
    }
}

private struct CaptureSourceButton: View {
    let title: String
    let subtitle: String
    let systemName: String
    var isPrimary = false
    var lockBadge: String?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .radixIconButtonSurface(
                    size: 34,
                    background: (isPrimary ? Color.white : RadixAccent.primary).opacity(isPrimary ? 0.18 : 0.12)
                )

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

            if let lockBadge {
                Text(lockBadge)
                    .font(ResponsiveFont.caption2.weight(.bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .foregroundStyle(RadixAccent.primary)
                    .radixSurface(RadixAccent.primary.opacity(0.12), radius: 8)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .foregroundStyle(isPrimary ? Color.white : Color.primary)
        .radixSurface(
            isPrimary ? RadixAccent.primary : RadixTheme.secondaryBackground,
            radius: 8,
            border: isPrimary ? RadixAccent.primary : RadixTheme.separator.opacity(0.35)
        )
    }
}

private struct CaptureWorkflowHint: View {
    private let steps: [(String, String)] = [
        ("1", "Choose source"),
        ("2", "Read text"),
        ("3", "Browse page")
    ]

    var body: some View {
        if RadixPlatform.isPhone {
            RadixInlineHelpDisclosure(
                title: "Workflow",
                message: "Choose an image, let Radix read the Chinese text, then browse the saved page.",
                systemImage: "list.number"
            )
        } else {
            compactBody
        }
    }

    private var compactBody: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { stepContent }
            VStack(alignment: .leading, spacing: 8) { stepContent }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .radixSurface(RadixTheme.secondaryBackground.opacity(0.55), radius: 8)
    }

    private var stepContent: some View {
        ForEach(steps, id: \.0) { step in
            HStack(spacing: 6) {
                Text(step.0)
                    .font(ResponsiveFont.tinySystem(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(RadixAccent.primary)
                    .radixIconButtonSurface(
                        size: 22,
                        background: RadixAccent.primary.opacity(0.12),
                        radius: 11
                    )
                Text(step.1)
                    .font(ResponsiveFont.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

struct CaptureImagePreview: View {
    let image: CapturedImage?

    var body: some View {
        if let preview = image?.preview {
            preview
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 260)
                .frame(maxWidth: .infinity)
                .padding(8)
                .radixSurface(RadixTheme.secondaryBackground, radius: 8)
        }
    }
}

struct CaptureStatusMessages: View {
    let errorMessage: String?
    let statusMessage: String?

    var body: some View {
        if let errorMessage {
            CaptureMessageBanner(message: errorMessage, systemName: "exclamationmark.triangle.fill", color: .red)
        }
        if let statusMessage {
            CaptureMessageBanner(message: statusMessage, systemName: "checkmark.circle.fill", color: .green)
        }
    }
}

private struct CaptureMessageBanner: View {
    let message: String
    let systemName: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemName)
                .foregroundStyle(color)
            Text(message)
                .font(ResponsiveFont.caption)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(10)
        .radixSurface(color.opacity(0.10))
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
        CaptureSection(RadixCopy.pages) {
            SavedImageRows(
                collections: collections,
                emptyDescription: "Scan or import an image.",
                onOpen: onOpen,
                onDelete: onDelete
            )
        }
    }
}

struct SavedImageRows: View {
    let collections: [CharacterCollection]
    var emptyDescription: String
    let onOpen: (CharacterCollection) -> Void
    let onDelete: (CharacterCollection) -> Void

    var body: some View {
        if collections.isEmpty {
            ContentUnavailableView(
                "No Pages",
                systemImage: "photo.on.rectangle.angled",
                description: Text(emptyDescription)
            )
            .frame(maxWidth: .infinity)
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

struct SavedImageRow: View {
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    let collection: CharacterCollection
    let onOpen: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onOpen) {
                HStack(spacing: 8) {
                    thumbnail

                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayName)
                            .font(ResponsiveFont.body.weight(.semibold))
                            .lineLimit(1)
                        Text(Self.dateFormatter.string(from: collection.createdAt))
                            .font(ResponsiveFont.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text("\(collection.uniqueCharacters.count) chars")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel("Delete \(displayName)")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .radixSurface(RadixTheme.secondaryBackground.opacity(0.55), radius: 8)
    }

    @ViewBuilder
    private var thumbnail: some View {
        RadixThumbnailView(
            thumbnail: RadixThumbnail(jpegData: collection.thumbnailJPEGData),
            size: 34,
            cornerRadius: 6
        )
    }

    private var displayName: String {
        let name = collection.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? RadixCopy.savedPage : name
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
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { captureCharacterActions }
                VStack(alignment: .leading, spacing: 8) { captureCharacterActions }
            }

            if characterItems.isEmpty {
                Text("No characters yet.")
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
                .radixSurface(RadixTheme.secondaryBackground, radius: 8)
        }
    }

    private var captureCharacterActions: some View {
        Group {
            Button(action: onReadAloud) {
                Label("Read Aloud", systemImage: "speaker.wave.2")
            }
            .buttonStyle(.bordered)
            .disabled(characters.isEmpty)

            Button(action: onClear) {
                Label("Clear", systemImage: "xmark.circle")
            }
            .buttonStyle(.bordered)
        }
    }
}
