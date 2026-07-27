import SwiftUI

extension DataBackupPreviewSection {
    var revertBasePhrasesRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Revert base phrase edits that have no notes.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Revert All", role: .destructive, action: revertAllUnnotedBasePhraseEdits)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }

            if let revertBasePhraseMessage {
                Text(revertBasePhraseMessage)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 8)
    }

    func revertAllUnnotedBasePhraseEdits() {
        do {
            let revertedWords = try store.removeAllUnnotedAddedPhrases()
            let phraseWord = revertedWords.count == 1 ? "phrase" : "phrases"
            revertBasePhraseMessage = revertedWords.isEmpty
                ? "No edited base phrases without notes to revert."
                : "Reverted \(revertedWords.count) edited base \(phraseWord) without notes."
        } catch {
            revertBasePhraseMessage = "Revert failed: \(error.localizedDescription)"
        }
    }

    func openBackupSavedPage(_ collection: CharacterCollection) {
        store.goToPagesWorkspace(id: collection.id, preservingOrigin: true)
    }

    func deleteBackupSavedPage(_ collection: CharacterCollection) {
        store.deleteCollection(id: collection.id)
    }

    var isPhone: Bool {
        RadixPlatform.isPhone
    }

    func presentPhrase(_ phrase: PhraseItem) {
        store.speakPhrase(phrase)
        if isPhone {
            store.presentPhraseInSidebar(phrase)
            selectedPhrase = phrase
        } else {
            selectedPhrase = nil
            store.presentPhraseInSidebar(phrase)
        }
    }

    var phonePhraseSheetBinding: Binding<PhraseItem?> {
        Binding(
            get: { isPhone ? selectedPhrase : nil },
            set: { newValue in
                if isPhone {
                    selectedPhrase = newValue
                }
            }
        )
    }
}
