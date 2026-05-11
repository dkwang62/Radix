import SwiftUI

extension SmartSearchTab {
    @ViewBuilder
    func searchResults(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            phoneSearchPreviewIfNeeded
            searchResultsHeader
            gridInteractionHintRow

            SmartResultsGrid(
                items: store.filteredResults,
                currentPage: $searchGridPage,
                onPreview: { character in
                    setSearchDrilldownAnchor(character)
                },
                onSelect: { withAnimation { proxy.scrollTo("searchTop", anchor: .top) } }
            )

            phraseDrilldown(proxy: proxy)
            initialPhraseMatches(proxy: proxy)

            if store.filteredResults.isEmpty && store.filteredSmartPhraseResults.isEmpty {
                ContentUnavailableView.search(text: store.lastSearchQuery)
            }
        }
    }

    var searchResultsHeader: some View {
        HStack {
            Text("\(store.filteredResults.count) characters for \"\(store.lastSearchQuery)\"")
                .font(ResponsiveFont.title3)
            Spacer()
            CompactScriptFilterControl(selection: store.scriptFilter) { store.setScriptFilter($0) }
            Button("Clear Results") {
                clearSearchResults()
            }
            .font(ResponsiveFont.caption)
        }
    }

    @ViewBuilder
    var gridInteractionHintRow: some View {
        InteractionHintRow(
            previewText: isRunningOnMac ? "Click to preview" : "Tap to preview",
            memoryText: "Preview adds to 🕘",
            copyText: isRunningOnMac ? "Right-click to copy" : "Long-press to copy"
        )
    }
}
