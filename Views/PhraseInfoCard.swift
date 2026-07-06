import SwiftUI

enum PhraseInfoFavoriteTarget {
    case phrase
    case sentence(ConversationPracticeItem)
}

struct PhraseInfoCard: View {
    @EnvironmentObject var store: RadixStore
    let phrase: PhraseItem
    var phraseLookupOverride: [PhraseItem]? = nil
    var favoriteTarget: PhraseInfoFavoriteTarget = .phrase
    var onSelectCharacter: ((String) -> Void)?
    var onDone: (() -> Void)?
    @State var animationScript = RadixPhrasePreferences.animationScript
    @State var isEditingNotes = false
    @State var editableNotes = ""
    @State var hasLocalNotes = false
    @State var editStatus: String?
    @State var showPhraseTableSheet = false
    @State var showSentenceExampleSheet = false
    @State var selectedAnimationPage = 0

    var phraseCharacters: [String] {
        phrase.word.map(String.init).filter { character in
            let trimmed = character.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return false }
            guard !trimmed.unicodeScalars.contains(where: { CharacterSet.punctuationCharacters.contains($0) }) else {
                return false
            }
            return store.item(for: trimmed) != nil
        }
    }

    var isPracticeSentence: Bool {
        if case .sentence = favoriteTarget {
            return true
        }
        return false
    }

    var body: some View {
        phraseContent
            .padding(16)
            .background(RadixTheme.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(RadixTheme.separator, lineWidth: 1)
            )
            .sheet(isPresented: $showPhraseTableSheet) {
                PhraseTableSheet(
                    character: phraseLookupOverride == nil ? (phraseCharacters.first ?? phrase.word) : phrase.word,
                    isVertical: true,
                    requiredCharacters: phraseCharacters.isEmpty ? phrase.word.map(String.init) : phraseCharacters,
                    fixedPhrases: phraseLookupOverride
                )
                .environmentObject(store)
            }
            .sheet(isPresented: $showSentenceExampleSheet) {
                SentenceExampleListSheet(
                    title: "Examples",
                    examples: SentenceExampleDisplayRules.examples(containingPhrase: phrase.word, limit: nil)
                )
                .environmentObject(store)
            }
            .onChange(of: phrase.word) { _, _ in
                editableNotes = phrase.notes
                hasLocalNotes = false
                editStatus = nil
                isEditingNotes = false
                showPhraseTableSheet = false
                showSentenceExampleSheet = false
                selectedAnimationPage = 0
            }
            .onAppear {
                animationScript = RadixPhrasePreferences.animationScript
                if !hasLocalNotes {
                    editableNotes = phrase.notes
                }
            }
            .onChange(of: animationScript) { _, newValue in
                RadixPhrasePreferences.animationScript = newValue
            }
    }

    @ViewBuilder
    var phraseContent: some View {
        if isPracticeSentence {
            VStack(alignment: .leading, spacing: 14) {
                practiceSentenceToolbar
                phraseAnimationPicker
                phraseMeaningAndNotes
            }
        } else {
            VStack(alignment: .leading, spacing: 14) {
                phraseHeader
                animationScriptToggle
                phraseAnimationPicker
                phraseMeaningAndNotes
            }
        }
    }
}
