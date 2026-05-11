import SwiftUI

extension FilterGridTab {
    @ViewBuilder
    func browseContent(proxy: ScrollViewProxy) -> some View {
        if isPhoneBrowseLayout {
            browseHintIfNeeded
        }

        if let collection = store.selectedBrowseCollection {
            imageGridContent(collection: collection, proxy: proxy)
        } else {
            smartGridContent(proxy: proxy)
        }
    }

    @ViewBuilder
    func phoneBrowsePreview(proxy: ScrollViewProxy) -> some View {
        BrowsePhonePreview(
            phrase: store.activeSidebarPhrasePreview,
            character: store.previewCharacter,
            onReturn: { returnToBrowse(proxy: proxy) }
        )
        .environmentObject(store)
    }

    var dictionaryGridSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 35, coordinateSpace: .local)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > 70, abs(horizontal) > abs(vertical) * 1.35 else { return }

                withAnimation(.easeInOut(duration: 0.18)) {
                    if horizontal < 0 {
                        store.nextGridPage()
                    } else {
                        store.previousGridPage()
                    }
                }
            }
    }

    var dictionaryGridFooter: some View {
        DictionaryGridFooter(
            totalCount: store.allGridItems.count,
            page: store.gridPage,
            pageSize: store.gridBatchSize,
            pageCount: store.gridPageCount,
            onPrevious: {
                store.previousGridPage()
            },
            onNext: {
                store.nextGridPage()
            }
        )
    }

    @ViewBuilder
    var smartGridControls: some View {
        let isComponents = store.gridSortMode == .componentFrequency
        let componentsToggle = Button {
            store.setGridSortMode(isComponents ? .characterFrequency : .componentFrequency)
        } label: {
            Text("Components")
                .font(ResponsiveFont.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isComponents ? Color.accentColor : Color(.secondarySystemBackground))
                .foregroundStyle(isComponents ? Color.white : Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)

        let filterButton = Button {
            showBrowseFilters = true
        } label: {
            Text("▽")
                .font(ResponsiveFont.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(filterButtonTitle)

        HStack(alignment: .center, spacing: 8) {
            componentsToggle
            CompactScriptFilterControl(selection: store.gridScriptFilter) { store.setGridScriptFilter($0) }
            filterButton
        }
    }

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
                let isActive = highlightRole == .target
                let pinyin = store.item(for: character)?.pinyinText ?? ""
                Button {
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

    @ViewBuilder
    func smartGridContent(proxy: ScrollViewProxy) -> some View {
        if !isPhoneBrowseLayout {
            browseHintIfNeeded
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
        }

        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(store.pagedGridItems, id: \.character) { item in
                let isActive = item.character == store.previewCharacter || item.character == store.browseHighlightedCharacter
                Button {
                    store.highlightBrowseDictionaryCharacter(item.character)
                    store.speakCharacter(item.character)
                    store.preview(character: item.character)
                    scrollToBrowseTile(dictionaryTileAnchorID(item.character), proxy: proxy)
                } label: {
                    BrowseGridTileLabel(
                        displayCharacter: item.character,
                        pinyin: item.pinyinText,
                        fontSize: fontSize,
                        isFavorite: store.isFavorite(item.character),
                        background: isActive ? Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground),
                        stroke: isActive ? Color.accentColor : Color.clear
                    )
                }
                .buttonStyle(.plain)
                .id(dictionaryTileAnchorID(item.character))
            }
        }
        .simultaneousGesture(dictionaryGridSwipeGesture)

        dictionaryGridFooter
    }

    @ViewBuilder
    var browseHintIfNeeded: some View {
        if showBrowseInteractionHint && store.showBrowseHelp {
            browseInteractionHintRow
        }
    }
}
