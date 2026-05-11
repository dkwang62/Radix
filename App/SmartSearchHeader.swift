import SwiftUI

extension SmartSearchTab {
    var searchHeader: some View {
        VStack(alignment: .center, spacing: 15) {
            HStack(spacing: 12) {
                HStack {
                    searchHistoryMenu

                    TextField("See examples", text: $localQuery)
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
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSearchFocused ? Color.accentColor : Color.clear, lineWidth: 2)
                )
                .shadow(color: isSearchFocused ? Color.accentColor.opacity(0.2) : Color.clear, radius: 4)

                Button {
                    runSearch(localQuery)
                    isSearchFocused = false
                } label: {
                    Text("Search")
                        .font(ResponsiveFont.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.top, 10)
        }
        .padding(.vertical, isRunningOnMac ? 30 : 16)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    var searchHistoryMenu: some View {
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
            .accessibilityLabel("Search History")
        }
    }
}
