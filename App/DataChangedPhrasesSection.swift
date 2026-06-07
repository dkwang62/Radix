import SwiftUI

struct DataChangedPhrasesSection: View {
    @EnvironmentObject private var store: RadixStore

    let changedPhraseEntries: [PhraseItem]
    let addedPhraseEntries: [PhraseItem]
    let editedPhraseEntries: [PhraseItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Changed Phrases")
                .font(ResponsiveFont.subheadline.bold())

            Text("Added phrases are new. Edited phrases are built-in phrases you changed for your own copy.")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)

            if changedPhraseEntries.isEmpty {
                Text("No changed phrases yet.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            } else {
                if !addedPhraseEntries.isEmpty {
                    changedPhraseGroup(title: "Added", phrases: addedPhraseEntries)
                }
                if !editedPhraseEntries.isEmpty {
                    changedPhraseGroup(title: "Edited", phrases: editedPhraseEntries)
                }
            }
        }
    }

    private func changedPhraseGroup(title: String, phrases: [PhraseItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(title) (\(phrases.count))")
                .font(ResponsiveFont.caption.bold())
                .foregroundStyle(.secondary)

            ForEach(phrases) { phrase in
                editablePhraseCard(phrase)
            }
        }
    }

    private func editablePhraseCard(_ phrase: PhraseItem) -> some View {
        let isBuiltInPhrase = store.isPhraseInBase(phrase.word)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                PhraseSummaryTile(phrase: phrase)
                    .phraseContextMenu(phrase)
                Spacer()
                Button(store.phraseNotesActionTitle(for: phrase.word)) {
                    store.openQuickPhraseEditor(word: phrase.word)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)

                Button(role: isBuiltInPhrase ? nil : .destructive) {
                    store.removeDataEditPhrase(word: phrase.word)
                } label: {
                    Text(isBuiltInPhrase ? "Revert" : "Delete")
                        .font(ResponsiveFont.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }

            Text(phrase.meanings)
                .font(ResponsiveFont.body)
            if !phrase.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(phrase.notes)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(10)
        .background(RadixTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
