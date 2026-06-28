import SwiftUI

struct CharacterDetailView: View {
    @EnvironmentObject var store: RadixStore
    @EnvironmentObject var entitlement: EntitlementManager
    @Environment(\.horizontalSizeClass) var sizeClass
    let item: ComponentItem
    @State var showPhraseTable = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if sizeClass == .compact {
                        header
                    } else {
                        regularHeader
                    }

                    if sizeClass != .compact {
                        regularActionRow(proxy: proxy)
                    }

                    if sizeClass != .compact && showPhraseTable {
                        CharacterPhraseLookupSection {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showPhraseTable = false
                            }
                        }
                        .id("phraseTableSection")
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("")
        .toolbar {
            Button {
                store.toggleFavorite(character: item.character)
            } label: {
                Image(systemName: store.isFavorite(item.character) ? "star.fill" : "star")
            }
        }
        .onChange(of: store.phraseLength) { _, _ in
            store.refreshPhrases()
        }
        .onChange(of: store.previewCharacter) { _, _ in
            store.refreshPhrases()
        }
        .onAppear { store.refreshPhrases() }
    }
}
