import SwiftUI

struct CaptureHeaderView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    let isProcessing: Bool
    let filePickerTitle: String
    let isImportLocked: Bool
    let freeScanStatusText: String
    let onCamera: () -> Void
    let onLockedImport: () -> Void
    let onAlbumImage: @MainActor @Sendable (CapturedImage) -> Void
    let onAlbumError: @MainActor @Sendable (Error) -> Void
    let onFiles: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if RadixPlatform.isPhone {
                RadixInlineHelpDisclosure(
                    title: "Scan help",
                    message: "Scan real-world Chinese text. Saved pages open in Browse.",
                    systemImage: "camera.viewfinder"
                )
            } else {
                Text("Scan real-world Chinese text. Saved pages open in Browse.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            LazyVGrid(columns: sourceColumns, spacing: 10) {
                Button(action: onCamera) {
                    CaptureSourceButton(
                        title: "Camera",
                        subtitle: freeScanStatusText,
                        systemName: "camera.fill",
                        isPrimary: true
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Camera")
                .disabled(isProcessing)

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

            CaptureWorkflowHint()
        }
    }

    private var sourceColumns: [GridItem] {
        if sizeClass == .compact {
            return [GridItem(.flexible(minimum: 220), spacing: 10)]
        }
        return Array(repeating: GridItem(.flexible(minimum: 150), spacing: 10), count: 3)
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
                .frame(width: 34, height: 34)
                .background((isPrimary ? Color.white : Color.accentColor).opacity(isPrimary ? 0.18 : 0.12))
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

            if let lockBadge {
                Text(lockBadge)
                    .font(ResponsiveFont.caption2.weight(.bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .foregroundStyle(Color.accentColor)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .foregroundStyle(isPrimary ? Color.white : Color.primary)
        .background(isPrimary ? Color.accentColor : RadixTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isPrimary ? Color.accentColor : RadixTheme.separator.opacity(0.35), lineWidth: 1)
        )
    }
}

private struct CaptureWorkflowHint: View {
    private let steps: [(String, String)] = [
        ("1", "Choose image"),
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
        .background(RadixTheme.secondaryBackground.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var stepContent: some View {
        ForEach(steps, id: \.0) { step in
            HStack(spacing: 6) {
                Text(step.0)
                    .font(ResponsiveFont.tinySystem(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 22, height: 22)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(Circle())
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
                .background(RadixTheme.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
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
        .background(color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
        CaptureSection(RadixCopy.savedPages) {
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
        .background(RadixTheme.secondaryBackground.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
                .background(RadixTheme.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
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
