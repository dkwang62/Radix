import SwiftUI

extension FavouritesTab {
    var hasStudyGridItems: Bool {
        !studyGridEntries.isEmpty
    }

    var studyGridEntries: [StudyGridEntry] {
        studyPhraseGridEntries + studyCharacterGridEntries
    }

    var studyPhraseGridEntries: [StudyGridEntry] {
        studyVisiblePhraseMarkers.flatMap { phrase, marker in
            studyPhraseEntries(for: phrase, idPrefix: marker.idPrefix, marker: marker)
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
            let leftCount = lhs.phrase.word.count
            let rightCount = rhs.phrase.word.count
            if leftCount != rightCount { return leftCount < rightCount }

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
                    phrase: nil,
                    phraseRole: nil,
                    isFavoriteCharacter: true,
                    phraseMarker: nil
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
                    phrase: nil,
                    phraseRole: nil,
                    isFavoriteCharacter: false,
                    phraseMarker: nil
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

    func studyPhraseEntries(for phrase: PhraseItem, idPrefix: String, marker: StudyPhraseMarker) -> [StudyGridEntry] {
        let markerEntry = StudyGridEntry(
            id: "\(idPrefix):\(phrase.word):marker",
            character: "",
            pinyin: "",
            phrase: phrase,
            phraseRole: nil,
            isFavoriteCharacter: false,
            phraseMarker: marker
        )

        let characterEntries = Array(phrase.word).enumerated().compactMap { offset, rawCharacter -> StudyGridEntry? in
            let character = String(rawCharacter)
            guard let item = store.item(for: character) else { return nil }
            return StudyGridEntry(
                id: "\(idPrefix):\(phrase.word):\(offset)",
                character: character,
                pinyin: item.pinyinText,
                phrase: phrase,
                phraseRole: offset == 0 ? .target : .phraseMember,
                isFavoriteCharacter: false,
                phraseMarker: nil
            )
        }

        return [markerEntry] + characterEntries
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
    let phrase: PhraseItem?
    let phraseRole: ImagePhraseHighlightRole?
    let isFavoriteCharacter: Bool
    let phraseMarker: StudyPhraseMarker?
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
