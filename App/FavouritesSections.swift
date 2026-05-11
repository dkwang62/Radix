import SwiftUI

extension FavouritesTab {
    var favouritesScrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if isPhone, let current = store.previewCharacter {
                    VStack(alignment: .leading, spacing: 8) {
                        standardPhoneCharacterPreview(
                            character: current,
                            showAddToMemoryButton: false,
                            onClear: { store.previewCharacter = nil }
                        )
                    }
                }

                if !store.favoriteItems.isEmpty {
                    favoriteCharactersSection
                }

                if !store.favoritePhrasesItems.isEmpty {
                    favoritePhrasesSection
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    var favoriteCharactersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Characters (\(store.favoriteItems.count))")
                .font(ResponsiveFont.caption.bold())
                .foregroundStyle(.secondary)

            LazyVGrid(columns: favoriteCharacterColumns, spacing: 8) {
                ForEach(store.favoriteItems, id: \.character) { item in
                    favoriteCharacterCell(item)
                }
            }
        }
    }

    var favoritePhrasesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Phrases (\(store.favoritePhrasesItems.count))")
                .font(ResponsiveFont.caption.bold())
                .foregroundStyle(.secondary)

            LazyVGrid(columns: favoritePhraseColumns, spacing: 8) {
                ForEach(store.favoritePhrasesItems, id: \.word) { phrase in
                    Button {
                        presentPhrase(phrase)
                    } label: {
                        PhraseSummaryTile(phrase: phrase)
                    }
                    .buttonStyle(.plain)
                    .phraseContextMenu(phrase)
                }
            }
        }
    }
}
