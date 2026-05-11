import SwiftUI

extension FilterGridTab {
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

    var activeBrowseFilterCount: Int {
        BrowseFilterSummary.activeCount(store: store)
    }

    var filterButtonTitle: String {
        activeBrowseFilterCount > 0 ? "Filters (\(activeBrowseFilterCount))" : "Filters"
    }
}
