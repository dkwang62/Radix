import SwiftUI

struct PhraseSummaryTile: View {
    let phraseText: String
    let pinyin: String
    let isFavorite: Bool?
    let isActive: Bool
    let minimumHeight: CGFloat
    let maximumWidth: CGFloat
    let onSelect: (() -> Void)?
    let onToggleFavorite: (() -> Void)?

    init(
        phrase: PhraseItem,
        isFavorite: Bool? = nil,
        isActive: Bool = false,
        minimumHeight: CGFloat = 46,
        maximumWidth: CGFloat = 180,
        onSelect: (() -> Void)? = nil,
        onToggleFavorite: (() -> Void)? = nil
    ) {
        self.phraseText = phrase.word
        self.pinyin = phrase.pinyin
        self.isFavorite = isFavorite
        self.isActive = isActive
        self.minimumHeight = minimumHeight
        self.maximumWidth = maximumWidth
        self.onSelect = onSelect
        self.onToggleFavorite = onToggleFavorite
    }

    init(
        phraseText: String,
        pinyin: String,
        isFavorite: Bool? = nil,
        isActive: Bool = false,
        minimumHeight: CGFloat = 46,
        maximumWidth: CGFloat = 180,
        onSelect: (() -> Void)? = nil,
        onToggleFavorite: (() -> Void)? = nil
    ) {
        self.phraseText = phraseText
        self.pinyin = pinyin
        self.isFavorite = isFavorite
        self.isActive = isActive
        self.minimumHeight = minimumHeight
        self.maximumWidth = maximumWidth
        self.onSelect = onSelect
        self.onToggleFavorite = onToggleFavorite
    }

    private var hasFavoriteControl: Bool {
        isFavorite != nil
    }

    var body: some View {
        HStack(spacing: 0) {
            if let isFavorite {
                Button(action: { onToggleFavorite?() }) {
                    Image(systemName: isFavorite ? RadixIcon.saved : RadixIcon.unsaved)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isFavorite ? Color.yellow : Color.secondary.opacity(0.75))
                        .frame(width: 34, height: minimumHeight)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(onToggleFavorite == nil)
                .accessibilityLabel(isFavorite ? "Remove phrase from Favorites" : "Add phrase to Favorites")
            }

            phraseContent
        }
        .background(tileBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(tileStroke, lineWidth: isActive ? 2.5 : 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(phraseText), \(favoriteAccessibility)")
    }

    @ViewBuilder
    private var phraseContent: some View {
        if let onSelect {
            Button(action: onSelect) {
                phraseTextStack
            }
            .buttonStyle(.plain)
        } else {
            phraseTextStack
        }
    }

    private var phraseTextStack: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(phraseText)
                .font(ResponsiveFont.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(displayPinyin)
                .font(ResponsiveFont.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.leading, hasFavoriteControl ? 0 : 10)
        .padding(.trailing, 10)
        .frame(minWidth: hasFavoriteControl ? 74 : 96, maxWidth: maximumWidth, minHeight: minimumHeight, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var displayPinyin: String {
        let trimmed = pinyin.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? " " : trimmed
    }

    private var tileBackground: Color {
        if isActive { return Color.accentColor.opacity(0.16) }
        if isFavorite == true { return Color.yellow.opacity(0.12) }
        return Color(.secondarySystemBackground).opacity(0.62)
    }

    private var tileStroke: Color {
        if isActive { return Color.accentColor.opacity(0.8) }
        if isFavorite == true { return Color.yellow.opacity(0.65) }
        return Color.secondary.opacity(0.22)
    }

    private var favoriteAccessibility: String {
        guard let isFavorite else { return "phrase" }
        return isFavorite ? "favorite phrase" : "phrase"
    }
}
