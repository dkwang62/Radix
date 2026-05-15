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

                    if store.showComponentHelp {
                        componentsExplorerHelp
                    }

                    lineageSection
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

    var componentsExplorerHelp: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Breakdown")
                .font(ResponsiveFont.subheadline.bold())
            Text("Tap a component to pivot. Counts show matching characters.")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
