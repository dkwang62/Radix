import SwiftUI

struct QuickEditSheet: View {
    let destination: QuickEditDestination
    @EnvironmentObject private var store: RadixStore

    var body: some View {
        switch destination {
        case .character(let character):
            QuickCharacterEditorView(character: character, isNew: false)
        case .newCharacter:
            QuickCharacterEditorView(character: "", isNew: true)
        case .phrase(let word):
            QuickPhraseEditorView(word: word, isNew: false)
        case .newPhrase:
            QuickPhraseEditorView(word: "", isNew: true)
        }
    }
}

struct QuickCharacterEditorView: View {
    let initialCharacter: String
    let isNew: Bool
    @EnvironmentObject private var store: RadixStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var editorError: String?
    @State private var characterInput: String = ""
    @State private var isLoaded: Bool = false
    @State private var detailsExpanded: Bool = false

    init(character: String, isNew: Bool) {
        self.initialCharacter = character
        self.isNew = isNew
    }

    private var editingCharacter: String {
        isNew ? characterInput.trimmingCharacters(in: .whitespacesAndNewlines) : initialCharacter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header bar
            HStack {
                Text(isNew ? "Add New Character" : "\(store.characterNotesActionTitle(for: initialCharacter)): \(initialCharacter)")
                    .font(ResponsiveFont.title3.bold())
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(.systemBackground))

            Divider()

            if isNew && !isLoaded {
                // Step 1 for new characters: enter the character first
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
                        let key = characterInput.trimmingCharacters(in: .whitespacesAndNewlines)
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
                    .disabled(characterInput.trimmingCharacters(in: .whitespacesAndNewlines).count != 1)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
    }

    private var editorForm: some View {
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
                    }
                    formField("Hints") {
                        TextField("Hint", text: $store.dataEditEtymHint).textFieldStyle(.roundedBorder)
                    }
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
                    }
                    formField("Hints") {
                        TextField("Hint", text: $store.dataEditEtymHint).textFieldStyle(.roundedBorder)
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
                do {
                    try store.saveCurrentDictionaryDraft()
                    editorError = nil
                    dismiss()
                } catch {
                    editorError = error.localizedDescription
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 4)
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    private func formField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(ResponsiveFont.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            content()
        }
        .frame(maxWidth: .infinity)
    }

    private func compactFormField<Content: View>(_ label: String, width: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(ResponsiveFont.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            content()
        }
        .frame(width: width)
    }

    private func compactFieldRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 8) {
            content()
        }
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

struct QuickPhraseEditorView: View {
    let initialWord: String
    let isNew: Bool
    @EnvironmentObject private var store: RadixStore
    @Environment(\.dismiss) private var dismiss
    @State private var phraseEditorWord: String = ""
    @State private var phraseEditorPinyin: String = ""
    @State private var phraseEditorMeanings: String = ""
    @State private var phraseEditorIsExistingPhrase: Bool = false
    @State private var editorError: String?

    init(word: String, isNew: Bool) {
        self.initialWord = word
        self.isNew = isNew
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header bar
            HStack {
                Text(isNew ? "Add New Phrase" : "Edit Phrase")
                    .font(ResponsiveFont.title3.bold())
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(.systemBackground))

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                if let editorError {
                    Text(editorError)
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.red)
                }

                // Phrase word — editable for new, display-only for existing
                VStack(alignment: .leading, spacing: 4) {
                    Text("Phrase")
                        .font(ResponsiveFont.caption2)
                        .foregroundStyle(.secondary)
                    if isNew {
                        TextField("Chinese phrase", text: $phraseEditorWord)
                            .font(ResponsiveFont.title3.bold())
                            .textFieldStyle(.roundedBorder)
                    } else {
                        Text(phraseEditorWord)
                            .font(ResponsiveFont.title3.bold())
                            .phraseContextMenu(PhraseItem(word: phraseEditorWord, pinyin: phraseEditorPinyin, meanings: phraseEditorMeanings))
                        Text(phraseEditorIsExistingPhrase ? "Editing existing phrase" : "New phrase")
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Pinyin")
                        .font(ResponsiveFont.caption2)
                        .foregroundStyle(.secondary)
                    TextField("Pinyin", text: $phraseEditorPinyin)
                        .font(ResponsiveFont.body.monospaced())
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("English Meaning")
                        .font(ResponsiveFont.caption2)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $phraseEditorMeanings)
                        .font(ResponsiveFont.body)
                        .frame(minHeight: 160)
                        .padding(8)
                        .background(Color(.secondarySystemBackground).opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.separator), lineWidth: 0.5)
                        )
                }

                Spacer(minLength: 0)

                Divider()

                HStack(spacing: 10) {
                    if !isNew {
                        if phraseEditorIsExistingPhrase {
                            Button("Revert") {
                                store.removeDataEditPhrase(word: phraseEditorWord)
                                dismiss()
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Button("Delete", role: .destructive) {
                                store.removeDataEditPhrase(word: phraseEditorWord)
                                dismiss()
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    Spacer()

                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)

                    Button("Save") {
                        do {
                            let wordToSave = isNew
                                ? store.simplifiedText(phraseEditorWord.trimmingCharacters(in: .whitespacesAndNewlines))
                                : phraseEditorWord
                            try store.addCustomPhrase(
                                word: wordToSave,
                                pinyin: phraseEditorPinyin,
                                meanings: phraseEditorMeanings
                            )
                            editorError = nil
                            dismiss()
                        } catch {
                            editorError = error.localizedDescription
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(phraseEditorWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.top, 4)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onAppear {
            if isNew {
                phraseEditorWord = ""
                phraseEditorPinyin = ""
                phraseEditorMeanings = ""
                phraseEditorIsExistingPhrase = false
            } else {
                let simplifiedWord = store.simplifiedText(initialWord)
                if let phrase = store.mergedPhrase(for: simplifiedWord) {
                    phraseEditorWord = phrase.word
                    phraseEditorPinyin = phrase.pinyin
                    phraseEditorMeanings = phrase.meanings
                    phraseEditorIsExistingPhrase = true
                } else {
                    phraseEditorWord = simplifiedWord
                    phraseEditorPinyin = ""
                    phraseEditorMeanings = ""
                    phraseEditorIsExistingPhrase = false
                }
            }
        }
    }
}
