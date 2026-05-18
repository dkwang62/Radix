import SwiftUI

extension FavouritesTab {
    var hasStudyGridItems: Bool {
        !studyReviewTiles.isEmpty
    }

    var studyReviewTiles: [StudyReviewTile] {
        (studyPhraseRows.map(StudyReviewTile.phraseTile)
            + studyCharacterGridEntries.map(StudyReviewTile.characterTile))
            .sorted { lhs, rhs in
                let leftPinyin = studySortPinyin(lhs.pinyin)
                let rightPinyin = studySortPinyin(rhs.pinyin)
                if leftPinyin != rightPinyin { return leftPinyin < rightPinyin }

                return lhs.sortText < rhs.sortText
            }
    }

    var studyPhraseRows: [StudyPhraseRowData] {
        studyVisiblePhraseMarkers.map { phrase, marker in
            StudyPhraseRowData(phrase: phrase, marker: marker)
        }
    }

    var studyVisiblePhraseMarkers: [(phrase: PhraseItem, marker: StudyPhraseMarker)] {
        var keyedPhrases: [String: (phrase: PhraseItem, marker: StudyPhraseMarker)] = [:]

        for phrase in store.favoritePhrasesItems {
            keyedPhrases[phrase.word] = (phrase, .favorite)
        }

        if studyGridScope == .all {
            for phrase in recentStudyPhrases where keyedPhrases[phrase.word] == nil {
                keyedPhrases[phrase.word] = (phrase, .recent)
            }
        }

        return keyedPhrases.values.sorted { lhs, rhs in
            let leftPinyin = studySortPinyin(lhs.phrase.pinyin)
            let rightPinyin = studySortPinyin(rhs.phrase.pinyin)
            if leftPinyin != rightPinyin { return leftPinyin < rightPinyin }

            return lhs.phrase.word < rhs.phrase.word
        }
    }

    var studyCharacterGridEntries: [StudyGridEntry] {
        let visiblePhraseCharacters = Set(studyVisiblePhrases.flatMap { phrase in
            phrase.word.map { String($0) }
        })

        let favoriteCharacterEntries = store.favoriteItems
            .filter { !visiblePhraseCharacters.contains($0.character) }
            .map { item in
                StudyGridEntry(
                    id: "character:\(item.character)",
                    character: item.character,
                    pinyin: item.pinyinText,
                    isFavoriteCharacter: true
                )
            }

        let recentCharacterEntries = store.recentOnlyCharacterItems
            .filter { !visiblePhraseCharacters.contains($0.character) }
            .filter { _ in studyGridScope == .all }
            .map { item in
                StudyGridEntry(
                    id: "recent:\(item.character)",
                    character: item.character,
                    pinyin: item.pinyinText,
                    isFavoriteCharacter: false
                )
            }

        return favoriteCharacterEntries + recentCharacterEntries
    }

    var studyVisiblePhrases: [PhraseItem] {
        studyVisiblePhraseMarkers.map(\.phrase)
    }

    var recentStudyPhrases: [PhraseItem] {
        store.rootBreadcrumb
            .filter { $0.count > 1 && !store.isPhraseFavorite($0) }
            .compactMap { store.mergedPhrase(for: $0) }
    }

    func studyGridDisplayText(_ text: String) -> String {
        studyGridUsesTraditionalScript ? store.traditionalText(text) : store.simplifiedText(text)
    }

    private func studySortPinyin(_ pinyin: String) -> String {
        pinyin
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct StudyGridEntry: Identifiable {
    let id: String
    let character: String
    let pinyin: String
    let isFavoriteCharacter: Bool
}

struct StudyReviewTile: Identifiable {
    let id: String
    let kind: Kind

    enum Kind {
        case phrase(StudyPhraseRowData)
        case character(StudyGridEntry)
    }

    var pinyin: String {
        switch kind {
        case .phrase(let row): return row.phrase.pinyin
        case .character(let entry): return entry.pinyin
        }
    }

    var sortText: String {
        switch kind {
        case .phrase(let row): return row.phrase.word
        case .character(let entry): return entry.character
        }
    }

    static func phraseTile(_ row: StudyPhraseRowData) -> StudyReviewTile {
        StudyReviewTile(id: "phraseTile:\(row.id)", kind: .phrase(row))
    }

    static func characterTile(_ entry: StudyGridEntry) -> StudyReviewTile {
        StudyReviewTile(id: "characterTile:\(entry.id)", kind: .character(entry))
    }
}

struct StudyPhraseRowData: Identifiable {
    let phrase: PhraseItem
    let marker: StudyPhraseMarker

    var id: String { "\(marker.idPrefix):\(phrase.word)" }
}

enum StudyPhraseMarker {
    case favorite
    case recent

    var idPrefix: String {
        switch self {
        case .favorite: return "phrase"
        case .recent: return "recentPhrase"
        }
    }
}
