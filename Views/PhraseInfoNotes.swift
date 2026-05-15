import SwiftUI

extension PhraseInfoCard {
    var phraseMeaningAndNotes: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Label("Meaning", systemImage: "text.book.closed")
                    .font(ResponsiveFont.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(phrase.meanings.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No meaning saved" : phrase.meanings)
                    .font(ResponsiveFont.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground).opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 8))

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
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                saveNotesButton
                cancelNotesButton
            }

            VStack(alignment: .leading, spacing: 8) {
                saveNotesButton
                cancelNotesButton
            }
        }
    }

    var saveNotesButton: some View {
        Button {
            saveNotes()
        } label: {
            Label("Save", systemImage: "checkmark")
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
    }

    var cancelNotesButton: some View {
        Button {
            editableNotes = phrase.notes
            editStatus = nil
            withAnimation(.easeInOut(duration: 0.2)) {
                isEditingNotes = false
            }
        } label: {
            Label("Cancel", systemImage: "xmark")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    @ViewBuilder
    var savedNotesText: some View {
        let noteSource = hasLocalNotes ? editableNotes : phrase.notes
        let trimmedNotes = noteSource.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNotes.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Label("Notes", systemImage: "note.text")
                    .font(ResponsiveFont.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(trimmedNotes)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground).opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 8))
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
