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
            .background(RadixTheme.secondaryBackground.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            if isEditingNotes {
                noteEditor
                noteEditActions
            } else {
                savedNotesText
            }

            phraseSentenceExamples

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
            .background(RadixTheme.secondaryBackground.opacity(0.6))
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

    @ViewBuilder
    var phraseSentenceExamples: some View {
        let examples = SentenceExampleDisplayRules.examples(containingPhrase: phrase.word)
        if !examples.isEmpty {
            SentenceExamplePreviewSection(title: "Examples", examples: examples)
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
            .background(RadixTheme.secondaryBackground.opacity(0.35))
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

enum SentenceExampleDisplayRules {
    static func examples(containingPhrase phrase: String, limit: Int = 3) -> [SentenceExampleRecord] {
        let key = SentenceExampleRecord.normalizedChineseKey(phrase)
        guard !key.isEmpty else { return [] }
        return rankedExamples().filter { record in
            record.detectedPhrases.contains { SentenceExampleRecord.normalizedChineseKey($0) == key } ||
            record.targetPhrases.contains { SentenceExampleRecord.normalizedChineseKey($0) == key } ||
            record.normalizedChineseKey.contains(key)
        }
        .prefix(limit)
        .map { $0 }
    }

    static func examples(containingCharacter character: String, limit: Int = 3) -> [SentenceExampleRecord] {
        let key = character.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return [] }
        return rankedExamples().filter { record in
            record.detectedCharacters.contains(key) ||
            record.targetCharacters.contains(key) ||
            record.chinese.contains(key)
        }
        .prefix(limit)
        .map { $0 }
    }

    private static func rankedExamples() -> [SentenceExampleRecord] {
        RadixStudyPreferences.sentenceExamples
            .filter { !$0.isHidden }
            .sorted {
                if $0.isFavorited != $1.isFavorited { return $0.isFavorited && !$1.isFavorited }
                if $0.qualityScore != $1.qualityScore { return $0.qualityScore > $1.qualityScore }
                if $0.practicedCount != $1.practicedCount { return $0.practicedCount > $1.practicedCount }
                if $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
                return $0.chinese < $1.chinese
            }
    }
}

struct SentenceExamplePreviewSection: View {
    let title: String
    let examples: [SentenceExampleRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: RadixGlossaryIcon.systemImage(for: "Sentence"))
                .font(ResponsiveFont.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(examples) { example in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(example.chinese)
                            .font(ResponsiveFont.caption.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)

                        if let pinyin = example.pinyin {
                            Text(pinyin)
                                .font(ResponsiveFont.caption2)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if let english = example.english {
                            Text(english)
                                .font(ResponsiveFont.caption2)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RadixTheme.secondaryBackground.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
