import SwiftUI

extension QuickCharacterEditorView {
    var actionRow: some View {
        HStack(spacing: 10) {
            if hasCharacterManagementAction {
                destructiveOrRevertAction
                Spacer()
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

    var hasCharacterManagementAction: Bool {
        store.addedDictionaryCharacters.contains(store.dataEditCharacter)
            || store.changedDictionaryCharacters.contains(store.dataEditCharacter)
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
                RadixHaptics.light()
                dismiss()
            }
            .buttonStyle(.bordered)
            .tint(.blue)
        }
    }

    func deleteCurrentCharacter() {
        do {
            try store.deleteCurrentDataEditEntry()
            RadixHaptics.success()
            dismiss()
        } catch {
            editorError = error.localizedDescription
            RadixHaptics.error()
        }
    }

    func saveCharacter() {
        do {
            try store.saveCurrentDictionaryDraft()
            editorError = nil
            RadixHaptics.success()
            dismiss()
        } catch {
            editorError = error.localizedDescription
            RadixHaptics.error()
        }
    }
}
