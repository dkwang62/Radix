import SwiftUI

extension DataBackupPreviewSection {
    @ViewBuilder
    func backupCharacterRows(_ characters: [String]) -> some View {
        let sortedCharacters = sortedBackupCharacters(characters)
        let displayed = Array(sortedCharacters.prefix(80))
        let truncated = sortedCharacters.count > displayed.count

        VStack(alignment: .leading, spacing: 8) {
            if characters.isEmpty {
                Text("No matching characters.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: backupCharacterColumns, alignment: .leading, spacing: 8) {
                    ForEach(displayed, id: \.self) { character in
                        let item = store.item(for: character)
                        BackupCharacterTile(character: character, pinyin: item?.pinyinText ?? "") {
                            onPreviewCharacter(character)
                        }
                    }
                }

                if truncated {
                    Text("Showing the first \(displayed.count) of \(sortedCharacters.count) characters.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    func backupPhraseRows(_ phrases: [PhraseItem]) -> some View {
        let sortedPhrases = sortedBackupPhrases(phrases)

        if phrases.isEmpty {
            Text("No matching phrases.")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        } else {
            LazyVGrid(columns: backupPhraseColumns, alignment: .leading, spacing: 8) {
                ForEach(sortedPhrases) { phrase in
                    BackupPhraseRow(phrase: phrase) {
                        presentPhrase(phrase)
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    @ViewBuilder
    func addedPhraseReviewRows(_ phrases: [PhraseItem]) -> some View {
        let reviewPhrases = phrases.filter { $0.reviewStatus != .completed }
        let sortedPhrases = sortedBackupPhrases(reviewPhrases)

        if reviewPhrases.isEmpty {
            Text("No phrases waiting for review. Completed phrases are available in Classify & Prune.")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        } else {
            LazyVGrid(columns: backupPhraseColumns, alignment: .leading, spacing: 8) {
                ForEach(sortedPhrases) { phrase in
                    BackupPhraseRow(phrase: phrase, onSelect: {
                        previewOrCycleAddedPhrase(phrase)
                    }, showsReviewStatus: true)
                }
            }
            .padding(.top, 8)
        }
    }

    var backupSavedPagesRows: some View {
        SavedImageRows(
            collections: store.allCollections,
            emptyDescription: "Scan or import an image.",
            onOpen: openBackupSavedPage,
            onDelete: deleteBackupSavedPage
        )
        .padding(.top, 8)
    }

    var backupPhraseColumns: [GridItem] {
        [GridItem(.adaptive(minimum: isPhone ? 120 : 140), spacing: 8)]
    }

    var backupCharacterColumns: [GridItem] {
        [GridItem(.adaptive(minimum: isPhone ? 72 : 82), spacing: 8)]
    }

    func sortedBackupCharacters(_ characters: [String]) -> [String] {
        characters.sorted { lhs, rhs in
            let leftItem = store.item(for: lhs)
            let rightItem = store.item(for: rhs)
            let leftKey = BackupPreviewSort.key(primary: leftItem?.pinyinText ?? "", fallback: lhs)
            let rightKey = BackupPreviewSort.key(primary: rightItem?.pinyinText ?? "", fallback: rhs)
            return leftKey.localizedStandardCompare(rightKey) == .orderedAscending
        }
    }

    func sortedBackupPhrases(_ phrases: [PhraseItem]) -> [PhraseItem] {
        phrases.sorted { lhs, rhs in
            if lhs.word.count != rhs.word.count {
                return lhs.word.count < rhs.word.count
            }
            let leftKey = BackupPreviewSort.key(primary: lhs.pinyin, fallback: lhs.word)
            let rightKey = BackupPreviewSort.key(primary: rhs.pinyin, fallback: rhs.word)
            return leftKey.localizedStandardCompare(rightKey) == .orderedAscending
        }
    }

    func previewOrCycleAddedPhrase(_ phrase: PhraseItem) {
        let word = store.normalizedPhraseWord(phrase.word)
        let action = addedPhraseReviewCycle.action(
            for: word,
            currentStatus: currentAddedPhraseReviewStatus(for: phrase)
        )
        defer {
            presentPhrase(phrase)
        }

        guard case let .apply(status) = action else { return }
        setAddedPhraseReviewStatus(status, for: phrase)
    }

    func setAddedPhraseReviewStatus(_ status: PhraseReviewStatus?, for phrase: PhraseItem) {
        do {
            try store.updateAddedPhraseReviewStatus(word: phrase.word, status: status)
        } catch {
            revertBasePhraseMessage = "Could not update \(phrase.word): \(error.localizedDescription)"
        }
    }

    func currentAddedPhraseReviewStatus(for phrase: PhraseItem) -> PhraseReviewStatus? {
        let word = store.normalizedPhraseWord(phrase.word)
        return store.addedPhrases.first { store.normalizedPhraseWord($0.word) == word }?.reviewStatus ?? phrase.reviewStatus
    }

}
