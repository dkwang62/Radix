import SwiftUI

enum ConversationPracticeInspectionRoute: Hashable {
    case phrase(PhraseItem)
    case character(String)
}

@MainActor
enum ConversationPracticeScriptSupport {
    static func filter(usesTraditionalScript: Bool) -> ScriptFilter {
        usesTraditionalScript ? .traditional : .simplified
    }

    static func displayText(_ text: String, usesTraditionalScript: Bool, store: RadixStore) -> String {
        usesTraditionalScript ? store.traditionalText(text) : store.simplifiedText(text)
    }

    static func displayCharacters(
        for item: ConversationPracticeItem,
        usesTraditionalScript: Bool,
        store: RadixStore
    ) -> [String] {
        var seen = Set<String>()
        return item.characterHints.compactMap { character in
            let converted = displayText(character, usesTraditionalScript: usesTraditionalScript, store: store)
            guard converted.count == 1,
                  converted.unicodeScalars.contains(where: { (0x4E00...0x9FFF).contains(Int($0.value)) }),
                  seen.insert(converted).inserted
            else { return nil }
            return converted
        }
    }

    static func displayCharacters(
        for item: ConversationPracticeItem,
        excludingPhrases phrases: [PhraseItem],
        usesTraditionalScript: Bool,
        store: RadixStore
    ) -> [String] {
        let coveredCharacters = Set(phrases.flatMap { phrase in
            displayText(phrase.word, usesTraditionalScript: usesTraditionalScript, store: store).map(String.init)
        })
        return displayCharacters(
            for: item,
            usesTraditionalScript: usesTraditionalScript,
            store: store
        )
        .filter { !coveredCharacters.contains($0) }
    }

    static func phraseItem(
        for item: ConversationPracticeItem,
        usesTraditionalScript: Bool,
        store: RadixStore
    ) -> PhraseItem {
        let base = store.mergedPhrase(for: item.phraseKey)
        return PhraseItem(
            word: displayText(item.simplified, usesTraditionalScript: usesTraditionalScript, store: store),
            pinyin: base?.pinyin ?? item.pinyin,
            meanings: base?.meanings ?? item.english,
            notes: base?.notes ?? item.notes
        )
    }

    static func displayPhrase(
        _ phrase: PhraseItem,
        usesTraditionalScript: Bool,
        store: RadixStore
    ) -> PhraseItem {
        PhraseItem(
            word: displayText(phrase.word, usesTraditionalScript: usesTraditionalScript, store: store),
            pinyin: phrase.pinyin,
            meanings: phrase.meanings,
            notes: phrase.notes
        )
    }
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
                        CharacterDetailView(item: item, phraseTargetCharacter: character)
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
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityHint("Back returns to \(sourceTitle)")
    }
}
