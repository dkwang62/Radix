import SwiftUI

extension SmartSearchTab {
    @ViewBuilder
    func searchResults(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 15) {
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.lastSearchQuery.isEmpty ? "Search Results" : "\"\(store.lastSearchQuery)\"")
                        .font(ResponsiveFont.title3.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Text(resultSummaryText)
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        CompactScriptFilterControl(selection: store.scriptFilter) { store.setScriptFilter($0) }
                        clearResultsButton
                    }
                    VStack(alignment: .trailing, spacing: 8) {
                        CompactScriptFilterControl(selection: store.scriptFilter) { store.setScriptFilter($0) }
                        clearResultsButton
                    }
                }
            }
        }
        .padding(12)
        .background(RadixTheme.secondaryBackground.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    var resultSummaryText: String {
        let characterCount = store.filteredResults.count
        let phraseCount = store.filteredSmartPhraseResults.count
        if phraseCount > 0 {
            return "\(characterCount) characters • \(phraseCount) phrases"
        }
        return "\(characterCount) characters"
    }

    var clearResultsButton: some View {
        Button {
            clearSearchResults()
        } label: {
            Image(systemName: "xmark.circle")
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityLabel("Clear Results")
    }

    @ViewBuilder
    var gridInteractionHintRow: some View {
        InteractionHintRow(
            previewText: isRunningOnMac ? "Click to preview" : "Tap to preview",
            memoryText: "Adds to Recent",
            copyText: isRunningOnMac ? "Right-click to copy" : "Long-press to copy"
        )
    }
}
