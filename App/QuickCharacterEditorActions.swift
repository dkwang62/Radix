import SwiftUI

extension QuickCharacterEditorView {
    var actionRow: some View {
        HStack(spacing: 10) {
            destructiveOrRevertAction

            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.bordered)

            Button("Save") {
                saveCharacter()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 4)
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    var destructiveOrRevertAction: some View {
        if store.addedDictionaryCharacters.contains(store.dataEditCharacter) {
            Button("Delete", role: .destructive) {
                deleteCurrentCharacter()
            }
            .buttonStyle(.bordered)
        } else if store.changedDictionaryCharacters.contains(store.dataEditCharacter) {
            Button("Revert") {
                store.restoreFromLibrary()
                dismiss()
            }
            .buttonStyle(.bordered)
            .tint(.blue)
        }
    }

    func deleteCurrentCharacter() {
        do {
            try store.deleteCurrentDataEditEntry()
            dismiss()
        } catch {
            editorError = error.localizedDescription
        }
    }

    func saveCharacter() {
        do {
            try store.saveCurrentDictionaryDraft()
            editorError = nil
            dismiss()
        } catch {
            editorError = error.localizedDescription
        }
    }
}
