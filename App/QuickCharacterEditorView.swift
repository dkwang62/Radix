import SwiftUI

struct QuickCharacterEditorView: View {
    enum FocusedCharacterField: Hashable {
        case etymology
        case hints
    }

    let initialCharacter: String
    let isNew: Bool
    @EnvironmentObject var store: RadixStore
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State var editorError: String?
    @State var characterInput: String = ""
    @State var isLoaded: Bool = false
    @State var detailsExpanded: Bool = false
    @FocusState var focusedField: FocusedCharacterField?

    init(character: String, isNew: Bool) {
        self.initialCharacter = character
        self.isNew = isNew
    }

    var trimmedCharacterInput: String {
        characterInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canOpenCharacter: Bool {
        trimmedCharacterInput.count == 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            if isNew && !isLoaded {
                newCharacterPrompt
            } else {
                editorForm
            }
        }
        .onAppear {
            if !isNew {
                store.loadDataEditEntry(for: initialCharacter)
                isLoaded = true
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Button("Done") {
                    focusedField = nil
                }
                Spacer()
                Button("Save") {
                    saveCharacter()
                }
            }
        }
    }

    var header: some View {
        HStack {
            Text(isNew ? "Add New Character" : "\(store.characterNotesActionTitle(for: initialCharacter)): \(initialCharacter)")
                .font(ResponsiveFont.title3.bold())
            Spacer()
            if isNew && !isLoaded {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}
