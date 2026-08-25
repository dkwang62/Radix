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
        store.addedPhraseReviewPhrases
    }

    func presentAddedPhraseReview() {
        store.dismissSidebarPhrasePreview()
        store.previewCharacter = nil
        withAnimation(.snappy(duration: 0.18)) {
            screenState.presentFocusedSection(.addedPhrases)
        }
    }

    func sortedStudySavedPages() -> [CharacterCollection] {
        store.sortedCollections(order: studyPageSortOrder)
    }

    var pageIDsWithRecordedPhraseExtractions: Set<UUID> {
        Set(RadixStudyPreferences.pagePhraseExtractions.map(\.sourcePageID))
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

    func isPageSentencePractice(_ pack: ConversationPracticePack) -> Bool {
        guard let sourceTitle = pack.sourceLink?.sourceTitle.trimmingCharacters(in: .whitespacesAndNewlines),
              !sourceTitle.isEmpty
        else {
            return false
        }

        let packTitle = pack.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return packTitle.compare(
            sourceTitle,
            options: [.caseInsensitive, .diacriticInsensitive]
        ) == .orderedSame
    }

    func pagePracticeArtifactTitle(for pack: ConversationPracticePack) -> String {
        isPageSentencePractice(pack) ? "Sentences" : "Conversation"
    }

    func pagePracticeArtifactIcon(for pack: ConversationPracticePack) -> String {
        isPageSentencePractice(pack) ? "text.quote" : "bubble.left.and.bubble.right"
    }

    func pagePhrases(for collection: CharacterCollection) -> [PhraseItem] {
        store.sortPhrasesByPinyin(store.browsePagePhraseCandidates(in: collection).map(\.phrase))
    }

    func hasKnownPagePhrases(for collection: CharacterCollection, hasRecordedPagePhrases: Bool) -> Bool {
        if hasRecordedPagePhrases {
            return true
        }
        if let cachedCandidates = store.browsePagePhraseCandidateCache[collection.id] {
            return !cachedCandidates.isEmpty
        }
        return false
    }

    func showPagePhrases(_ collection: CharacterCollection) {
        let phrases = pagePhrases(for: collection)
        guard !phrases.isEmpty else {
            setStudyPageActionMessage("No page phrases are available for this page.", for: collection)
            return
        }
        studyPagePhrasesPresentation = StudyPagePhrasesPresentation(
            collection: collection,
            phrases: phrases
        )
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
        store.goToBrowseCollection(id: collection.id)
    }

    func openAICleanedPage(_ collection: CharacterCollection) {
        withAnimation(.snappy(duration: 0.18)) {
            screenState.openAICleanedPage(collectionID: collection.id)
        }
        if let record = RadixStudyPreferences.aiCleanedPage(for: collection.id) {
            refreshAICleanedPageSentenceCache(for: record)
        }
    }

    func setStudyPageActionMessage(_ message: String?, for collection: CharacterCollection) {
        studyPageActionMessage = message
        studyPageActionMessageCollectionID = message == nil ? nil : collection.id
        if message != nil {
            expandedStudySavedPageID = collection.id
        }
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

    func beginPromotingOCRCorrection(original: CharacterCollection, corrected: CharacterCollection) {
        pendingStudyOCRPromotion = StudyOCRPromotion(original: original, corrected: corrected)
    }

    func promotePendingOCRCorrection(keepOriginal: Bool) {
        guard let promotion = pendingStudyOCRPromotion else { return }
        pendingStudyOCRPromotion = nil
        guard let promoted = store.promoteCorrectedOCRCollection(
            correctedID: promotion.corrected.id,
            keepOriginalAsArchive: keepOriginal
        ) else {
            setStudyPageActionMessage("Could not make the corrected text the main page.", for: promotion.original)
            RadixHaptics.error()
            return
        }
        loadImportedConversationPracticePacks()
        setStudyPageActionMessage(
            keepOriginal
                ? "Corrected text is now the main page. The original captured page was kept separately."
                : "Corrected text is now the main page. The original captured copy was deleted.",
            for: promoted
        )
        RadixHaptics.success()
    }

    func beginStudyAILinkPageTask(_ collection: CharacterCollection, taskID: String) {
        setStudyPageActionMessage(nil, for: collection)
        store.goToAILinkCollectionTask(collection: collection, taskID: taskID)
    }

    func studyPageAITasks(for collection: CharacterCollection) -> [CollectionPageAITask] {
        CollectionPageAITaskKind.pageTasks(
            for: collection,
            manualAction: { taskID in beginStudyAILinkPageTask(collection, taskID: taskID) },
            automaticAction: { kind in runStudyPageAIAction(kind, for: collection) }
        )
    }

    func runAutomaticStudyPageAIAction(_ action: () -> Void) {
        guard !store.geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            store.goToSettingsForAPIKeySetup()
            return
        }
        action()
    }

    func runStudyPageAIAction(_ kind: CollectionPageAITaskKind, for collection: CharacterCollection) {
        if kind == .createQuiz {
            beginStudyAILinkPageTask(collection, taskID: kind.id)
            return
        }
        runAutomaticStudyPageAIAction {
            switch kind {
            case .checkOCR:
                runAutomaticStudyOCRReview(collection)
            case .createAICleanedPage:
                runStudyGeminiAICleanedPage(collection)
            case .extractPhrases:
                runStudyGeminiPhraseExtraction(collection)
            case .translate:
                runStudyGeminiTranslationAndSave(collection)
            case .extractSentences:
                runStudyGeminiSentenceExtraction(collection)
            case .createPagePractice:
                runStudyGeminiPagePracticeGeneration(collection)
            case .createQuiz:
                break
            }
        }
    }

    func runAutomaticStudyOCRReview(_ collection: CharacterCollection) {
        isRunningStudyPageAction = true
        setStudyPageActionMessage("Checking captured text with Gemini...", for: collection)
        Task {
            do {
                let response = try await store.runGeminiOCRReview(for: collection)
                await MainActor.run {
                    createStudyCorrectedOCRPage(from: response, original: collection)
                    isRunningStudyPageAction = false
                }
            } catch {
                await MainActor.run {
                    offerManualStudyAIFallback(.checkOCR(collection), error: error)
                    isRunningStudyPageAction = false
                }
            }
        }
    }

    func createStudyCorrectedOCRPage(from response: String, original collection: CharacterCollection) {
        do {
            let corrected = try store.createCorrectedOCRCollection(fromAIResponse: response, original: collection)
            setStudyPageActionMessage("Corrected page created: \(corrected.name).", for: collection)
        } catch {
            setStudyPageActionMessage(error.localizedDescription, for: collection)
        }
    }

    func runStudyGeminiPhraseExtraction(_ collection: CharacterCollection) {
        isRunningStudyPageAction = true
        setStudyPageActionMessage("Extracting phrases with Gemini...", for: collection)
        Task {
            do {
                let summary = try await store.runGeminiPhraseExtraction(for: collection)
                await MainActor.run {
                    setStudyPageActionMessage(summary.message(defaultAIName: "Gemini"), for: collection)
                    isRunningStudyPageAction = false
                }
            } catch {
                await MainActor.run {
                    offerManualStudyAIFallback(.extractPhrases(collection), error: error)
                    isRunningStudyPageAction = false
                }
            }
        }
    }

    func runStudyGeminiTranslationAndSave(_ collection: CharacterCollection) {
        isRunningStudyPageAction = true
        setStudyPageActionMessage("Explaining page with Gemini...", for: collection)
        Task {
            do {
                let report = try await store.runGeminiTranslationReport(for: collection)
                await MainActor.run {
                    let updated = store.collection(id: collection.id) ?? collection
                    studyTranslationReportCollection = updated
                    studyTranslationReportDraft = updated.translationReport ?? report
                    setStudyPageActionMessage("Page explanation saved.", for: collection)
                    isRunningStudyPageAction = false
                }
            } catch {
                await MainActor.run {
                    offerManualStudyAIFallback(.translate(collection), error: error)
                    isRunningStudyPageAction = false
                }
            }
        }
    }

    func runStudyGeminiSentenceExtraction(_ collection: CharacterCollection) {
        isRunningStudyPageAction = true
        setStudyPageActionMessage("Extracting sentences with Gemini...", for: collection)
        Task {
            do {
                let pack = try await store.runGeminiPageSentenceExtraction(for: collection)
                await MainActor.run {
                    loadImportedConversationPracticePacks()
                    setStudyPageActionMessage("Loaded \(pack.title) · \(pack.entries.count) sentences.", for: collection)
                    isRunningStudyPageAction = false
                }
            } catch {
                await MainActor.run {
                    offerManualStudyAIFallback(.extractSentences(collection), error: error)
                    isRunningStudyPageAction = false
                }
            }
        }
    }

    func runStudyGeminiPagePracticeGeneration(_ collection: CharacterCollection) {
        isRunningStudyPageAction = true
        setStudyPageActionMessage("Creating page-inspired practice with Gemini...", for: collection)
        Task {
            do {
                let pack = try await store.runGeminiPagePracticeGeneration(for: collection)
                await MainActor.run {
                    loadImportedConversationPracticePacks()
                    setStudyPageActionMessage("Loaded \(pack.title) · \(pack.entries.count) sentences.", for: collection)
                    isRunningStudyPageAction = false
                }
            } catch {
                await MainActor.run {
                    offerManualStudyAIFallback(.createPagePractice(collection), error: error)
                    isRunningStudyPageAction = false
                }
            }
        }
    }

    func runStudyGeminiAICleanedPage(_ collection: CharacterCollection) {
        isRunningStudyPageAction = true
        setStudyPageActionMessage("Extracting sentences with Gemini...", for: collection)
        Task {
            do {
                let record = try await store.runGeminiAICleanedPage(for: collection)
                await MainActor.run {
                    setStudyPageActionMessage("AI page saved: \(record.cleanedTitle.isEmpty ? collection.name : record.cleanedTitle).", for: collection)
                    openAICleanedPage(collection)
                    isRunningStudyPageAction = false
                }
            } catch {
                await MainActor.run {
                    offerManualStudyAIFallback(.createAICleanedPage(collection), error: error)
                    isRunningStudyPageAction = false
                }
            }
        }
    }

    func offerManualStudyAIFallback(_ task: BrowseAIFallbackTask, error: Error) {
        studyAutomaticAIError = error.localizedDescription
        setStudyPageActionMessage(
            "Automatic Gemini is unavailable. You can still copy the prompt to an AI chat.",
            for: task.collection
        )
        studyAIFallbackTask = task
    }

    func useManualStudyAIFallback(_ task: BrowseAIFallbackTask) {
        beginStudyAILinkPageTask(task.collection, taskID: task.taskID)
    }

    func openStudyPracticePack(_ pack: ConversationPracticePack, from collection: CharacterCollection) {
        withAnimation(.snappy(duration: 0.18)) {
            screenState.openConversationPractice(fromPageID: collection.id)
        }
        selectConversationPracticeTopic(conversationPracticeTopic(for: pack.practiceLibrary))
    }

    func returnToOriginatingStudyPage() {
        guard let collectionID = screenState.navigation.pageReturnCollectionID else { return }
        withAnimation(.snappy(duration: 0.18)) {
            _ = screenState.returnToOriginatingPage()
        }
        store.selectBrowseCollection(id: collectionID)
        syncActiveStudySectionTitle()
    }
}
