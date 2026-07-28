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

/// The shared, interactive Chinese surface for a saved page. Browse and Pages
/// show the same words, phrase tiles, and character-preview behavior.
struct PageTextGrid: View {
    @EnvironmentObject private var store: RadixStore

    let collection: CharacterCollection
    let usesTraditionalScript: Bool
    let layout: BrowseGridLayout
    let characterFontSize: CGFloat
    @Binding var tappedOffset: Int?

    private var items: [BrowseImageGridItem] {
        let phraseTiles = store.browsePagePhraseTiles(in: collection)
        var results: [BrowseImageGridItem] = []
        var offset = 0

        while offset < collection.characters.count {
            if let phraseTile = phraseTiles[offset] {
                results.append(BrowseImageGridItem(offset: offset, kind: .phrase(phraseTile.phrase, phraseTile.offsets)))
                offset = phraseTile.end
            } else {
                results.append(BrowseImageGridItem(offset: offset, kind: .character(collection.characters[offset])))
                offset += 1
            }
        }

        return results
    }

    var body: some View {
        RadixTileFlowLayout(
            horizontalSpacing: RadixTileMetrics.compactSpacing,
            verticalSpacing: RadixTileMetrics.compactSpacing
        ) {
            ForEach(items) { item in
                switch item.kind {
                case .character(let character):
                    characterTile(character, offset: item.offset)
                case .phrase(let phrase, let offsets):
                    phraseTile(phrase, offsets: offsets)
                }
            }
        }
    }

    private func characterTile(_ character: String, offset: Int) -> some View {
        let highlightRole = store.imagePhraseHighlightRole(collectionID: collection.id, offset: offset)
        let isMemoryHighlighted = store.isBrowseMemoryHighlighted(collectionID: collection.id, offset: offset)
        let isActive = highlightRole == .target || tappedOffset == offset
        let pinyin = store.item(for: character)?.pinyinText ?? ""

        return Button {
            tappedOffset = offset
            store.previewImageCharacter(character, offset: offset)
        } label: {
            BrowseGridTileLabel(
                displayCharacter: displayText(character),
                pinyin: pinyin,
                fontSize: characterFontSize,
                isFavorite: store.isFavorite(character),
                background: BrowseImageTileStyle.background(
                    isActive: isActive,
                    highlightRole: highlightRole,
                    isMemoryHighlighted: isMemoryHighlighted
                ),
                stroke: BrowseImageTileStyle.stroke(
                    isActive: isActive,
                    highlightRole: highlightRole,
                    isMemoryHighlighted: isMemoryHighlighted
                ),
                strokeWidth: highlightRole == nil ? 2 : 2.5
            ) {
                store.previewImageCharacter(character, offset: offset, announce: false)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    NotificationCenter.default.post(name: .radixShowPhraseTable, object: character)
                }
            }
            .frame(width: layout.tileMaximumWidth)
        }
        .buttonStyle(.plain)
    }

    private func phraseTile(_ phrase: PhraseItem, offsets: [Int]) -> some View {
        let isActive = offsets.contains(tappedOffset ?? -1)

        return BrowseImagePhraseTile(
            phraseText: displayText(phrase.word),
            pinyin: phrase.pinyin,
            isActive: isActive,
            fontSize: characterFontSize,
            contextMenuPhrase: phrase
        ) {
            if let offset = offsets.first, collection.characters.indices.contains(offset) {
                tappedOffset = offset
            }
            store.presentPhraseFromBrowseImageTile(phrase, in: collection, offsets: Set(offsets))
        }
        .frame(maxWidth: phraseTileWidth(for: offsets.count))
    }

    private func displayText(_ text: String) -> String {
        usesTraditionalScript ? store.traditionalText(text) : store.simplifiedText(text)
    }

    private func phraseTileWidth(for characterCount: Int) -> CGFloat {
        let tileWidth = layout.tileMaximumWidth
        let spacing = RadixTileMetrics.compactSpacing
        return min(
            RadixTileMetrics.browsePhraseWidth,
            tileWidth * CGFloat(max(2, characterCount)) + spacing * CGFloat(max(1, characterCount - 1))
        )
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
