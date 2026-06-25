import SwiftUI

struct BrowseImageScriptToggle: View {
    @Binding var mode: String

    var body: some View {
        CompactScriptToggle(
            isTraditional: mode == "traditional",
            accessibilityLabel: "Image script"
        ) {
            mode = mode == "traditional" ? "simplified" : "traditional"
        }
    }
}

struct CollectionPageActionsMenu: View {
    let collection: CharacterCollection
    let onEdit: () -> Void
    let onCheckOCR: (() -> Void)?
    let hasGeminiAPIKey: Bool
    let onCheckOCRAutomatically: () -> Void
    let onChoosePhrases: () -> Void
    let onViewTranslation: () -> Void
    let onManualExtract: () -> Void
    let onAIExtract: () -> Void
    let onTranslate: () -> Void
    let onTranslateAndSave: () -> Void

    var body: some View {
        Menu {
            Section("Page") {
                Button {
                    onEdit()
                } label: {
                    Label("Edit Page", systemImage: "pencil")
                }

                if let onCheckOCR {
                    Menu {
                        Button {
                            onCheckOCR()
                        } label: {
                            Label("Copy and Paste with ChatGPT", systemImage: "doc.on.clipboard")
                        }

                        Button {
                            onCheckOCRAutomatically()
                        } label: {
                            Label(
                                hasGeminiAPIKey ? "Check Automatically with Gemini" : "Set Up Automatic OCR…",
                                systemImage: hasGeminiAPIKey ? "sparkles" : "key"
                            )
                        }
                    } label: {
                        Label("Check OCR", systemImage: "text.viewfinder")
                    }
                }

                Button {
                    onChoosePhrases()
                } label: {
                    Label("Choose Page Phrases", systemImage: "text.quote")
                }

                Button {
                    onViewTranslation()
                } label: {
                    Label(
                        collection.translationReport == nil ? "Save Translation" : "View Translation",
                        systemImage: collection.translationReport == nil ? "doc.badge.plus" : "doc.text"
                    )
                }
            }

            Section("Use AI by Copy and Paste") {
                Button {
                    onManualExtract()
                } label: {
                    Label("Extract Phrases", systemImage: "text.badge.plus")
                }

                Button {
                    onTranslate()
                } label: {
                    Label("Translate Page", systemImage: "translate")
                }
            }

            Section("Use AI Automatically") {
                Button {
                    onAIExtract()
                } label: {
                    Label("Extract and Add Phrases", systemImage: "curlybraces")
                }

                Button {
                    onTranslateAndSave()
                } label: {
                    Label("Translate and Save", systemImage: "tray.and.arrow.down")
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "ellipsis.circle")
                Text("Actions")
                Image(systemName: "chevron.down")
                    .font(ResponsiveFont.tinySystem(size: 9, weight: .bold))
            }
            .font(ResponsiveFont.caption2.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(minWidth: 82)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityLabel("Page actions for \(collection.name)")
        .help("Page Actions")
    }
}

struct SourceCollectionRow: View {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    let collection: CharacterCollection
    let isSelected: Bool
    let thumbnail: RadixThumbnail?
    var dateMode: PageCollectionSortOrder = .lastViewed
    let onSelect: () -> Void
    var onDelete: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onSelect) {
                HStack(spacing: 8) {
                    sourceThumbnail

                    VStack(alignment: .leading, spacing: 2) {
                        Text(collection.name)
                            .font(ResponsiveFont.body.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(dateText)
                            .font(ResponsiveFont.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text("\(collection.characters.count)")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.accentColor)
                            .font(.system(size: 14))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel("Delete \(collection.name)")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.10) : RadixTheme.secondaryBackground.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var dateText: String {
        switch dateMode {
        case .lastViewed:
            let date = collection.lastViewedAt ?? collection.createdAt
            return "Viewed \(Self.dateFormatter.string(from: date))"
        case .scanned:
            return "Scanned \(Self.dateFormatter.string(from: collection.createdAt))"
        }
    }

    @ViewBuilder
    private var sourceThumbnail: some View {
        RadixThumbnailView(
            thumbnail: thumbnail,
            size: 34,
            cornerRadius: 6,
            placeholderSystemImage: collection.isFavorite ? "star.fill" : "photo",
            placeholderColor: collection.isFavorite ? Color.yellow : Color.secondary
        )
    }
}

struct SourceMenuRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var isSelected = false
    var iconColor: Color = .secondary
    var trailingSystemImage: String?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(ResponsiveFont.body)
                .foregroundStyle(iconColor)
                .frame(width: 34, height: 34)
                .background(RadixTheme.background.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ResponsiveFont.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 4)

            if let trailingSystemImage {
                Image(systemName: trailingSystemImage)
                    .foregroundStyle(Color.accentColor)
                    .font(.system(size: 14))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.accentColor.opacity(0.10) : RadixTheme.secondaryBackground.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
