import SwiftUI

struct FavouritesTab: View {
    @EnvironmentObject var store: RadixStore
    @EnvironmentObject var entitlement: EntitlementManager
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    let onExportProfile: () -> Void
    let onImportProfile: () -> Void
    let onRequirePro: (EntitlementManager.FeatureGate) -> Void
    let onOpenProtectRecover: () -> Void
    let onCreateCheckpoint: () -> Void
    let onReturnToCheckpoint: (LocalDataSnapshot?) -> Void
    let onRefreshCheckpoints: () -> Void
    let checkpoints: [LocalDataSnapshot]
    let isCreatingCheckpoint: Bool
    let isReturningToCheckpoint: Bool
    @State var selectedPhrase: PhraseItem?
    @State var studyGridUsesTraditionalScript = RadixStudyPreferences.usesTraditionalScript
    @State var studyGridScope = RadixStudyPreferences.gridScope
    @State var studyPageSortOrder = RadixStudyPreferences.pageSortOrder
    @State var hasDismissedStudyIntro = RadixStudyPreferences.hasDismissedIntro
    @State var addedPhraseReviewPresentation: AddedPhraseReviewPresentation?
    @State var pendingCheckpointReturn: LocalDataSnapshot?
    @State var conversationPracticeLibrary: ConversationPracticeLibrary? = try? ConversationPracticeService().loadStarterLibrary()
    @State var conversationPracticeReviewPresentation: ConversationPracticeReviewPresentation?
    @State var conversationPracticeQuizPresentation: ConversationPracticeQuizPresentation?

    var isPhone: Bool {
        RadixPlatform.isPhone
    }

    var isNarrowStudyLayout: Bool {
        RadixPlatform.interfaceIdiom.usesNarrowLayout(horizontalIsCompact: horizontalSizeClass == .compact)
    }

    var hasStudyContent: Bool {
        store.recentCharacterCount > 0
            || store.rootBreadcrumb.contains { $0.count > 1 }
            || !store.favoriteItems.isEmpty
            || !store.favoritePhrasesItems.isEmpty
            || !store.allCollections.isEmpty
            || !addedStudyPhraseEntries.isEmpty
            || conversationPracticeLibrary != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            favouritesHeader

            if isPhoneStudyPreviewActive {
                ScrollView {
                    phoneStudyPreview
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                }
            } else if hasStudyContent {
                favouritesScrollContent
            } else {
                ContentUnavailableView("No Study Items", systemImage: "clock.badge.questionmark", description: Text("Search, take a photo, or star a character."))
            }
        }
        .sheet(item: phonePhraseSheetBinding) { phrase in
            NavigationStack {
                PhraseInfoCard(phrase: phrase, onDone: {
                    selectedPhrase = nil
                    })
                    .environmentObject(store)
                    .padding()
                    .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $addedPhraseReviewPresentation, onDismiss: {
            addedPhraseReviewPresentation = nil
        }) { _ in
            AddedPhraseReviewSheet()
                .environmentObject(store)
        }
        .sheet(item: $conversationPracticeReviewPresentation, onDismiss: {
            conversationPracticeReviewPresentation = nil
        }) { presentation in
            ConversationPracticeReviewSheet(
                library: presentation.library,
                onOpenPhrase: { phrase in
                    presentPhrase(phrase)
                },
                onOpenCharacter: { character in
                    store.preview(character: character)
                }
            )
            .environmentObject(store)
        }
        .sheet(item: $conversationPracticeQuizPresentation, onDismiss: {
            conversationPracticeQuizPresentation = nil
        }) { presentation in
            ConversationPracticeQuizSheet(
                library: presentation.library,
                onOpenPhrase: { phrase in
                    presentPhrase(phrase)
                },
                onOpenCharacter: { character in
                    store.preview(character: character)
                }
            )
            .environmentObject(store)
        }
        .alert("Return to Checkpoint?", isPresented: Binding(
            get: { pendingCheckpointReturn != nil },
            set: { if !$0 { pendingCheckpointReturn = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                pendingCheckpointReturn = nil
            }
            Button("Return to Checkpoint", role: .destructive) {
                let checkpoint = pendingCheckpointReturn
                pendingCheckpointReturn = nil
                onReturnToCheckpoint(checkpoint)
            }
        } message: {
            Text("Current study data on this device will be replaced by the selected checkpoint. Backup files are not affected.")
        }
        .onAppear {
            studyGridUsesTraditionalScript = RadixStudyPreferences.usesTraditionalScript
            studyGridScope = RadixStudyPreferences.gridScope
            studyPageSortOrder = RadixStudyPreferences.pageSortOrder
            hasDismissedStudyIntro = RadixStudyPreferences.hasDismissedIntro
            openAddedPhraseReviewIfRequested()
            loadConversationPracticeLibrary()
            onRefreshCheckpoints()
        }
        .onChange(of: studyGridUsesTraditionalScript) { _, newValue in
            RadixStudyPreferences.usesTraditionalScript = newValue
        }
        .onChange(of: studyGridScope) { _, newValue in
            RadixStudyPreferences.gridScope = newValue
        }
        .onChange(of: studyPageSortOrder) { _, newValue in
            RadixStudyPreferences.pageSortOrder = newValue
        }
        .onChange(of: hasDismissedStudyIntro) { _, newValue in
            RadixStudyPreferences.hasDismissedIntro = newValue
        }
        .onChange(of: store.shouldOpenAddedPhraseReview) { _, newValue in
            guard newValue else { return }
            openAddedPhraseReviewIfRequested()
        }
    }

    func openAddedPhraseReviewIfRequested() {
        guard store.shouldOpenAddedPhraseReview else { return }
        store.shouldOpenAddedPhraseReview = false
        guard !addedStudyPhraseEntries.isEmpty else { return }
        presentAddedPhraseReview()
    }

    func loadConversationPracticeLibrary() {
        conversationPracticeLibrary = try? ConversationPracticeService().loadStarterLibrary()
    }

    func presentConversationPracticeReview(_ library: ConversationPracticeLibrary) {
        conversationPracticeReviewPresentation = ConversationPracticeReviewPresentation(library: library)
    }

    func presentConversationPracticeQuiz(_ library: ConversationPracticeLibrary) {
        conversationPracticeQuizPresentation = ConversationPracticeQuizPresentation(library: library)
    }

    var isPhoneStudyPreviewActive: Bool {
        isPhone && (store.previewCharacter != nil || store.activeSidebarPhrasePreview != nil)
    }

    var phoneStudyPreview: some View {
        PhoneContextPreview(
            returnTitle: "Study",
            returnSystemImage: RadixIcon.study,
            phrase: store.activeSidebarPhrasePreview,
            character: store.previewCharacter,
            onReturn: {
                selectedPhrase = nil
                store.dismissSidebarPhrasePreview()
                store.previewCharacter = nil
            }
        )
        .environmentObject(store)
    }
}

enum StudyGridScope: String, CaseIterable, Identifiable {
    case all = "All"
    case favorites = "Saved"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "Recent"
        case .favorites: return "Favorite"
        }
    }

    var emptyMessage: String {
        switch self {
        case .all: return "No recent study items yet."
        case .favorites: return "No favorite study items yet."
        }
    }

    var legendText: String {
        switch self {
        case .all: return "Tap an item to preview it. Favorite the useful ones, then clear Recent."
        case .favorites: return "Tap a favorite character or phrase to preview it. Use the star to remove it from Favorites."
        }
    }
}
