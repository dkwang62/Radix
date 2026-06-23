import SwiftUI

struct FavouritesTab: View {
    @EnvironmentObject var store: RadixStore
    @EnvironmentObject var entitlement: EntitlementManager
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    let onExportProfile: () -> Void
    let onImportProfile: () -> Void
    let onRequirePro: (EntitlementManager.FeatureGate) -> Void
    var onSaveSnapshot: (() -> Void)?
    var onRestoreSnapshot: ((LocalDataSnapshot?) -> Void)?
    var onRefreshSnapshots: (() -> Void)?
    var localSnapshots: [LocalDataSnapshot] = []
    var isSavingSnapshot = false
    var isRestoringSnapshot = false
    @State var selectedPhrase: PhraseItem?
    @State var studyGridUsesTraditionalScript = RadixStudyPreferences.usesTraditionalScript
    @State var studyGridScope = RadixStudyPreferences.gridScope
    @State var studyPageSortOrder = RadixStudyPreferences.pageSortOrder
    @State var hasDismissedStudyIntro = RadixStudyPreferences.hasDismissedIntro
    @State var addedPhraseReviewPresentation: AddedPhraseReviewPresentation?
    @State var pendingSnapshotRestore: LocalDataSnapshot?

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
        .safeAreaInset(edge: .bottom) {
            if isPhone && !isPhoneStudyPreviewActive && hasStudyContent {
                VStack(spacing: 0) {
                    Divider()
                    studySnapshotActions
                        .padding(.horizontal)
                        .padding(.top, 10)
                        .padding(.bottom, 8)
                }
                .background(.ultraThinMaterial)
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
        .alert("Replace My Data?", isPresented: Binding(
            get: { pendingSnapshotRestore != nil },
            set: { if !$0 { pendingSnapshotRestore = nil } }
        )) {
            Button("Replace My Data", role: .destructive) {
                let snapshot = pendingSnapshotRestore
                pendingSnapshotRestore = nil
                onRestoreSnapshot?(snapshot)
            }
            Button("Cancel", role: .cancel) {
                pendingSnapshotRestore = nil
            }
        } message: {
            Text("Current data on this device will be replaced with the selected device snapshot.")
        }
        .sheet(item: $addedPhraseReviewPresentation, onDismiss: {
            addedPhraseReviewPresentation = nil
        }) { _ in
            AddedPhraseReviewSheet()
                .environmentObject(store)
        }
        .onAppear {
            studyGridUsesTraditionalScript = RadixStudyPreferences.usesTraditionalScript
            studyGridScope = RadixStudyPreferences.gridScope
            studyPageSortOrder = RadixStudyPreferences.pageSortOrder
            hasDismissedStudyIntro = RadixStudyPreferences.hasDismissedIntro
            if onSaveSnapshot != nil || onRestoreSnapshot != nil {
                onRefreshSnapshots?()
            }
            openAddedPhraseReviewIfRequested()
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
