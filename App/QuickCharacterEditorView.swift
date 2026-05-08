import SwiftUI

struct QuickCharacterEditorView: View {
    private enum FocusedCharacterField: Hashable {
        case etymology
        case hints
    }

    let initialCharacter: String
    let isNew: Bool
    @EnvironmentObject private var store: RadixStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var editorError: String?
    @State private var characterInput: String = ""
    @State private var isLoaded: Bool = false
    @State private var detailsExpanded: Bool = false
    @FocusState private var focusedField: FocusedCharacterField?

    init(character: String, isNew: Bool) {
        self.initialCharacter = character
        self.isNew = isNew
    }

    private var trimmedCharacterInput: String {
        characterInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canOpenCharacter: Bool {
        trimmedCharacterInput.count == 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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

    private var newCharacterPrompt: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Enter the Chinese character you want to add:")
                .font(ResponsiveFont.body)
                .foregroundStyle(.secondary)

            TextField("Single Chinese character", text: $characterInput)
                .font(.system(size: 36))
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
                .frame(width: 100)

            if let editorError {
                Text(editorError)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.red)
            }

            Button("Open") {
                let key = trimmedCharacterInput
                guard key.count == 1 else {
                    editorError = "Enter exactly one Chinese character."
                    return
                }
                do {
                    try store.createCustomDictionaryEntry(character: key)
                    editorError = nil
                    isLoaded = true
                } catch {
                    editorError = error.localizedDescription
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canOpenCharacter)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var editorForm: some View {
        if horizontalSizeClass == .compact && detailsExpanded {
            scrollableEditorForm
        } else {
            fixedEditorForm
        }
    }

    private var fixedEditorForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let editorError {
                Text(editorError)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            notesSection
                .frame(maxHeight: .infinity)

            dictionaryDetailsSection

            Divider()

            actionRow
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .font(ResponsiveFont.body)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var scrollableEditorForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        if let editorError {
                            Text(editorError)
                                .font(ResponsiveFont.caption)
                                .foregroundStyle(.red)
                                .padding(.horizontal)
                        }

                        notesSection
                            .frame(height: notesMinimumHeight)

                        dictionaryDetailsSection

                        Spacer(minLength: 120)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    .font(ResponsiveFont.body)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .onChange(of: focusedField) { _, field in
                    guard let field else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(field, anchor: .center)
                    }
                }
            }

            Divider()

            actionRow
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var dictionaryDetailsSection: some View {
        if horizontalSizeClass == .compact {
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    detailsExpanded.toggle()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: detailsExpanded ? "chevron.down" : "chevron.right")
                            .font(ResponsiveFont.caption.bold())
                            .frame(width: 16)
                        Text(detailsExpanded ? "Hide Dictionary Fields" : "Edit Dictionary Fields")
                            .font(ResponsiveFont.subheadline.weight(.semibold))
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if detailsExpanded {
                    dictionaryDetailsFields
                }
            }
        } else {
            dictionaryDetailsFields
        }
    }

    private var dictionaryDetailsFields: some View {
        VStack(alignment: .leading, spacing: 6) {
            formField("Definition / Meanings") {
                TextField("Definition / Meanings", text: $store.dataEditDefinition)
                    .textFieldStyle(.roundedBorder)
            }

            if horizontalSizeClass == .compact {
                compactFieldRow {
                    formField("Pinyin") {
                        TextField("e.g. fā, fà", text: $store.dataEditPinyin).textFieldStyle(.roundedBorder)
                    }
                    compactFormField("Radical", width: 82) {
                        TextField("Radical", text: $store.dataEditRadical).textFieldStyle(.roundedBorder)
                    }
                    compactFormField("Strokes", width: 76) {
                        TextField("Strokes", text: $store.dataEditStrokes).textFieldStyle(.roundedBorder)
                    }
                    formField("Decomposition") {
                        TextField("Decomposition", text: $store.dataEditDecomposition).textFieldStyle(.roundedBorder)
                    }
                }

                compactFieldRow {
                    compactFormField("Variant", width: 82) {
                        TextField("Variant", text: $store.dataEditVariant).textFieldStyle(.roundedBorder)
                    }
                    formField("Additional Variants") {
                        TextField("e.g. 髮, 臺", text: $store.dataEditAdditionalVariants).textFieldStyle(.roundedBorder)
                    }
                }

                formField("Related Characters") {
                    TextField("Comma-separated", text: $store.dataEditRelatedCharacters).textFieldStyle(.roundedBorder)
                }

                compactFieldRow {
                    formField("Etymology") {
                        TextField("Details", text: $store.dataEditEtymDetails).textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: .etymology)
                    }
                    .id(FocusedCharacterField.etymology)
                    formField("Hints") {
                        TextField("Hint", text: $store.dataEditEtymHint).textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: .hints)
                    }
                    .id(FocusedCharacterField.hints)
                }
            } else {
                HStack(spacing: 8) {
                    formField("Pinyin") {
                        TextField("e.g. fā, fà", text: $store.dataEditPinyin).textFieldStyle(.roundedBorder)
                    }
                    compactFormField("Radical", width: 90) {
                        TextField("Radical", text: $store.dataEditRadical).textFieldStyle(.roundedBorder)
                    }
                    compactFormField("Strokes", width: 82) {
                        TextField("Strokes", text: $store.dataEditStrokes).textFieldStyle(.roundedBorder)
                    }
                    formField("Decomposition") {
                        TextField("Decomposition", text: $store.dataEditDecomposition).textFieldStyle(.roundedBorder)
                    }
                }

                compactFieldRow {
                    compactFormField("Variant", width: 100) {
                        TextField("Variant", text: $store.dataEditVariant).textFieldStyle(.roundedBorder)
                    }
                    formField("Additional Variants") {
                        TextField("e.g. 髮, 臺", text: $store.dataEditAdditionalVariants).textFieldStyle(.roundedBorder)
                    }
                    formField("Related Characters") {
                        TextField("Comma-separated", text: $store.dataEditRelatedCharacters).textFieldStyle(.roundedBorder)
                    }
                }

                HStack(spacing: 8) {
                    formField("Etymology") {
                        TextField("Details", text: $store.dataEditEtymDetails).textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: .etymology)
                    }
                    formField("Hints") {
                        TextField("Hint", text: $store.dataEditEtymHint).textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: .hints)
                    }
                }
            }
        }
        .controlSize(.small)
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            if store.addedDictionaryCharacters.contains(store.dataEditCharacter) {
                Button("Delete", role: .destructive) {
                    do {
                        try store.deleteCurrentDataEditEntry()
                        dismiss()
                    } catch {
                        editorError = error.localizedDescription
                    }
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

    private func saveCharacter() {
        do {
            try store.saveCurrentDictionaryDraft()
            editorError = nil
            dismiss()
        } catch {
            editorError = error.localizedDescription
        }
    }

    @ViewBuilder
    private func formField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        QuickEditField(label: label, content: content)
    }

    private func compactFormField<Content: View>(_ label: String, width: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        QuickEditField(label: label, width: width, content: content)
    }

    private func compactFieldRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        QuickEditFieldRow(content: content)
    }

    @ViewBuilder
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Notes / Sentences / Phrases")
                    .font(ResponsiveFont.caption2)
                    .foregroundStyle(.secondary)
                if !store.dataEditNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Image(systemName: "text.badge.checkmark")
                        .font(ResponsiveFont.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            notesEditor()
        }
    }

    private func notesEditor() -> some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $store.dataEditNotes)
                .font(ResponsiveFont.body)
                .scrollContentBackground(.hidden)
                .padding(8)

            if store.dataEditNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Type sentences, examples, and phrases you want to practise.")
                    .font(ResponsiveFont.body)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 16)
                    .allowsHitTesting(false)
            }
        }
        .frame(minHeight: notesMinimumHeight, maxHeight: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.separator), lineWidth: 1)
        )
    }

    private var notesMinimumHeight: CGFloat {
        if horizontalSizeClass == .compact {
            return detailsExpanded ? 220 : 360
        }
        return 320
    }
}
