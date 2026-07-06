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
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(backupCharacterRows(for: displayed).enumerated()), id: \.offset) { _, rowCharacters in
                        HStack(spacing: 8) {
                            ForEach(rowCharacters, id: \.self) { character in
                                let item = store.item(for: character)
                                BackupCharacterTile(character: character, pinyin: item?.pinyinText ?? "") {
                                    onPreviewCharacter(character)
                                }
                            }

                            ForEach(0..<backupCharacterPlaceholderCount(for: rowCharacters), id: \.self) { _ in
                                Color.clear
                                    .frame(maxWidth: .infinity, minHeight: 58)
                            }
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
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(backupPhraseRows(for: sortedPhrases).enumerated()), id: \.offset) { _, rowPhrases in
                    HStack(spacing: 8) {
                        ForEach(rowPhrases) { phrase in
                            BackupPhraseRow(phrase: phrase) {
                                presentPhrase(phrase)
                            }
                        }

                        ForEach(0..<backupPhrasePlaceholderCount(for: rowPhrases), id: \.self) { _ in
                            Color.clear
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    var backupPhraseColumnCount: Int {
        isPhone ? 2 : 3
    }

    var backupCharacterColumnCount: Int {
        isPhone ? 4 : 6
    }

    func backupPhraseRows(for phrases: [PhraseItem]) -> [[PhraseItem]] {
        stride(from: 0, to: phrases.count, by: backupPhraseColumnCount).map { start in
            let end = min(start + backupPhraseColumnCount, phrases.count)
            return Array(phrases[start..<end])
        }
    }

    func backupCharacterRows(for characters: [String]) -> [[String]] {
        stride(from: 0, to: characters.count, by: backupCharacterColumnCount).map { start in
            let end = min(start + backupCharacterColumnCount, characters.count)
            return Array(characters[start..<end])
        }
    }

    func backupPhrasePlaceholderCount(for row: [PhraseItem]) -> Int {
        max(0, backupPhraseColumnCount - row.count)
    }

    func backupCharacterPlaceholderCount(for row: [String]) -> Int {
        max(0, backupCharacterColumnCount - row.count)
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
