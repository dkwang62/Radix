import SwiftUI

extension FilterGridTab {
    @ViewBuilder
    func imageGridContent(collection: CharacterCollection, proxy: ScrollViewProxy) -> some View {
        let allItems = Array(collection.characters.enumerated())

        if !isPhoneBrowseLayout {
            browseHintIfNeeded
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
        }

        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(allItems, id: \.offset) { offset, character in
                let displayCharacter = browseImageDisplayCharacter(character)
                let highlightRole = store.imagePhraseHighlightRole(collectionID: collection.id, offset: offset)
                let isMemoryHighlighted = store.isBrowseMemoryHighlighted(collectionID: collection.id, offset: offset)
                let isActive = highlightRole == .target || lastTappedImageOffset == offset
                let pinyin = store.item(for: character)?.pinyinText ?? ""
                Button {
                    lastTappedImageOffset = offset
                    let shouldScroll = store.handleImageCharacterTap(character, offset: offset)
                    if shouldScroll {
                        scrollToBrowseTile(activeBrowseTileAnchorID() ?? imageTileAnchorID(offset), proxy: proxy)
                    }
                } label: {
                    BrowseGridTileLabel(
                        displayCharacter: displayCharacter,
                        pinyin: pinyin,
                        fontSize: fontSize,
                        isFavorite: store.isFavorite(character),
                        background: BrowseImageTileStyle.background(isActive: isActive, highlightRole: highlightRole, isMemoryHighlighted: isMemoryHighlighted),
                        stroke: BrowseImageTileStyle.stroke(isActive: isActive, highlightRole: highlightRole, isMemoryHighlighted: isMemoryHighlighted),
                        strokeWidth: highlightRole == nil ? 2 : 2.5
                    ) {
                        store.previewImageCharacter(character, offset: offset, announce: false)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            NotificationCenter.default.post(name: .radixShowPhraseTable, object: character)
                        }
                    }
                }
                .buttonStyle(.plain)
                .id(imageTileAnchorID(offset))
            }
        }
    }

    func browseImageDisplayCharacter(_ character: String) -> String {
        browseImageDisplayText(character)
    }

    func browseImageDisplayText(_ text: String) -> String {
        useTraditionalBrowseImageScript ? store.traditionalText(text) : store.simplifiedText(text)
    }
}
