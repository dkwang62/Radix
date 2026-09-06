import SwiftUI

struct QuickCharacterEditorView: View {
    enum FocusedCharacterField: Hashable {
        case notes
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
    @State var pendingManagementAction: QuickEditorManagementAction?
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
        .alert(
            pendingManagementAction?.title(for: "Character") ?? "Confirm Change",
            isPresented: managementConfirmationBinding
        ) {
            if let pendingManagementAction {
                Button(pendingManagementAction.confirmationTitle, role: .destructive) {
                    confirmManagementAction(pendingManagementAction)
                }
            }
            Button("Cancel", role: .cancel) {
                pendingManagementAction = nil
            }
        } message: {
            Text(managementConfirmationMessage)
        }
    }

    var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: isNew ? "character.book.closed" : "square.and.pencil")
                .font(ResponsiveFont.title3.weight(.semibold))
                .foregroundStyle(RadixAccent.primary)
                .radixIconButtonSurface(
                    size: 34,
                    background: RadixAccent.primary.opacity(0.12)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(isNew ? "Add Character" : "\(store.characterNotesActionTitle(for: initialCharacter)): \(initialCharacter)")
                    .font(ResponsiveFont.title3.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(isNew ? "Create a custom dictionary entry." : "Save personal notes and dictionary details.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            }
            .layoutPriority(1)

            Spacer()
            if isNew && !isLoaded {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .fixedSize(horizontal: true, vertical: false)
            } else {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .fixedSize(horizontal: true, vertical: false)

                Button {
                    saveCharacter()
                } label: {
                    Label("Save", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
                .fixedSize(horizontal: true, vertical: false)
            }
        }
        .padding()
        .background(RadixTheme.background)
    }
}
