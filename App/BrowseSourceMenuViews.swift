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
    let onSelect: (String) -> Void

    var body: some View {
        Menu {
            Button {
                onSelect("task4")
            } label: {
                Label("Extract Phrases (Manual)", systemImage: "text.badge.plus")
            }

            Button {
                onSelect("task6")
            } label: {
                Label("Extract Phrase AI", systemImage: "curlybraces")
            }

            Button {
                onSelect("task5")
            } label: {
                Label("Translate", systemImage: "translate")
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                Text("AI Task")
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .font(ResponsiveFont.caption2.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(minWidth: 92)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .accessibilityLabel("AI Task for \(collection.name)")
    }
}

struct SourceCollectionRow: View {
    let collection: CharacterCollection
    let isSelected: Bool
    let thumbnail: UIImage?
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onSelect) {
                HStack(spacing: 8) {
                    sourceThumbnail

                    Text(collection.name)
                        .font(ResponsiveFont.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
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
        .background(isSelected ? Color.accentColor.opacity(0.10) : Color(.secondarySystemBackground).opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
