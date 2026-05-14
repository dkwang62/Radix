import SwiftUI

struct PhraseInfoCard: View {
    @EnvironmentObject var store: RadixStore
    let phrase: PhraseItem
    var onSelectCharacter: ((String) -> Void)?
    var onDone: (() -> Void)?
    @AppStorage("phraseInfoAnimationScript") var animationScript = "simplified"
    @State var isEditingNotes = false
    @State var editableNotes = ""
    @State var hasLocalNotes = false
    @State var editStatus: String?
    @State var showPhraseTableSheet = false
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

    var body: some View {
        phraseContent
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(.separator), lineWidth: 1)
            )
            .sheet(isPresented: $showPhraseTableSheet) {
                PhraseTableSheet(
                    character: phraseCharacters.first ?? phrase.word,
                    isVertical: true,
                    requiredCharacters: phraseCharacters.isEmpty ? phrase.word.map(String.init) : phraseCharacters
                )
                .environmentObject(store)
            }
            .onChange(of: phrase.word) { _, _ in
                editableNotes = phrase.notes
                hasLocalNotes = false
                editStatus = nil
                isEditingNotes = false
                showPhraseTableSheet = false
                selectedAnimationPage = 0
            }
            .onAppear {
                if !hasLocalNotes {
                    editableNotes = phrase.notes
                }
            }
    }

    var phraseContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            phraseHeader
            phrasePinyinRow
            animationScriptToggle
            phraseAnimationPicker
            phraseMeaningAndNotes
        }
    }
}
