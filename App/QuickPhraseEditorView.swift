import SwiftUI

struct QuickPhraseEditorView: View {
    let initialWord: String
    let isNew: Bool
    @EnvironmentObject private var store: RadixStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var phraseEditorWord: String = ""
    @State private var phraseEditorPinyin: String = ""
    @State private var phraseEditorMeanings: String = ""
    @State private var phraseEditorNotes: String = ""
    @State private var editorError: String?
    @FocusState private var focusedPhraseField: PhraseField?

    private enum PhraseField: Hashable {
        case notes
        case pinyin
        case meanings
    }

    init(word: String, isNew: Bool) {
        self.initialWord = word
        self.isNew = isNew
    }

    private var canSavePhrase: Bool {
        !phraseEditorWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(sheetTitle)
                    .font(ResponsiveFont.title3.bold())
                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if let editorError {
                        Text(editorError)
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.red)
                    }

                    phraseNotesSection

                    phraseFieldsSection
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }

            Divider()

            phraseActionRow
                .padding()
                .background(Color(.systemBackground))
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Button("Done") {
                    focusedPhraseField = nil
                }
                Spacer()
                Button("Save") {
                    savePhrase()
                }
                .disabled(!canSavePhrase)
            }
        }
        .onAppear {
            if isNew {
                phraseEditorWord = ""
                phraseEditorPinyin = ""
                phraseEditorMeanings = ""
                phraseEditorNotes = ""
            } else {
                let simplifiedWord = store.simplifiedText(initialWord)
                if let phrase = store.addedPhraseForReview(word: simplifiedWord) ?? store.mergedPhrase(for: simplifiedWord) {
                    phraseEditorWord = phrase.word
                    phraseEditorPinyin = phrase.pinyin
                    phraseEditorMeanings = phrase.meanings
                    phraseEditorNotes = phrase.notes
                } else {
                    phraseEditorWord = simplifiedWord
                    phraseEditorPinyin = ""
                    phraseEditorMeanings = ""
                    phraseEditorNotes = ""
                }
            }
        }
    }

    private var sheetTitle: String {
        if isNew { return "Add New Phrase" }
        return "\(store.phraseNotesActionTitle(for: initialWord)): \(initialWord)"
    }

    @ViewBuilder
    private var phraseNotesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Notes / Sentences / Examples")
                    .font(ResponsiveFont.caption2)
                    .foregroundStyle(.secondary)
                if !phraseEditorNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Image(systemName: "text.badge.checkmark")
                        .font(ResponsiveFont.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            notesEditor
        }
    }

    private var notesEditor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $phraseEditorNotes)
                .font(ResponsiveFont.body)
                .scrollContentBackground(.hidden)
                .padding(8)
                .focused($focusedPhraseField, equals: .notes)

            if phraseEditorNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Type your own example sentences, phrases, usage notes, and reminders for this phrase.")
                    .font(ResponsiveFont.body)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 16)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: phraseNotesHeight)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.separator), lineWidth: 1)
        )
    }

    private var phraseNotesHeight: CGFloat {
        if horizontalSizeClass == .compact {
            return 240
        }
        return 360
    }

    private var phraseMeaningHeight: CGFloat {
        horizontalSizeClass == .compact ? 96 : 120
    }

    @ViewBuilder
    private var phraseFieldsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Phrase Fields")
                .font(ResponsiveFont.caption.bold())
                .foregroundStyle(.secondary)
            phraseFields
        }
    }

    private var phraseFields: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                phraseField("Phrase") {
                    if isNew {
                        TextField("Chinese phrase", text: $phraseEditorWord)
                            .font(ResponsiveFont.body.bold())
                            .textFieldStyle(.roundedBorder)
                    } else {
                        Text(phraseEditorWord)
                            .font(ResponsiveFont.body.bold())
                            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                            .phraseContextMenu(PhraseItem(word: phraseEditorWord, pinyin: phraseEditorPinyin, meanings: phraseEditorMeanings, notes: phraseEditorNotes))
                    }
                }
                phraseField("Pinyin") {
                    TextField("Pinyin", text: $phraseEditorPinyin)
                        .font(ResponsiveFont.body.monospaced())
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedPhraseField, equals: .pinyin)
                }
            }

            phraseField("English Meaning") {
                TextEditor(text: $phraseEditorMeanings)
                    .font(ResponsiveFont.body)
                    .frame(height: phraseMeaningHeight)
                    .padding(8)
                    .background(Color(.secondarySystemBackground).opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.separator), lineWidth: 0.5)
                    )
                    .focused($focusedPhraseField, equals: .meanings)
            }
        }
        .controlSize(.small)
    }

    private var phraseActionRow: some View {
        HStack(spacing: 10) {
            if !isNew && store.isPhraseInAdd(phraseEditorWord) {
                let isBuiltIn = store.isPhraseInBase(phraseEditorWord)
                Button(isBuiltIn ? "Revert" : "Delete", role: isBuiltIn ? nil : .destructive) {
                    deletePhrase()
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.bordered)

            Button("Save") {
                savePhrase()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSavePhrase)
        }
    }

    private func savePhrase() {
        do {
            let wordToSave = store.normalizedPhraseWord(phraseEditorWord)
            try store.addCustomPhrase(
                word: wordToSave,
                pinyin: phraseEditorPinyin,
                meanings: phraseEditorMeanings,
                notes: phraseEditorNotes
            )
            editorError = nil
            dismiss()
        } catch {
            editorError = error.localizedDescription
        }
    }

    private func deletePhrase() {
        store.removeDataEditPhrase(word: phraseEditorWord)
        dismiss()
    }

    private func phraseField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        QuickEditField(label: label, allowLabelScaling: false, content: content)
    }
}
