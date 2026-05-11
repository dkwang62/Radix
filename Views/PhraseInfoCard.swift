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
    @State var showAddPhraseSheet = false

    var phraseCharacters: [String] {
        phrase.word.map(String.init).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
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
            .sheet(isPresented: $showAddPhraseSheet) {
                AddPhraseSheet()
                    .environmentObject(store)
            }
            .onChange(of: phrase.word) { _, _ in
                editableNotes = phrase.notes
                hasLocalNotes = false
                editStatus = nil
                isEditingNotes = false
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
            animationGrid
            phraseMeaningAndNotes
        }
    }
}
