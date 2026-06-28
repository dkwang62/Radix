import SwiftUI

enum ConversationPracticeInspectionRoute: Hashable {
    case phrase(PhraseItem)
    case character(String)
}

extension ConversationPracticeInspectionRoute {
    var character: String? {
        if case let .character(value) = self {
            return value
        }
        return nil
    }
}

struct ConversationPracticeInspectionDestination: View {
    @EnvironmentObject var store: RadixStore
    let route: ConversationPracticeInspectionRoute
    let sourceTitle: String
    let onOpenCharacter: (String) -> Void

    var body: some View {
        Group {
            switch route {
            case let .phrase(phrase):
                ScrollView {
                    PhraseInfoCard(
                        phrase: phrase,
                        onSelectCharacter: onOpenCharacter
                    )
                    .environmentObject(store)
                    .padding()
                }
                .background(RadixTheme.background)
                .navigationTitle(phrase.word)
            case let .character(character):
                ScrollView {
                    if let item = store.item(for: character) {
                        CharacterDetailView(item: item)
                            .environmentObject(store)
                    } else {
                        ContentUnavailableView(
                            character,
                            systemImage: "character.book.closed",
                            description: Text("This character is not available in the dictionary yet.")
                        )
                        .padding()
                    }
                }
                .background(RadixTheme.background)
                .navigationTitle(character)
                .onAppear {
                    store.previewCharacter = character
                    store.refreshPhrases()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityHint("Back returns to \(sourceTitle)")
    }
}
