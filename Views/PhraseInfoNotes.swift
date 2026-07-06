import SwiftUI

extension PhraseInfoCard {
    var phraseMeaningAndNotes: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text(phrase.meanings.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No meaning saved" : phrase.meanings)
                    .font(ResponsiveFont.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .radixSurface(RadixTheme.secondaryBackground.opacity(0.45))

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
            .radixSurface(RadixTheme.secondaryBackground.opacity(0.6))
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
                RadixTermLabel(term: RadixTerm.notes)
                    .font(ResponsiveFont.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(trimmedNotes)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .radixSurface(RadixTheme.secondaryBackground.opacity(0.35))
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

enum SentenceExampleDisplayRules {
    static func examples(containingPhrase phrase: String, limit: Int? = 3) -> [SentenceExampleRecord] {
        RadixStudyPreferences.sentenceExamples(containingPhrase: phrase, limit: limit)
    }

    static func examples(containingCharacter character: String, limit: Int? = 3) -> [SentenceExampleRecord] {
        RadixStudyPreferences.sentenceExamples(containingCharacter: character, limit: limit)
    }
}
