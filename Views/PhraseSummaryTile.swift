import SwiftUI

enum RadixTileMetrics {
    static let cornerRadius: CGFloat = 8
    static let compactHeight: CGFloat = 56
    static let compactSpacing: CGFloat = 4
    static let defaultPhraseWidth: CGFloat = 180
    static let browsePhraseWidth: CGFloat = 260
    static let defaultCharacterSize: CGFloat = 24
    static let characterPinyinSize: CGFloat = 13
    static let borderWidth: CGFloat = 2
    static let activeBorderWidth: CGFloat = 2.5
}

extension PhraseReviewStatusTool {
    var icon: String {
        switch self {
        case .removed: return "xmark.circle.fill"
        case .checked: return "checkmark.circle.fill"
        case .hidden: return "eye.slash.fill"
        case .new: return "sparkle"
        }
    }

    var color: Color {
        switch self {
        case .removed: return Color.red
        case .checked: return Color.accentColor
        case .hidden: return Color.orange
        case .new: return Color.secondary
        }
    }
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
    let characterFontSize: CGFloat
    let textAlignment: HorizontalAlignment
    let onSelect: (() -> Void)?
    let onToggleFavorite: (() -> Void)?
    let reviewStatus: PhraseReviewStatus?
    let showsReviewStatus: Bool

    init(
        phrase: PhraseItem,
        isFavorite: Bool? = nil,
        isActive: Bool = false,
        minimumHeight: CGFloat = RadixTileMetrics.compactHeight,
        maximumWidth: CGFloat = RadixTileMetrics.defaultPhraseWidth,
        characterFontSize: CGFloat = RadixTileMetrics.defaultCharacterSize,
        textAlignment: HorizontalAlignment = .leading,
        onSelect: (() -> Void)? = nil,
        onToggleFavorite: (() -> Void)? = nil,
        showsReviewStatus: Bool = false
    ) {
        self.phraseText = phrase.word
        self.pinyin = phrase.pinyin
        self.isFavorite = isFavorite
        self.isActive = isActive
        self.minimumHeight = minimumHeight
        self.maximumWidth = maximumWidth
        self.characterFontSize = characterFontSize
        self.textAlignment = textAlignment
        self.onSelect = onSelect
        self.onToggleFavorite = onToggleFavorite
        self.reviewStatus = phrase.reviewStatus
        self.showsReviewStatus = showsReviewStatus
    }

    init(
        phraseText: String,
        pinyin: String,
        isFavorite: Bool? = nil,
        isActive: Bool = false,
        minimumHeight: CGFloat = RadixTileMetrics.compactHeight,
        maximumWidth: CGFloat = RadixTileMetrics.defaultPhraseWidth,
        characterFontSize: CGFloat = RadixTileMetrics.defaultCharacterSize,
        textAlignment: HorizontalAlignment = .leading,
        onSelect: (() -> Void)? = nil,
        onToggleFavorite: (() -> Void)? = nil,
        reviewStatus: PhraseReviewStatus? = nil,
        showsReviewStatus: Bool = false
    ) {
        self.phraseText = phraseText
        self.pinyin = pinyin
        self.isFavorite = isFavorite
        self.isActive = isActive
        self.minimumHeight = minimumHeight
        self.maximumWidth = maximumWidth
        self.characterFontSize = characterFontSize
        self.textAlignment = textAlignment
        self.onSelect = onSelect
        self.onToggleFavorite = onToggleFavorite
        self.reviewStatus = reviewStatus
        self.showsReviewStatus = showsReviewStatus
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            phraseContent

            VStack(spacing: 2) {
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

                if showsReviewStatus {
                    Image(systemName: reviewStatusIcon)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(reviewStatusColor)
                        .padding(6)
                        .accessibilityLabel(reviewStatusTitle)
                }
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
                .font(characterFont)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(displayPinyin)
                .font(pinyinFont)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 10)
        .frame(minWidth: 96, maxWidth: maximumWidth, minHeight: minimumHeight, alignment: frameAlignment)
        .contentShape(Rectangle())
    }

    private var characterFont: Font {
        .system(size: characterFontSize)
    }

    private var pinyinFont: Font {
        ResponsiveFont.tinySystem(size: RadixTileMetrics.characterPinyinSize, weight: .semibold)
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
        if showsReviewStatus, reviewStatus == .removed { return Color.red.opacity(0.08) }
        if showsReviewStatus, reviewStatus == .checked || reviewStatus == .completed { return Color.accentColor.opacity(0.10) }
        if showsReviewStatus, reviewStatus == .hidden { return Color.orange.opacity(0.10) }
        return RadixTheme.secondaryBackground.opacity(0.62)
    }

    private var tileStroke: Color {
        if isActive { return Color.accentColor.opacity(0.8) }
        if isFavorite == true { return Color.yellow.opacity(0.65) }
        if showsReviewStatus, reviewStatus == .removed { return Color.red.opacity(0.38) }
        if showsReviewStatus, reviewStatus == .checked || reviewStatus == .completed { return Color.accentColor.opacity(0.45) }
        if showsReviewStatus, reviewStatus == .hidden { return Color.orange.opacity(0.38) }
        return Color.secondary.opacity(0.22)
    }

    private var favoriteAccessibility: String {
        guard let isFavorite else { return "phrase" }
        return isFavorite ? "favorite phrase" : "phrase"
    }

    private var reviewStatusIcon: String {
        switch reviewStatus {
        case .checked, .completed: return "checkmark.circle.fill"
        case .hidden: return "eye.slash.fill"
        case .removed: return "xmark.circle.fill"
        case nil: return "circle.fill"
        }
    }

    private var reviewStatusColor: Color {
        switch reviewStatus {
        case .checked, .completed: return Color.accentColor
        case .hidden: return Color.orange
        case .removed: return Color.red
        case nil: return Color.secondary.opacity(0.45)
        }
    }

    private var reviewStatusTitle: String {
        reviewStatus?.title ?? "Unreviewed"
    }
}
