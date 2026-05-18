import SwiftUI

enum RadixTileMetrics {
    static let cornerRadius: CGFloat = 8
    static let compactHeight: CGFloat = 52
    static let compactSpacing: CGFloat = 4
    static let defaultPhraseWidth: CGFloat = 180
    static let browsePhraseWidth: CGFloat = 260
    static let characterPinyinSize: CGFloat = 11
    static let borderWidth: CGFloat = 2
    static let activeBorderWidth: CGFloat = 2.5
}

struct RadixTileFlowLayout: Layout {
    var horizontalSpacing: CGFloat = RadixTileMetrics.compactSpacing
    var verticalSpacing: CGFloat = RadixTileMetrics.compactSpacing

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? subviews.map { $0.sizeThatFits(.unspecified).width }.reduce(0, +)
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let proposedWidth = lineWidth == 0 ? size.width : lineWidth + horizontalSpacing + size.width

            if proposedWidth > maxWidth, lineWidth > 0 {
                totalWidth = max(totalWidth, lineWidth)
                totalHeight += lineHeight + verticalSpacing
                lineWidth = size.width
                lineHeight = size.height
            } else {
                lineWidth = proposedWidth
                lineHeight = max(lineHeight, size.height)
            }
        }

        totalWidth = max(totalWidth, lineWidth)
        totalHeight += lineHeight
        return CGSize(width: min(totalWidth, maxWidth), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var origin = CGPoint(x: bounds.minX, y: bounds.minY)
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let proposedMaxX = origin.x == bounds.minX ? origin.x + size.width : origin.x + horizontalSpacing + size.width

            if proposedMaxX > bounds.maxX, origin.x > bounds.minX {
                origin.x = bounds.minX
                origin.y += lineHeight + verticalSpacing
                lineHeight = 0
            } else if origin.x > bounds.minX {
                origin.x += horizontalSpacing
            }

            let width = min(size.width, bounds.width)
            subview.place(
                at: origin,
                proposal: ProposedViewSize(width: width, height: size.height)
            )
            origin.x += width
            lineHeight = max(lineHeight, size.height)
        }
    }
}

struct PhraseSummaryTile: View {
    let phraseText: String
    let pinyin: String
    let isFavorite: Bool?
    let isActive: Bool
    let minimumHeight: CGFloat
    let maximumWidth: CGFloat
    let textAlignment: HorizontalAlignment
    let onSelect: (() -> Void)?
    let onToggleFavorite: (() -> Void)?

    init(
        phrase: PhraseItem,
        isFavorite: Bool? = nil,
        isActive: Bool = false,
        minimumHeight: CGFloat = 46,
        maximumWidth: CGFloat = RadixTileMetrics.defaultPhraseWidth,
        textAlignment: HorizontalAlignment = .leading,
        onSelect: (() -> Void)? = nil,
        onToggleFavorite: (() -> Void)? = nil
    ) {
        self.phraseText = phrase.word
        self.pinyin = phrase.pinyin
        self.isFavorite = isFavorite
        self.isActive = isActive
        self.minimumHeight = minimumHeight
        self.maximumWidth = maximumWidth
        self.textAlignment = textAlignment
        self.onSelect = onSelect
        self.onToggleFavorite = onToggleFavorite
    }

    init(
        phraseText: String,
        pinyin: String,
        isFavorite: Bool? = nil,
        isActive: Bool = false,
        minimumHeight: CGFloat = 46,
        maximumWidth: CGFloat = RadixTileMetrics.defaultPhraseWidth,
        textAlignment: HorizontalAlignment = .leading,
        onSelect: (() -> Void)? = nil,
        onToggleFavorite: (() -> Void)? = nil
    ) {
        self.phraseText = phraseText
        self.pinyin = pinyin
        self.isFavorite = isFavorite
        self.isActive = isActive
        self.minimumHeight = minimumHeight
        self.maximumWidth = maximumWidth
        self.textAlignment = textAlignment
        self.onSelect = onSelect
        self.onToggleFavorite = onToggleFavorite
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            phraseContent

            if isFavorite == true {
                Button(action: { onToggleFavorite?() }) {
                    Image(systemName: RadixIcon.saved)
                        .font(.system(size: 14))
                        .foregroundStyle(.yellow)
                        .padding(6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(onToggleFavorite == nil)
                .accessibilityLabel("Remove phrase from Favorites")
            }
        }
        .background(tileBackground)
        .clipShape(RoundedRectangle(cornerRadius: RadixTileMetrics.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: RadixTileMetrics.cornerRadius)
                .stroke(tileStroke, lineWidth: isActive ? RadixTileMetrics.activeBorderWidth : RadixTileMetrics.borderWidth)
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
        VStack(alignment: textAlignment, spacing: 2) {
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
        .padding(.horizontal, 10)
        .frame(minWidth: 96, maxWidth: maximumWidth, minHeight: minimumHeight, alignment: frameAlignment)
        .contentShape(Rectangle())
    }

    private var frameAlignment: Alignment {
        textAlignment == .center ? .center : .leading
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
