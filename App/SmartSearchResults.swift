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
                onSelect: { withAnimation { proxy.scrollTo("searchTop", anchor: .top) } },
                emptyMessage: nil
            )

            phraseDrilldown(proxy: proxy)
            initialPhraseMatches(proxy: proxy)

            if store.filteredResults.isEmpty && store.filteredSmartPhraseResults.isEmpty {
                ContentUnavailableView.search(text: store.lastSearchQuery)
            }
        }
    }

    var searchResultsHeader: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(resultSummaryText)
                .font(ResponsiveFont.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    CompactScriptFilterControl(selection: store.scriptFilter) { store.setScriptFilter($0) }
                    editSearchButton
                }
                VStack(alignment: .trailing, spacing: 8) {
                    CompactScriptFilterControl(selection: store.scriptFilter) { store.setScriptFilter($0) }
                    editSearchButton
                }
            }
        }
        .radixCard(
            padding: 12,
            background: RadixTheme.secondaryBackground.opacity(0.55)
        )
    }

    var resultSummaryText: String {
        let characterCount = store.filteredResults.count
        let phraseCount = store.filteredSmartPhraseResults.count
        if phraseCount > 0 {
            return "\(characterCount) characters • \(phraseCount) phrases"
        }
        return "\(characterCount) characters"
    }

    var editSearchButton: some View {
        Button {
            editCurrentSearch()
        } label: {
            Label("Edit Search", systemImage: "square.and.pencil")
                .font(ResponsiveFont.caption.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityLabel("Edit Search")
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
