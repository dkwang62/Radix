import SwiftUI

struct BrowseGridTileLabel: View {
    let displayCharacter: String
    let pinyin: String
    let fontSize: CGFloat
    let isFavorite: Bool
    let background: Color
    let stroke: Color
    var strokeWidth: CGFloat = 2
    var matchPhraseTileTextSize: Bool = false
    var onShowPhrases: (() -> Void)?

    var body: some View {
        VStack(spacing: 2) {
            Text(displayCharacter)
                .font(characterFont)
                .copyCharacterContextMenu(displayCharacter, pinyin: pinyin, onShowPhrases: onShowPhrases)
            Text(pinyin.isEmpty ? " " : pinyin)
                .font(pinyinFont)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(stroke, lineWidth: strokeWidth))
        .overlay(alignment: .topTrailing) {
            if isFavorite {
                Image(systemName: "star.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.yellow)
                    .padding(6)
            }
        }
    }

    private var characterFont: Font {
        matchPhraseTileTextSize ? ResponsiveFont.subheadline.weight(.semibold) : .system(size: fontSize)
    }

    private var pinyinFont: Font {
        matchPhraseTileTextSize ? ResponsiveFont.caption2 : ResponsiveFont.tinySystem(size: 11, weight: .semibold)
    }
}

struct BrowseImagePhraseTile: View {
    let phraseText: String
    let pinyin: String
    let fontSize: CGFloat
    let isFavorite: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            PhraseSummaryTile(
                phraseText: phraseText,
                pinyin: pinyin,
                isFavorite: nil,
                minimumHeight: 52,
                maximumWidth: 260
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(phraseText), phrase")
    }
}

struct BrowseImageFlowLayout: Layout {
    var horizontalSpacing: CGFloat = 6
    var verticalSpacing: CGFloat = 6

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

            subview.place(at: origin, proposal: ProposedViewSize(width: min(size.width, bounds.width), height: size.height))
            origin.x += min(size.width, bounds.width)
            lineHeight = max(lineHeight, size.height)
        }
    }
}

struct DictionaryGridFooter: View {
    let totalCount: Int
    let page: Int
    let pageSize: Int
    let pageCount: Int
    let onPrevious: () -> Void
    let onNext: () -> Void

    private var rangeStart: Int {
        totalCount == 0 ? 0 : page * pageSize + 1
    }

    private var rangeEnd: Int {
        min((page + 1) * pageSize, totalCount)
    }

    var body: some View {
        HStack(spacing: 18) {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
                    .frame(width: 36, height: 32)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(page == 0)
            .accessibilityLabel("Previous page")

            Text("\(rangeStart)–\(rangeEnd) of \(totalCount)")
                .font(ResponsiveFont.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .frame(width: 36, height: 32)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(page + 1 >= pageCount)
            .accessibilityLabel("Next page")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}

enum BrowseImageTileStyle {
    static func background(isActive: Bool, highlightRole: ImagePhraseHighlightRole?, isMemoryHighlighted: Bool) -> Color {
        switch highlightRole {
        case .target:
            return Color.accentColor.opacity(0.24)
        case .phraseMember:
            return Color.blue.opacity(0.16)
        case nil:
            if isMemoryHighlighted {
                return Color.accentColor.opacity(0.18)
            }
            return isActive ? Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground)
        }
    }

    static func stroke(isActive: Bool, highlightRole: ImagePhraseHighlightRole?, isMemoryHighlighted: Bool) -> Color {
        switch highlightRole {
        case .target:
            return Color.accentColor
        case .phraseMember:
            return Color.blue.opacity(0.72)
        case nil:
            if isMemoryHighlighted {
                return Color.accentColor
            }
            return isActive ? Color.accentColor : Color.clear
        }
    }
}
