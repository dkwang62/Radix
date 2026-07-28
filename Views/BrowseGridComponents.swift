import SwiftUI

struct BrowseGridTileLabel: View {
    let displayCharacter: String
    let pinyin: String
    let fontSize: CGFloat
    let isFavorite: Bool
    let background: Color
    let stroke: Color
    var strokeWidth: CGFloat = 2
    var onShowPhrases: (() -> Void)?

    var body: some View {
        VStack(spacing: 2) {
            Text(displayCharacter)
                .font(characterFont)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .copyCharacterContextMenu(displayCharacter, pinyin: pinyin, onShowPhrases: onShowPhrases)
            Text(pinyin.isEmpty ? " " : pinyin)
                .font(pinyinFont)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, minHeight: tileHeight, maxHeight: tileHeight, alignment: .center)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: RadixTileMetrics.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: RadixTileMetrics.cornerRadius).stroke(stroke, lineWidth: strokeWidth))
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
        .system(size: fontSize)
    }

    private var pinyinFont: Font {
        ResponsiveFont.tinySystem(size: RadixTileMetrics.characterPinyinSize, weight: .semibold)
    }

    private var tileHeight: CGFloat {
        56
    }

}

struct BrowseImagePhraseTile: View {
    let phraseText: String
    let pinyin: String
    let isActive: Bool
    let fontSize: CGFloat
    var contextMenuPhrase: PhraseItem?
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            phraseTileContent
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(phraseText), phrase")
    }

    @ViewBuilder
    private var phraseTileContent: some View {
        if let contextMenuPhrase {
            phraseTile
                .phraseContextMenu(contextMenuPhrase)
        } else {
            phraseTile
        }
    }

    private var phraseTile: some View {
        PhraseSummaryTile(
            phraseText: phraseText,
            pinyin: pinyin,
            isFavorite: nil,
            isActive: isActive,
            minimumHeight: RadixTileMetrics.compactHeight,
            maximumWidth: RadixTileMetrics.browsePhraseWidth,
            characterFontSize: fontSize,
            textAlignment: .center
        )
        .frame(height: RadixTileMetrics.compactHeight)
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
                RadixCompactChevronLabel(
                    chevronSystemName: "chevron.left",
                    chevronOpacity: 1,
                    width: 36,
                    height: 32
                )
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
                RadixCompactChevronLabel(
                    chevronSystemName: "chevron.right",
                    chevronOpacity: 1,
                    width: 36,
                    height: 32
                )
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
            return RadixAccent.primary.opacity(0.24)
        case .phraseMember:
            return Color.blue.opacity(0.16)
        case nil:
            if isMemoryHighlighted {
                return RadixAccent.primary.opacity(0.18)
            }
            return isActive ? RadixAccent.primary.opacity(0.18) : RadixTheme.secondaryBackground
        }
    }

    static func stroke(isActive: Bool, highlightRole: ImagePhraseHighlightRole?, isMemoryHighlighted: Bool) -> Color {
        switch highlightRole {
        case .target:
            return RadixAccent.primary
        case .phraseMember:
            return Color.blue.opacity(0.72)
        case nil:
            if isMemoryHighlighted {
                return RadixAccent.primary
            }
            return isActive ? RadixAccent.primary : Color.clear
        }
    }
}
