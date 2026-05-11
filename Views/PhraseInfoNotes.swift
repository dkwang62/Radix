import SwiftUI

extension PhraseInfoCard {
    var phraseMeaningAndNotes: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(phrase.meanings.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No meaning" : phrase.meanings)
                .font(ResponsiveFont.body)
                .fixedSize(horizontal: false, vertical: true)

            if isEditingNotes {
                noteEditor
                noteEditActions
            } else {
                savedNotesText
            }

            if let editStatus {
                Text(editStatus)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var noteEditor: some View {
        TextEditor(text: $editableNotes)
            .font(ResponsiveFont.body)
            .frame(minHeight: 96)
            .padding(6)
            .background(Color(.secondarySystemBackground).opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    var noteEditActions: some View {
        HStack(spacing: 8) {
            Button("Save Notes") {
                saveNotes()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button("Cancel") {
                editableNotes = phrase.notes
                editStatus = nil
                withAnimation(.easeInOut(duration: 0.2)) {
                    isEditingNotes = false
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    @ViewBuilder
    var savedNotesText: some View {
        let noteSource = hasLocalNotes ? editableNotes : phrase.notes
        let trimmedNotes = noteSource.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNotes.isEmpty {
            Text(trimmedNotes)
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    func saveNotes() {
        do {
            try store.addCustomPhrase(
                word: phrase.word,
                pinyin: phrase.pinyin,
                meanings: phrase.meanings,
                notes: editableNotes
            )
            hasLocalNotes = true
            editStatus = "Notes saved."
            withAnimation(.easeInOut(duration: 0.2)) {
                isEditingNotes = false
            }
        } catch {
            editStatus = "Save failed: \(error.localizedDescription)"
        }
    }
}
