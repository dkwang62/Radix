import SwiftUI

struct AddPhraseInputForm: View {
    @EnvironmentObject private var store: RadixStore
    let onAdd: (PhraseDiscoveryCandidate, String?) -> Void
    let onCancel: () -> Void

    @State private var word = ""
    @State private var pinyin = ""
    @State private var meanings = ""
    @State private var notes = ""
    @State private var editorError: String?

    @FocusState private var focused: InputField?
    private enum InputField: Hashable { case word, pinyin, meanings, notes }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let editorError {
                    Label(editorError, systemImage: "exclamationmark.triangle")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.red)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .radixSurface(Color.red.opacity(0.08))
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label("Phrase Details", systemImage: "text.quote")
                        .font(ResponsiveFont.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    fieldBlock("Phrase") {
                        TextField("Chinese phrase", text: $word)
                            .font(ResponsiveFont.body.bold())
                            .textFieldStyle(.roundedBorder)
                            .focused($focused, equals: .word)
                    }

                    fieldBlock("Pinyin") {
                        TextField("Pinyin", text: $pinyin)
                            .font(ResponsiveFont.body.monospaced())
                            .textFieldStyle(.roundedBorder)
                            .focused($focused, equals: .pinyin)
                    }

                    fieldBlock("English Meaning") {
                        TextEditor(text: $meanings)
                            .font(ResponsiveFont.body)
                            .frame(height: 80)
                            .padding(8)
                            .radixSurface(
                                RadixTheme.secondaryBackground.opacity(0.6),
                                border: RadixTheme.separator,
                                borderWidth: 0.5
                            )
                            .focused($focused, equals: .meanings)
                    }
                }
                .padding(12)
                .radixSurface(RadixTheme.secondaryBackground.opacity(0.45))

                VStack(alignment: .leading, spacing: 12) {
                    RadixTermLabel("Study Notes", term: RadixTerm.notes)
                        .font(ResponsiveFont.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    fieldBlock("Notes / Sentences / Examples") {
                        notesEditor
                    }
                }
                .padding(12)
                .radixSurface(RadixTheme.secondaryBackground.opacity(0.35))
            }
            .padding()
        }

        Divider()

        actionRow
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Button("Done") { focused = nil }
                    Spacer()
                    Button("Add Phrase") { addPhrase() }
                        .disabled(word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
    }

    private var notesEditor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $notes)
                .font(ResponsiveFont.body)
                .scrollContentBackground(.hidden)
                .padding(8)
                .focused($focused, equals: .notes)
            if notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Example sentences, usage notes, reminders...")
                    .font(ResponsiveFont.body)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 16)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: 140)
        .radixSurface(RadixTheme.secondaryBackground, border: RadixTheme.separator)
    }

    private var actionRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                Spacer()
                cancelButton
                addButton
            }

            VStack(spacing: 10) {
                addButton
                cancelButton
            }
        }
        .padding()
        .background(RadixTheme.background)
    }

    private var cancelButton: some View {
        Button("Cancel", action: onCancel)
            .buttonStyle(.bordered)
    }

    private var addButton: some View {
        Button {
            addPhrase()
        } label: {
            Label("Add Phrase", systemImage: "plus")
        }
        .buttonStyle(.borderedProminent)
        .disabled(word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private func fieldBlock<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(ResponsiveFont.caption.bold())
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func addPhrase() {
        do {
            let trimmed = store.normalizedPhraseWord(word)
            try store.addCustomPhrase(word: trimmed, pinyin: pinyin, meanings: meanings, notes: notes)
            editorError = nil
            RadixHaptics.success()
            onAdd(
                PhraseDiscoveryCandidate(
                    phrase: trimmed,
                    pinyin: pinyin,
                    meaning: meanings,
                    isSelected: true
                ),
                "Added \(trimmed)."
            )
            word = ""
            pinyin = ""
            meanings = ""
            notes = ""
        } catch {
            editorError = error.localizedDescription
            RadixHaptics.error()
        }
    }
}
