import SwiftUI

extension SmartSearchTab {
    var searchHeader: some View {
        VStack(alignment: .leading, spacing: store.hasPerformedSearch ? 10 : 12) {
            if !store.hasPerformedSearch {
                Text("Characters, pinyin, English meanings, or phrases.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField("水, shui, water, =water, or 含水", text: $localQuery)
                        .font(ResponsiveFont.body)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($isSearchFocused)
                        .submitLabel(.search)
                        .onSubmit {
                            runSearch(localQuery)
                        }

                    if !localQuery.isEmpty {
                        Button {
                            localQuery = ""
                            clearSearchResults()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(ResponsiveFont.body)
                                .foregroundStyle(.secondary)
                        }
                    }

                    recentSearchesMenu
                }
                .padding(12)
                .background(RadixTheme.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSearchFocused ? Color.accentColor : Color.clear, lineWidth: 2)
                )
                .shadow(color: isSearchFocused ? Color.accentColor.opacity(0.2) : Color.clear, radius: 4)

                if !store.hasPerformedSearch || hasEditedQuerySinceResults {
                    Button {
                        runSearch(localQuery)
                        isSearchFocused = false
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(ResponsiveFont.headline)
                            .frame(width: 48, height: 48)
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .accessibilityLabel("Search")
                }
            }
            .padding(.top, store.hasPerformedSearch ? 0 : 10)

            if !store.hasPerformedSearch || isSearchFocused {
                quickSearchTypeRow
            }
        }
        .padding(isRunningOnMac ? 24 : 16)
        .frame(maxWidth: isRunningOnMac ? 900 : .infinity, alignment: .leading)
        .background(RadixTheme.background)
    }

    var quickSearchTypeRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { quickSearchTypeContent }
            VStack(alignment: .leading, spacing: 8) { quickSearchTypeContent }
        }
        .padding(.top, 2)
    }

    private var quickSearchTypeContent: some View {
        Group {
            SearchTypePill(title: "Character", example: "水")
            SearchTypePill(title: "Pinyin", example: "shui")
            SearchTypePill(title: "Meaning", example: "water")
            SearchTypePill(title: "Exact", example: "=water")
            SearchTypePill(title: "Phrase", example: "含水")
        }
    }

    @ViewBuilder
    var recentSearchesMenu: some View {
        if !store.searchHistory.isEmpty {
            Menu {
                ForEach(Array(store.searchHistory.enumerated().reversed()), id: \.offset) { _, query in
                    Button(query) {
                        localQuery = query
                        runSearch(query)
                        isSearchFocused = false
                    }
                }

                Divider()

                Button(role: .destructive) {
                    store.clearSearchHistory()
                } label: {
                    Label("Clear History", systemImage: "trash")
                }
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(ResponsiveFont.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Recent Searches")
            .help("Recent Searches")
        }
    }
}

private struct SearchTypePill: View {
    let title: String
    let example: String

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(ResponsiveFont.caption2.weight(.semibold))
            Text(example)
                .font(ResponsiveFont.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(RadixTheme.secondaryBackground.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
