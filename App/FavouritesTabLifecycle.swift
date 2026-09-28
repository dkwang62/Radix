import SwiftUI

extension FavouritesTab {
    func studyLifecycle<Content: View>(_ content: Content) -> some View {
        content
            .onAppear {
                if pageArtifactsOnly {
                    loadStudyPageReferenceData()
                    return
                }
                studyGridUsesTraditionalScript = RadixStudyPreferences.usesTraditionalScript
                studyGridScope = RadixStudyPreferences.initialGridScope
                studyPageSortOrder = RadixStudyPreferences.pageSortOrder
                openAddedPhraseReviewIfRequested()
                loadInitialStudyReferenceData()
                openPendingConversationPracticeIfNeeded()
                applyInitialStudyNavigationTargetIfNeeded()
            }
            .onChange(of: studyGridUsesTraditionalScript) { _, newValue in
                RadixStudyPreferences.usesTraditionalScript = newValue
            }
            .onChange(of: studyGridScope) { _, newValue in
                guard !pageArtifactsOnly else { return }
                RadixStudyPreferences.gridScope = newValue
                syncActiveStudySectionTitle()
            }
            .onChange(of: focusedStudySection) { _, _ in
                guard !pageArtifactsOnly else { return }
                syncActiveStudySectionTitle()
            }
            .onChange(of: store.requestedStudyNavigationTarget) { _, target in
                guard !pageArtifactsOnly else { return }
                applyRequestedStudyNavigationTarget(target)
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
                if pageArtifactsOnly {
                    loadStudyPageReferenceData()
                    return
                }
                store.didMigrateLegacyPhraseFavoritesToFavoriteSentences = false
                reloadVisibleStudyReferenceData()
                sentenceExampleRevision += 1
                refreshSentenceExampleResults()
            }
            .onChange(of: store.pageArtifactRevision) { _, _ in
                if pageArtifactsOnly { loadStudyPageReferenceData() }
            }
            .onChange(of: store.favoriteSentenceRevision) { _, _ in
                guard !pageArtifactsOnly else { return }
                loadFavoriteSentences()
                loadConversationPracticeLibrary()
                refreshSentenceExampleResults()
            }
    }

    func loadInitialStudyReferenceData() {
        let requestedTarget = store.requestedStudyNavigationTarget
        let opensSavedPages = requestedTarget == .savedPages || (
            requestedTarget == nil &&
                focusedStudySection == nil &&
                !showStudyCheckpoints &&
                studyGridScope == .savedPages
        )
        if opensSavedPages {
            loadStudyPageReferenceData()
        } else {
            loadStudyReferenceData()
        }
    }

    func reloadVisibleStudyReferenceData() {
        if focusedStudySection == nil, !showStudyCheckpoints, studyGridScope == .savedPages {
            loadStudyPageReferenceData()
        } else {
            loadStudyReferenceData()
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
            screenState.presentReview(scope: .all)
        case .favorites:
            screenState.presentReview(scope: .favorites)
        case .savedPages:
            store.requestedStudyNavigationTarget = nil
            store.goToPagesWorkspace()
            return
        case .addedPhrases:
            presentAddedPhraseReview()
        case .conversationPractice:
            presentConversationPractice()
        case .sentences:
            presentSentenceExamples()
        case .checkpoints:
            screenState.presentCheckpoints()
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
        guard let topic = conversationPracticeTopics.first(where: { $0.id == topicID }) else {
            store.pendingConversationPracticeTopicID = nil
            return
        }
        selectConversationPracticeTopic(topic)
        withAnimation(.snappy(duration: 0.18)) {
            screenState.presentFocusedSection(.conversationPractice)
        }
        store.pendingConversationPracticeTopicID = nil
    }
}
