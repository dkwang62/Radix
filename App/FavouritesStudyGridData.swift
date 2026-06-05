import SwiftUI

extension FavouritesTab {
    var hasStudyGridItems: Bool {
        !studyReviewTiles.isEmpty
    }

    var studyReviewTiles: [StudyReviewTile] {
        (studyPhraseRows.map(StudyReviewTile.phraseTile)
            + studyCharacterGridEntries.map(StudyReviewTile.characterTile))
            .sorted(by: StudyReviewRules.reviewTileSortPredicate)
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

        return keyedPhrases.values.sorted(by: StudyReviewRules.phraseMarkerSortPredicate)
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
}
