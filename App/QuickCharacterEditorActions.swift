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
                pendingManagementAction = .delete
            }
            .buttonStyle(.bordered)
        } else if store.changedDictionaryCharacters.contains(store.dataEditCharacter) {
            Button("Revert", role: .destructive) {
                pendingManagementAction = .revert
            }
            .buttonStyle(.bordered)
        }
    }

    var managementConfirmationBinding: Binding<Bool> {
        Binding(
            get: { pendingManagementAction != nil },
            set: { if !$0 { pendingManagementAction = nil } }
        )
    }

    var managementConfirmationMessage: String {
        let character = store.dataEditCharacter.trimmingCharacters(in: .whitespacesAndNewlines)
        switch pendingManagementAction {
        case .delete:
            return "Delete \(character)? This removes the custom character and discards any unsaved changes in this editor."
        case .revert:
            return "Revert \(character) to Radix's built-in dictionary values? Saved notes are kept. Other saved custom fields and any unsaved changes in this editor are discarded."
        case nil:
            return "This action discards saved or unsaved changes."
        }
    }

    func confirmManagementAction(_ action: QuickEditorManagementAction) {
        pendingManagementAction = nil
        switch action {
        case .delete:
            deleteCurrentCharacter()
        case .revert:
            store.restoreFromLibrary()
            RadixHaptics.light()
            dismiss()
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
