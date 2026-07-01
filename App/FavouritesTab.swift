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
    @State var studyMode: StudyMode = .review
    @State var studyGridUsesTraditionalScript = RadixStudyPreferences.usesTraditionalScript
    @State var studyGridScope = RadixStudyPreferences.gridScope
    @State var studyPageSortOrder = RadixStudyPreferences.pageSortOrder
    @State var hasDismissedStudyIntro = RadixStudyPreferences.hasDismissedIntro
    @State var addedPhraseReviewPresentation: AddedPhraseReviewPresentation?
    @State var pendingCheckpointReturn: LocalDataSnapshot?
    @State var conversationPracticeTopics = ConversationPracticeTopic.defaults
    @State var conversationPracticeLibrary: ConversationPracticeLibrary? = try? ConversationPracticeService().loadLibrary(for: .generalGreetings)
    @State var importedConversationPracticeLibraries: [String: ConversationPracticeLibrary] = [:]
    @State var showConversationPracticeImporter = false
    @State var conversationPracticeImportMessage: String?
    @State var conversationPracticeImportError: String?
    @State var pendingConversationPracticeDeletion: ConversationPracticeTopic?
    @State var isConversationPracticeExpanded = false
    @State var selectedConversationPracticeItemID: String?
    @State var conversationPracticeReviewPresentation: ConversationPracticeReviewPresentation?
    @State var conversationPracticeQuizPresentation: ConversationPracticeQuizPresentation?

    private let conversationPracticeService = ConversationPracticeService()

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
            || !conversationPracticeTopics.isEmpty
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
                usesTraditionalScript: $studyGridUsesTraditionalScript
            )
            .environmentObject(store)
            .environmentObject(entitlement)
        }
        .sheet(item: $conversationPracticeQuizPresentation, onDismiss: {
            conversationPracticeQuizPresentation = nil
        }) { presentation in
            ConversationPracticeQuizSheet(
                library: presentation.library,
                usesTraditionalScript: $studyGridUsesTraditionalScript
            )
            .environmentObject(store)
            .environmentObject(entitlement)
        }
        .fileImporter(
            isPresented: $showConversationPracticeImporter,
            allowedContentTypes: [RadixFileTypes.json],
            allowsMultipleSelection: false
        ) { result in
            importConversationPracticePack(result)
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
        .alert("Delete Practice?", isPresented: Binding(
            get: { pendingConversationPracticeDeletion != nil },
            set: { if !$0 { pendingConversationPracticeDeletion = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                pendingConversationPracticeDeletion = nil
            }
            Button("Delete Practice", role: .destructive) {
                guard let topic = pendingConversationPracticeDeletion else { return }
                pendingConversationPracticeDeletion = nil
                deleteConversationPracticeTopic(topic)
            }
        } message: {
            Text("This removes the imported practice set from this device.")
        }
        .onAppear {
            studyGridUsesTraditionalScript = RadixStudyPreferences.usesTraditionalScript
            studyGridScope = RadixStudyPreferences.gridScope
            studyPageSortOrder = RadixStudyPreferences.pageSortOrder
            hasDismissedStudyIntro = RadixStudyPreferences.hasDismissedIntro
            openAddedPhraseReviewIfRequested()
            loadImportedConversationPracticePacks()
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
        .onChange(of: store.selectedConversationPracticeTopicID) { _, _ in
            loadConversationPracticeLibrary()
        }
    }

    func openAddedPhraseReviewIfRequested() {
        guard store.shouldOpenAddedPhraseReview else { return }
        store.shouldOpenAddedPhraseReview = false
        guard !addedStudyPhraseEntries.isEmpty else { return }
        presentAddedPhraseReview()
    }

    func loadConversationPracticeLibrary() {
        let topic = selectedConversationPracticeTopic
        if let importedLibrary = importedConversationPracticeLibraries[topic.id] {
            conversationPracticeLibrary = importedLibrary
        } else {
            conversationPracticeLibrary = try? conversationPracticeService.loadLibrary(for: topic)
        }
        if let conversationPracticeLibrary {
            store.registerConversationPracticeLibrary(conversationPracticeLibrary)
            if let selectedConversationPracticeItemID,
               !conversationPracticeLibrary.items.contains(where: { $0.id == selectedConversationPracticeItemID }) {
                self.selectedConversationPracticeItemID = nil
            }
        }
    }

    func selectConversationPracticeTopic(_ topic: ConversationPracticeTopic) {
        conversationPracticeImportMessage = nil
        conversationPracticeImportError = nil
        isConversationPracticeExpanded = false
        selectedConversationPracticeItemID = nil
        store.selectedConversationPracticeTopicID = topic.id
        store.persistPromptSettings()
        loadConversationPracticeLibrary()
    }

    func loadImportedConversationPracticePacks() {
        let packs = RadixStudyPreferences.importedConversationPracticePacks
        importedConversationPracticeLibraries = Dictionary(
            uniqueKeysWithValues: packs.map { ($0.packID, $0.practiceLibrary) }
        )
        let importedTopics = packs.map { conversationPracticeTopic(for: $0.practiceLibrary) }
        conversationPracticeTopics = ConversationPracticeTopic.defaults + importedTopics.filter { importedTopic in
            !ConversationPracticeTopic.defaults.contains { $0.id == importedTopic.id }
        }
        if !conversationPracticeTopics.contains(where: { $0.id == store.selectedConversationPracticeTopicID }) {
            store.selectedConversationPracticeTopicID = ConversationPracticeTopic.generalGreetings.id
        }
    }

    func importConversationPracticePack(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            let pack = try conversationPracticeService.loadPack(
                from: data,
                sourceName: url.deletingPathExtension().lastPathComponent
            )
            saveImportedConversationPracticePack(pack)
            loadImportedConversationPracticePacks()
            if let topic = conversationPracticeTopics.first(where: { $0.id == pack.packID }) {
                selectConversationPracticeTopic(topic)
            }
            conversationPracticeImportMessage = "Loaded \(pack.title) · \(pack.entries.count) sentences"
            conversationPracticeImportError = nil
        } catch {
            conversationPracticeImportMessage = nil
            conversationPracticeImportError = error.localizedDescription
        }
    }

    func saveImportedConversationPracticePack(_ pack: ConversationPracticePack) {
        var packs = RadixStudyPreferences.importedConversationPracticePacks
        packs.removeAll { $0.packID == pack.packID }
        packs.append(pack)
        RadixStudyPreferences.importedConversationPracticePacks = packs
    }

    var selectedConversationPracticeTopic: ConversationPracticeTopic {
        conversationPracticeTopics.first { $0.id == store.selectedConversationPracticeTopicID }
            ?? .generalGreetings
    }

    func conversationPracticeTopic(for library: ConversationPracticeLibrary) -> ConversationPracticeTopic {
        ConversationPracticeTopic(
            id: library.set.id,
            title: library.set.title,
            summary: library.set.description,
            difficultyLabel: "Imported practice set",
            bundledResourceName: nil,
            generationBrief: library.set.description,
            situations: [],
            targetSentenceCount: library.set.itemCount
        )
    }

    func isImportedConversationPracticeTopic(_ topic: ConversationPracticeTopic) -> Bool {
        importedConversationPracticeLibraries[topic.id] != nil
    }

    func deleteConversationPracticeTopic(_ topic: ConversationPracticeTopic) {
        guard isImportedConversationPracticeTopic(topic) else { return }

        var packs = RadixStudyPreferences.importedConversationPracticePacks
        packs.removeAll { $0.packID == topic.id }
        RadixStudyPreferences.importedConversationPracticePacks = packs
        loadImportedConversationPracticePacks()

        if store.selectedConversationPracticeTopicID == topic.id {
            selectConversationPracticeTopic(.generalGreetings)
        } else {
            loadConversationPracticeLibrary()
        }

        conversationPracticeImportMessage = "Deleted \(topic.title)"
        conversationPracticeImportError = nil
    }

    func generateConversationPracticeTopic(_ topic: ConversationPracticeTopic) {
        store.goToAILinkPracticeGenerator(topic: topic)
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

enum StudyMode: String, CaseIterable, Identifiable {
    case review = "Review"
    case practice = "Practice"

    var id: String { rawValue }

    var title: String { rawValue }
}
