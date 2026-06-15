import SwiftUI

extension FavouritesTab {
    var hasStudyGridItems: Bool {
        !studyReviewTiles.isEmpty
    }

    var studyReviewTiles: [StudyReviewTile] {
        switch studyGridScope {
        case .all:
            return recentStudyReviewTiles
        case .favorites:
            return (studyPhraseRows.map(StudyReviewTile.phraseTile) + studyCharacterGridEntries
                .map(StudyReviewTile.characterTile)
            )
                .sorted(by: StudyReviewRules.reviewTileSortPredicate)
        }
    }

    var recentStudyReviewTiles: [StudyReviewTile] {
        let visiblePhraseCharacters = Set(recentStudyPhrases.flatMap { phrase in
            phrase.word.map { String($0) }
        })

        return store.rootBreadcrumb.compactMap { item in
            if item.count > 1 {
                guard !store.isPhraseFavorite(item), let phrase = store.mergedPhrase(for: item) else { return nil }
                return StudyReviewTile.phraseTile(StudyPhraseRowData(phrase: phrase, marker: .recent))
            }

            guard !store.isFavorite(item),
                  !visiblePhraseCharacters.contains(item),
                  let component = store.item(for: item)
            else {
                return nil
            }

            return StudyReviewTile.characterTile(StudyGridEntry(
                id: "recent:\(component.character)",
                character: component.character,
                pinyin: component.pinyinText,
                isFavoriteCharacter: false
            ))
        }
    }

    var studyPhraseRows: [StudyPhraseRowData] {
        studyVisiblePhraseMarkers.map { phrase, marker in
            StudyPhraseRowData(phrase: phrase, marker: marker)
        }
    }

    var studyVisiblePhraseMarkers: [(phrase: PhraseItem, marker: StudyPhraseMarker)] {
        switch studyGridScope {
        case .all:
            return recentStudyPhrases.map { ($0, .recent) }
        case .favorites:
            return store.favoritePhrasesItems
                .map { ($0, .favorite) }
                .sorted(by: StudyReviewRules.phraseMarkerSortPredicate)
        }
    }

    var studyCharacterGridEntries: [StudyGridEntry] {
        let visiblePhraseCharacters = Set(studyVisiblePhrases.flatMap { phrase in
            phrase.word.map { String($0) }
        })

        switch studyGridScope {
        case .all:
            return store.recentOnlyCharacterItems
                .filter { !visiblePhraseCharacters.contains($0.character) }
                .map { item in
                    StudyGridEntry(
                        id: "recent:\(item.character)",
                        character: item.character,
                        pinyin: item.pinyinText,
                        isFavoriteCharacter: false
                    )
                }
        case .favorites:
            return store.favoriteItems
                .filter { !visiblePhraseCharacters.contains($0.character) }
                .map { item in
                    StudyGridEntry(
                        id: "character:\(item.character)",
                        character: item.character,
                        pinyin: item.pinyinText,
                        isFavoriteCharacter: true
                    )
                }
        }
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

    var addedStudyPhraseEntries: [PhraseItem] {
        store.addedPhrases
            .filter { $0.word.count >= 2 && !store.isPhraseInBase($0.word) }
            .sorted(by: AddedPhraseReviewRules.reviewSortPredicate)
    }

    func addedStudyPhraseCount(status: PhraseReviewStatus?) -> Int {
        addedStudyPhraseEntries.filter { $0.reviewStatus == status }.count
    }

    func presentAddedPhraseReview() {
        addedPhraseReviewPresentation = nil
        DispatchQueue.main.async {
            addedPhraseReviewPresentation = AddedPhraseReviewPresentation()
        }
    }
}
