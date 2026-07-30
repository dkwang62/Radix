import SwiftUI

extension FavouritesTab {
    var favouritesScrollContent: some View {
        Group {
            if studyAICleanedPageCollectionID != nil {
                aiCleanedPageStudyScreen
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    if showsStudyPinnedControls {
                        studyPinnedControls
                    }

                    if isShowingConversationPractice {
                        ScrollView {
                            conversationPracticeStudyScreen
                                .padding(.horizontal)
                                .padding(.bottom, 20)
                        }
                    } else if isShowingAddedPhraseReview {
                        addedPhraseReviewStudyScreen
                    } else if isShowingSentenceExamples {
                        sentenceExamplesStudyScreen
                    } else {
                        ScrollView {
                            studyReviewScrollContent
                                .padding(.horizontal)
                                .padding(.bottom, 20)
                        }
                    }
                }
            }
        }
    }

    var studyPinnedControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            recentStudyHeader
        }
        .padding(.horizontal)
        .padding(.top, 2)
        .padding(.bottom, 8)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(RadixTheme.separator.opacity(0.72))
                .frame(height: 0.5)
        }
    }

    var studyReviewScrollContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            studyReviewContent
        }
        .padding(.top, 10)
    }

    @ViewBuilder
    var conversationPracticeStudyScreen: some View {
        if conversationPracticeTopics.isEmpty {
            ContentUnavailableView(
                "No Practice Sets",
                systemImage: "bubble.left.and.bubble.right",
                description: Text("Conversation practice sets will appear here when they are available.")
            )
            .frame(maxWidth: .infinity, minHeight: 220)
        } else {
            conversationPracticeSection
        }
    }

    var addedPhraseReviewStudyScreen: some View {
        AddedPhraseReviewSheet(isWorkspace: true, showsWorkspaceCloseButton: false) {
            store.refreshAddedPhrases()
        }
        .environmentObject(store)
    }

    var sentenceExamplesStudyScreen: some View {
        VStack(alignment: .leading, spacing: 10) {
            sentenceExamplesControls
                .padding(.horizontal, isPhone ? 4 : 16)
                .padding(.top, isPhone ? 4 : 8)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: isPhone ? 2 : 8) {
                    if sentenceExampleResultCount == 0 {
                        ContentUnavailableView(
                            "No Sentences",
                            systemImage: RadixGlossaryIcon.systemImage(for: "Sentence"),
                            description: Text("Import page sentences or practice packs to create saved sentences.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 240)
                    } else {
                        ForEach(pagedSentenceExamples) { example in
                            sentenceExampleRow(example)
                        }
                    }
                }
                .padding(.horizontal, isPhone ? 4 : 16)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            refreshSentenceExampleResults()
        }
    }

    func clearFocusedStudySections() {
        focusedStudySection = nil
    }

    func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(ResponsiveFont.caption.bold())
            .foregroundStyle(.secondary)
    }

    func collectionDisplayName(_ collection: CharacterCollection) -> String {
        let name = collection.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? RadixCopy.savedPage : name
    }
}
