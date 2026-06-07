import SwiftUI

extension QuickCharacterEditorView {
    var actionRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                destructiveOrRevertAction

                Spacer()

                cancelButton
                saveButton
            }

            VStack(spacing: 10) {
                saveButton
                cancelButton
                destructiveOrRevertAction
            }
        }
        .padding(.vertical, 4)
        .background(RadixTheme.background)
    }

    var cancelButton: some View {
        Button("Cancel") {
            dismiss()
        }
        .buttonStyle(.bordered)
    }

    var saveButton: some View {
        Button {
            saveCharacter()
        } label: {
            Label("Save", systemImage: "checkmark")
        }
        .buttonStyle(.borderedProminent)
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
