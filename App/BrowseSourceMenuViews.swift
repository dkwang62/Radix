import SwiftUI
import UIKit

struct BrowseImageScriptToggle: View {
    @Binding var mode: String

    var body: some View {
        HStack(spacing: 4) {
            scriptButton("简", mode: "simplified", accessibilityLabel: "Read image as simplified Chinese")
            scriptButton("繁", mode: "traditional", accessibilityLabel: "Read image as traditional Chinese")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Image script")
        .accessibilityValue(mode == "traditional" ? "Traditional" : "Simplified")
    }

    private func scriptButton(_ title: String, mode targetMode: String, accessibilityLabel: String) -> some View {
        Button {
            mode = targetMode
        } label: {
            Text(title)
                .font(ResponsiveFont.caption.weight(.semibold))
                .frame(width: 28, height: 28)
                .background(mode == targetMode ? Color.accentColor : Color(.secondarySystemBackground))
                .foregroundStyle(mode == targetMode ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct CollectionAITaskMenu: View {
    let collection: CharacterCollection
    let onManualExtract: () -> Void
    let onAIExtract: () -> Void
    let onTranslate: () -> Void
    let onTranslationReport: () -> Void

    var body: some View {
        Menu {
            Button {
                onManualExtract()
            } label: {
                Label("Extract Phrases by Paste", systemImage: "text.badge.plus")
            }

            Button {
                onAIExtract()
            } label: {
                Label("Extract Phrases Automatically", systemImage: "curlybraces")
            }

            Button {
                onTranslate()
            } label: {
                Label("Translate", systemImage: "translate")
            }

            Button {
                onTranslationReport()
            } label: {
                Label(
                    collection.translationReport == nil ? "Save Translation Report" : "View Translation Report",
                    systemImage: collection.translationReport == nil ? "doc.badge.plus" : "doc.text"
                )
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                Text("AI Link")
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .font(ResponsiveFont.caption2.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(minWidth: 78)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .accessibilityLabel("AI Link actions for \(collection.name)")
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
    let thumbnail: UIImage?
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

                    Text("\(collection.uniqueCharacters.count)/\(collection.characters.count)")
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
        .background(isSelected ? Color.accentColor.opacity(0.10) : Color(.secondarySystemBackground).opacity(0.55))
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
        if let thumbnail {
            Image(uiImage: thumbnail)
                .resizable()
                .scaledToFill()
                .frame(width: 34, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            Image(systemName: collection.isFavorite ? "star.fill" : "photo")
                .font(ResponsiveFont.body)
                .foregroundStyle(collection.isFavorite ? Color.yellow : Color.secondary)
                .frame(width: 34, height: 34)
                .background(Color(.systemBackground).opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
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
                .background(Color(.systemBackground).opacity(0.8))
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
        .background(isSelected ? Color.accentColor.opacity(0.10) : Color(.secondarySystemBackground).opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
