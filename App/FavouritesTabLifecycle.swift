import SwiftUI

extension FavouritesTab {
    func studyLifecycle<Content: View>(_ content: Content) -> some View {
        content
            .onAppear {
                studyGridUsesTraditionalScript = RadixStudyPreferences.usesTraditionalScript
                studyGridScope = RadixStudyPreferences.initialGridScope
                studyPageSortOrder = RadixStudyPreferences.pageSortOrder
                openAddedPhraseReviewIfRequested()
                loadImportedConversationPracticePacks()
                loadFavoriteSentences()
                loadConversationPracticeLibrary()
                openPendingConversationPracticeIfNeeded()
                onRefreshCheckpoints()
                applyInitialStudyNavigationTargetIfNeeded()
            }
            .onChange(of: studyGridUsesTraditionalScript) { _, newValue in
                RadixStudyPreferences.usesTraditionalScript = newValue
            }
            .onChange(of: studyGridScope) { _, newValue in
                RadixStudyPreferences.gridScope = newValue
                syncActiveStudySectionTitle()
            }
            .onChange(of: focusedStudySection) { _, _ in
                syncActiveStudySectionTitle()
            }
            .onChange(of: store.requestedStudyNavigationTarget) { _, target in
                applyRequestedStudyNavigationTarget(target)
            }
            .onChange(of: store.selectedBrowseCollectionID) { _, selectedPageID in
                guard studyGridScope == .savedPages else { return }
                expandedStudySavedPageID = selectedPageID
            }
            .onChange(of: studyPageSortOrder) { _, newValue in
                RadixStudyPreferences.pageSortOrder = newValue
            }
            .onChange(of: store.shouldOpenAddedPhraseReview) { _, newValue in
                guard newValue else { return }
                openAddedPhraseReviewIfRequested()
            }
            .onChange(of: store.selectedConversationPracticeTopicID) { _, _ in
                loadConversationPracticeLibrary()
            }
            .onChange(of: store.pendingConversationPracticeTopicID) { _, _ in
                openPendingConversationPracticeIfNeeded()
            }
            .onChange(of: store.dataImportRevision) { _, _ in
                loadImportedConversationPracticePacks()
                loadFavoriteSentences()
                loadConversationPracticeLibrary()
                sentenceExampleRevision += 1
                refreshSentenceExampleResults()
            }
            .onChange(of: store.favoriteSentenceRevision) { _, _ in
                loadFavoriteSentences()
                loadConversationPracticeLibrary()
                refreshSentenceExampleResults()
            }
    }

    func syncActiveStudySectionTitle() {
        store.activeStudySectionTitle = activeStudySectionTitle
    }

    func applyInitialStudyNavigationTargetIfNeeded() {
        if let target = store.requestedStudyNavigationTarget {
            applyRequestedStudyNavigationTarget(target)
        } else if store.activeStudySectionTitle == StudyNavigationTarget.sentences.title,
                  focusedStudySection == nil {
            presentSentenceExamples()
            syncActiveStudySectionTitle()
        } else {
            syncActiveStudySectionTitle()
        }
    }

    func applyRequestedStudyNavigationTarget(_ target: StudyNavigationTarget?) {
        guard let target else { return }
        switch target {
        case .recent:
            clearFocusedStudySections()
            studyGridScope = .all
            showStudyCheckpoints = false
        case .favorites:
            clearFocusedStudySections()
            studyGridScope = .favorites
            showStudyCheckpoints = false
        case .savedPages:
            clearFocusedStudySections()
            studyGridScope = .savedPages
            showStudyCheckpoints = false
            if store.selectedBrowseCollectionID == nil,
               let firstPage = store.sortedCollections(order: .lastViewed).first {
                store.selectBrowseCollection(id: firstPage.id)
            }
            if let selectedPageID = store.selectedBrowseCollectionID {
                expandedStudySavedPageID = selectedPageID
            }
        case .addedPhrases:
            presentAddedPhraseReview()
        case .conversationPractice:
            presentConversationPractice()
        case .sentences:
            presentSentenceExamples()
        case .checkpoints:
            clearFocusedStudySections()
            showStudyCheckpoints = true
        }
        store.requestedStudyNavigationTarget = nil
        syncActiveStudySectionTitle()
    }

    func openAddedPhraseReviewIfRequested() {
        guard store.shouldOpenAddedPhraseReview else { return }
        store.shouldOpenAddedPhraseReview = false
        guard !addedStudyPhraseEntries.isEmpty else { return }
        presentAddedPhraseReview()
    }

    func openPendingConversationPracticeIfNeeded() {
        guard let topicID = store.pendingConversationPracticeTopicID else { return }
        loadImportedConversationPracticePacks()
        guard let topic = conversationPracticeTopics.first(where: { $0.id == topicID }) else {
            store.pendingConversationPracticeTopicID = nil
            return
        }
        selectConversationPracticeTopic(topic)
        withAnimation(.snappy(duration: 0.18)) {
            focusedStudySection = .conversationPractice
            studyAICleanedPageCollectionID = nil
        }
        store.pendingConversationPracticeTopicID = nil
    }
}
