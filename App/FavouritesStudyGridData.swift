import SwiftUI

extension FavouritesTab {
    var hasStudyGridItems: Bool {
        studyGridScope == .savedPages ? !store.allCollections.isEmpty : !studyReviewTiles.isEmpty
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
        case .savedPages:
            return []
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
        case .savedPages:
            return []
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
        case .savedPages:
            return []
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

    func presentAddedPhraseReview() {
        addedPhraseReviewPresentation = nil
        DispatchQueue.main.async {
            addedPhraseReviewPresentation = AddedPhraseReviewPresentation()
        }
    }

    func sortedStudySavedPages() -> [CharacterCollection] {
        store.sortedCollections(order: studyPageSortOrder)
    }

    func correctedStudyPages(for collection: CharacterCollection) -> [CharacterCollection] {
        store.allCollections
            .filter { $0.correctedFromCollectionID == collection.id }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func pagePracticePacks(for collection: CharacterCollection) -> [ConversationPracticePack] {
        RadixStudyPreferences.importedConversationPracticePacks
            .filter { $0.sourceLink?.sourcePageID == collection.id }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func favoriteSentenceCount(for packs: [ConversationPracticePack]) -> Int {
        let packIDs = Set(packs.map(\.packID))
        return favoriteSentenceRecords.filter { packIDs.contains($0.sourceSetID) }.count
    }

    func practiceProgressCount(for packs: [ConversationPracticePack]) -> Int {
        let packIDs = Set(packs.map(\.packID))
        return conversationPracticeProgress.records.filter { packIDs.contains($0.packID) }.count
    }

    func openSavedPageInBrowse(_ collection: CharacterCollection) {
        store.goToBrowsePages(selectLatest: false, preservingOrigin: true)
        store.selectBrowseCollection(id: collection.id)
    }

    func showStudyTranslationReport(_ collection: CharacterCollection) {
        studyTranslationReportDraft = collection.translationReport ?? ""
        studyTranslationReportCollection = collection
    }

    func pasteStudyTranslationReport() {
        studyTranslationReportDraft = RadixPlatform.pasteboardString
    }

    func saveStudyTranslationReport(_ collection: CharacterCollection) {
        let updated = store.saveTranslationReport(fromAIResponse: studyTranslationReportDraft, for: collection)
        studyTranslationReportCollection = updated
        studyTranslationReportDraft = updated.translationReport ?? ""
    }

    func clearStudyTranslationReport(_ collection: CharacterCollection) {
        studyTranslationReportDraft = ""
        store.updateCollectionTranslationReport(id: collection.id, report: nil)
        if let updated = store.collection(id: collection.id) {
            studyTranslationReportCollection = updated
        }
    }

    func beginStudyPageQuiz(_ collection: CharacterCollection) {
        studyPageQuizQuestions = store.pageQuizQuestions(for: collection)
        studyPageQuizMessage = "Using a local Radix quiz from this saved page."
        isGeneratingStudyPageQuiz = false
        studyPageQuizCollection = collection
    }

    func useLocalStudyPageQuizFallback(_ collection: CharacterCollection) {
        studyPageQuizQuestions = store.pageQuizQuestions(for: collection)
        studyPageQuizMessage = "Using a local Radix quiz because AI generation is unavailable."
        isGeneratingStudyPageQuiz = false
    }

    func openStudyPracticePack(_ pack: ConversationPracticePack) {
        withAnimation(.snappy(duration: 0.18)) {
            isShowingConversationPractice = true
        }
        selectConversationPracticeTopic(conversationPracticeTopic(for: pack.practiceLibrary))
    }
}
