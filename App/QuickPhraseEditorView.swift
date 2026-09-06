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
    @State private var pendingManagementAction: QuickEditorManagementAction?
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
        !normalizedEditorWord.isEmpty && newPhraseDuplicateMessage == nil
    }

    private var normalizedEditorWord: String {
        store.normalizedPhraseWord(phraseEditorWord)
    }

    private var newPhraseDuplicateMessage: String? {
        guard isNew else { return nil }
        let word = normalizedEditorWord
        guard !word.isEmpty else { return nil }
        if store.isPhraseInAdd(word) {
            return "This phrase is already in your added phrases."
        }
        if store.isPhraseInBase(word) {
            return "This phrase is already in Radix."
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if let editorError {
                        Text(editorError)
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.red)
                    }
                    if let newPhraseDuplicateMessage {
                        Text(newPhraseDuplicateMessage)
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.secondary)
                    }

                    phraseFieldsSection

                    phraseNotesSection
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }

            phraseManagementFooter
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
                phraseEditorWord = store.simplifiedText(initialWord).trimmingCharacters(in: .whitespacesAndNewlines)
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
        .alert(
            pendingManagementAction?.title(for: "Phrase") ?? "Confirm Change",
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

    private var sheetTitle: String {
        if isNew { return "Add New Phrase" }
        return "Edit Phrase: \(initialWord)"
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(sheetTitle)
                .font(ResponsiveFont.title3.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.bordered)

            Button {
                savePhrase()
            } label: {
                Label("Save", systemImage: "checkmark")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSavePhrase)
        }
        .padding()
        .background(RadixTheme.background)
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
        .radixSurface(RadixTheme.secondaryBackground, border: RadixTheme.separator)
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
                    .radixSurface(
                        RadixTheme.secondaryBackground.opacity(0.6),
                        border: RadixTheme.separator,
                        borderWidth: 0.5
                    )
                    .focused($focusedPhraseField, equals: .meanings)
            }
        }
        .controlSize(.small)
    }

    @ViewBuilder
    private var phraseManagementFooter: some View {
        if hasPhraseManagementAction {
            Divider()

            HStack(spacing: 10) {
                let isBuiltIn = store.isPhraseInBase(phraseEditorWord)
                Button(isBuiltIn ? "Revert" : "Delete", role: .destructive) {
                    pendingManagementAction = isBuiltIn ? .revert : .delete
                }
                .buttonStyle(.bordered)
                Spacer()
            }
            .padding()
            .background(RadixTheme.background)
        }
    }

    private var hasPhraseManagementAction: Bool {
        !isNew && store.isPhraseInAdd(phraseEditorWord)
    }

    private func savePhrase() {
        do {
            let wordToSave = normalizedEditorWord
            if isNew {
                if store.isPhraseInAdd(wordToSave) {
                    editorError = "This phrase is already in your added phrases."
                    return
                }
                if store.isPhraseInBase(wordToSave) {
                    editorError = "This phrase is already in Radix."
                    return
                }
            }
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

    private var managementConfirmationBinding: Binding<Bool> {
        Binding(
            get: { pendingManagementAction != nil },
            set: { if !$0 { pendingManagementAction = nil } }
        )
    }

    private var managementConfirmationMessage: String {
        let word = store.normalizedPhraseWord(phraseEditorWord)
        switch pendingManagementAction {
        case .delete:
            return "Delete \(word)? This removes it from your added phrases and discards any unsaved changes in this editor."
        case .revert:
            return "Revert \(word) to Radix's built-in phrase? Saved custom pinyin, meanings, notes, and any unsaved changes in this editor are discarded."
        case nil:
            return "This action discards saved or unsaved changes."
        }
    }

    private func confirmManagementAction(_ action: QuickEditorManagementAction) {
        pendingManagementAction = nil
        do {
            try store.removeDataEditPhrase(word: phraseEditorWord)
            editorError = nil
            dismiss()
        } catch {
            editorError = "\(action.confirmationTitle) failed: \(error.localizedDescription)"
            RadixHaptics.error()
        }
    }

    private func phraseField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        QuickEditField(label: label, allowLabelScaling: false, content: content)
    }
}
