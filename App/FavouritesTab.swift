import SwiftUI

struct StudyOCRPromotion: Identifiable {
    let original: CharacterCollection
    let corrected: CharacterCollection

    var id: UUID { corrected.id }
}

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
    @State var isShowingConversationPractice = false
    @State var studyGridUsesTraditionalScript = RadixStudyPreferences.usesTraditionalScript
    @State var studyGridScope = RadixStudyPreferences.gridScope
    @State var studyPageSortOrder = RadixStudyPreferences.pageSortOrder
    @State var hasDismissedStudyIntro = RadixStudyPreferences.hasDismissedIntro
    @State var addedPhraseReviewPresentation: AddedPhraseReviewPresentation?
    @State var pendingCheckpointReturn: LocalDataSnapshot?
    @State var conversationPracticeTopics = ConversationPracticeTopic.defaults
    @State var conversationPracticeLibrary: ConversationPracticeLibrary? = try? ConversationPracticeService().loadLibrary(for: .generalGreetings)
    @State var importedConversationPracticeLibraries: [String: ConversationPracticeLibrary] = [:]
    @State var favoriteSentenceRecords = RadixStudyPreferences.favoriteSentences
    @State var showConversationPracticeImporter = false
    @State var showConversationPracticePasteImporter = false
    @State var conversationPracticeImportMessage: String?
    @State var conversationPracticeImportError: String?
    @State var pendingConversationPracticeDeletion: ConversationPracticeTopic?
    @State var pendingConversationPracticeReplacement: ConversationPracticeReplacementReview?
    @State var conversationPracticeSentenceDisplay: ConversationPracticeSentenceDisplay = .chinese
    @State var conversationPracticePageIndex = 0
    @State var selectedConversationPracticeItemID: String?
    @State var conversationPracticeProgress = RadixStudyPreferences.conversationPracticeProgress
    @State var conversationPracticeReviewPresentation: ConversationPracticeReviewPresentation?
    @State var conversationPracticeQuizPresentation: ConversationPracticeQuizPresentation?
    @State var conversationPracticeTranslationQuizPresentation: ConversationPracticeTranslationQuizPresentation?
    @State var studyTranslationReportCollection: CharacterCollection?
    @State var studyTranslationReportDraft = ""
    @State var studyPageQuizCollection: CharacterCollection?
    @State var studyPageQuizQuestions: [PageQuizQuestion] = []
    @State var studyPageQuizMessage: String?
    @State var isGeneratingStudyPageQuiz = false
    @State var pendingStudyDeleteCollection: CharacterCollection?
    @State var pendingStudyOCRPromotion: StudyOCRPromotion?
    @State var studyPageActionMessage: String?
    @State var studyPageActionMessageCollectionID: UUID?
    @State var studyAIFallbackTask: BrowseAIFallbackTask?
    @State var studyAutomaticAIError = ""
    @State var isRunningStudyPageAction = false

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
            || !favoriteSentenceRecords.isEmpty
            || !conversationPracticeTopics.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !isShowingConversationPractice {
                favouritesHeader
            }

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
            refreshConversationPracticeProgress()
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
            refreshConversationPracticeProgress()
        }) { presentation in
            ConversationPracticeQuizSheet(
                library: presentation.library,
                usesTraditionalScript: $studyGridUsesTraditionalScript
            )
            .environmentObject(store)
            .environmentObject(entitlement)
        }
        .sheet(item: $conversationPracticeTranslationQuizPresentation, onDismiss: {
            conversationPracticeTranslationQuizPresentation = nil
            refreshConversationPracticeProgress()
        }) { presentation in
            ConversationPracticeTranslationQuizSheet(
                library: presentation.library,
                usesTraditionalScript: $studyGridUsesTraditionalScript
            )
            .environmentObject(store)
            .environmentObject(entitlement)
        }
        .sheet(item: $studyTranslationReportCollection) { collection in
            BrowseTranslationReportSheet(
                collectionName: collection.name,
                report: $studyTranslationReportDraft,
                updatedAt: collection.translationReportUpdatedAt,
                onPaste: pasteStudyTranslationReport,
                onSave: { saveStudyTranslationReport(collection) },
                onClear: { clearStudyTranslationReport(collection) },
                onDone: { studyTranslationReportCollection = nil }
            )
        }
        .sheet(item: $studyPageQuizCollection) { collection in
            BrowsePageQuizSheet(
                collectionName: collection.name,
                questions: studyPageQuizQuestions,
                message: studyPageQuizMessage,
                isGenerating: isGeneratingStudyPageQuiz,
                canSetUpGeminiKey: store.geminiAPIKey
                    .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                onUseLocalFallback: { useLocalStudyPageQuizFallback(collection) },
                onSetUpGeminiKey: {
                    studyPageQuizCollection = nil
                    DispatchQueue.main.async {
                        store.goToSettingsForAPIKeySetup()
                    }
                },
                onDone: { studyPageQuizCollection = nil }
            )
        }
        .sheet(isPresented: $showConversationPracticePasteImporter) {
            ConversationPracticePasteImportSheet { pack in
                importPastedConversationPracticePack(pack)
            }
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
        .alert("Replace Practice?", isPresented: Binding(
            get: { pendingConversationPracticeReplacement != nil },
            set: { if !$0 { pendingConversationPracticeReplacement = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                pendingConversationPracticeReplacement = nil
            }
            Button("Replace Practice", role: .destructive) {
                guard let review = pendingConversationPracticeReplacement else { return }
                pendingConversationPracticeReplacement = nil
                finishImportingConversationPracticePack(review.pack, replacing: true)
            }
        } message: {
            Text(pendingConversationPracticeReplacement?.message ?? "")
        }
        .alert("Delete Saved Page?", isPresented: Binding(
            get: { pendingStudyDeleteCollection != nil },
            set: { if !$0 { pendingStudyDeleteCollection = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let collection = pendingStudyDeleteCollection {
                    store.deleteCollection(id: collection.id)
                }
                pendingStudyDeleteCollection = nil
            }
            Button("Cancel", role: .cancel) {
                pendingStudyDeleteCollection = nil
            }
        } message: {
            if let collection = pendingStudyDeleteCollection {
                Text(store.deletionImpact(for: collection).alertMessage)
            }
        }
        .alert("Promote Corrected OCR?", isPresented: Binding(
            get: { pendingStudyOCRPromotion != nil },
            set: { if !$0 { pendingStudyOCRPromotion = nil } }
        )) {
            Button("Promote, Keep Original") {
                promotePendingOCRCorrection(keepOriginal: true)
            }
            Button("Promote, Delete Original", role: .destructive) {
                promotePendingOCRCorrection(keepOriginal: false)
            }
            Button("Cancel", role: .cancel) {
                pendingStudyOCRPromotion = nil
            }
        } message: {
            if let promotion = pendingStudyOCRPromotion {
                Text("Use \"\(promotion.corrected.name)\" as the main page for \"\(promotion.original.name)\". Existing page-linked practice, translation, favorites, and progress stay with the main page.")
            }
        }
        .alert(item: $studyAIFallbackTask) { task in
            Alert(
                title: Text("Automatic AI Is Unavailable"),
                message: Text("\(studyAutomaticAIError)\n\nYour API key may still be valid. Gemini can occasionally be unavailable, so the copy-and-paste method remains available."),
                primaryButton: .default(Text("Use Another AI App")) {
                    useManualStudyAIFallback(task)
                },
                secondaryButton: .cancel(Text("Not Now"))
            )
        }
        .onAppear {
            studyGridUsesTraditionalScript = RadixStudyPreferences.usesTraditionalScript
            studyGridScope = RadixStudyPreferences.gridScope
            studyPageSortOrder = RadixStudyPreferences.pageSortOrder
            hasDismissedStudyIntro = RadixStudyPreferences.hasDismissedIntro
            openAddedPhraseReviewIfRequested()
            loadImportedConversationPracticePacks()
            loadFavoriteSentences()
            loadConversationPracticeLibrary()
            openPendingConversationPracticeIfNeeded()
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
        .onChange(of: store.pendingConversationPracticeTopicID) { _, _ in
            openPendingConversationPracticeIfNeeded()
        }
        .onChange(of: store.dataImportRevision) { _, _ in
            loadImportedConversationPracticePacks()
            loadFavoriteSentences()
            loadConversationPracticeLibrary()
        }
        .onChange(of: store.favoriteSentenceRevision) { _, _ in
            loadFavoriteSentences()
            loadConversationPracticeLibrary()
        }
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
            isShowingConversationPractice = true
        }
        store.pendingConversationPracticeTopicID = nil
    }

    func loadConversationPracticeLibrary() {
        refreshConversationPracticeProgress()
        migratePhraseFavoritesToFavoriteSentences()
        let topic = selectedConversationPracticeTopic
        if topic.id == ConversationPracticeTopic.favoriteSentencesID {
            conversationPracticeLibrary = ConversationPracticeLibrary.favoriteSentencesLibrary(from: favoriteSentenceRecords)
        } else if let importedLibrary = importedConversationPracticeLibraries[topic.id] {
            conversationPracticeLibrary = importedLibrary
        } else {
            conversationPracticeLibrary = try? conversationPracticeService.loadLibrary(for: topic)
        }
        if let conversationPracticeLibrary {
            store.registerConversationPracticeLibrary(conversationPracticeLibrary)
            conversationPracticePageIndex = conversationPracticeClampedPageIndex(for: conversationPracticeLibrary)
            if let selectedConversationPracticeItemID,
               !conversationPracticeLibrary.items.contains(where: { $0.id == selectedConversationPracticeItemID }) {
                self.selectedConversationPracticeItemID = nil
            }
        } else {
            conversationPracticePageIndex = 0
        }
    }

    func selectConversationPracticeTopic(_ topic: ConversationPracticeTopic) {
        conversationPracticeImportMessage = nil
        conversationPracticeImportError = nil
        selectedConversationPracticeItemID = nil
        conversationPracticePageIndex = 0
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
        favoriteSentenceRecords = RadixStudyPreferences.favoriteSentences
        conversationPracticeTopics = conversationPracticeBaseTopics(importedTopics: importedTopics)
        if !conversationPracticeTopics.contains(where: { $0.id == store.selectedConversationPracticeTopicID }) {
            store.selectedConversationPracticeTopicID = ConversationPracticeTopic.generalGreetings.id
        }
    }

    func conversationPracticeBaseTopics(importedTopics: [ConversationPracticeTopic]) -> [ConversationPracticeTopic] {
        var topics = ConversationPracticeTopic.defaults + importedTopics.filter { importedTopic in
            !ConversationPracticeTopic.defaults.contains { $0.id == importedTopic.id }
        }
        if !favoriteSentenceRecords.isEmpty {
            topics.append(.favoriteSentences(count: favoriteSentenceRecords.count))
        }
        return topics
    }

    func loadFavoriteSentences() {
        migratePhraseFavoritesToFavoriteSentences()
        favoriteSentenceRecords = RadixStudyPreferences.favoriteSentences
        let importedTopics = RadixStudyPreferences.importedConversationPracticePacks.map {
            conversationPracticeTopic(for: $0.practiceLibrary)
        }
        conversationPracticeTopics = conversationPracticeBaseTopics(importedTopics: importedTopics)
        if store.selectedConversationPracticeTopicID == ConversationPracticeTopic.favoriteSentencesID,
           favoriteSentenceRecords.isEmpty {
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
            reviewOrFinishImportingConversationPracticePack(pack)
        } catch {
            conversationPracticeImportMessage = nil
            conversationPracticeImportError = error.localizedDescription
        }
    }

    func importPastedConversationPracticePack(_ pack: ConversationPracticePack) {
        reviewOrFinishImportingConversationPracticePack(pack)
    }

    func reviewOrFinishImportingConversationPracticePack(_ pack: ConversationPracticePack) {
        let existingPack = RadixStudyPreferences.importedConversationPracticePacks
            .first { $0.packID == pack.packID }
        let bundledTopic = ConversationPracticeTopic.defaults.first { $0.id == pack.packID }

        guard existingPack != nil || bundledTopic != nil else {
            finishImportingConversationPracticePack(pack, replacing: false)
            return
        }

        let validation = ConversationPracticeRules.validate(pack)
        pendingConversationPracticeReplacement = ConversationPracticeReplacementReview(
            pack: pack,
            existingTitle: existingPack?.title ?? bundledTopic?.title ?? pack.title,
            existingSentenceCount: existingPack?.entries.count ?? bundledTopic?.targetSentenceCount ?? 0,
            replacementSentenceCount: pack.entries.count,
            warningCount: validation.warnings.count,
            replacesBundledTopic: existingPack == nil && bundledTopic != nil
        )
        conversationPracticeImportMessage = nil
        conversationPracticeImportError = nil
    }

    func finishImportingConversationPracticePack(
        _ pack: ConversationPracticePack,
        replacing: Bool
    ) {
        saveImportedConversationPracticePack(pack)
        loadImportedConversationPracticePacks()
        if let topic = conversationPracticeTopics.first(where: { $0.id == pack.packID }) {
            selectConversationPracticeTopic(topic)
        }
        conversationPracticeImportMessage = "\(replacing ? "Replaced" : "Loaded") \(pack.title) · \(pack.entries.count) sentences"
        conversationPracticeImportError = nil
    }

    func saveImportedConversationPracticePack(_ pack: ConversationPracticePack) {
        store.saveImportedConversationPracticePack(pack)
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
        refreshConversationPracticeProgress()
        conversationPracticeReviewPresentation = ConversationPracticeReviewPresentation(library: library)
    }

    func presentConversationPracticeQuiz(_ library: ConversationPracticeLibrary) {
        refreshConversationPracticeProgress()
        conversationPracticeQuizPresentation = ConversationPracticeQuizPresentation(library: library)
    }

    func presentConversationPracticeTranslationQuiz(_ library: ConversationPracticeLibrary) {
        refreshConversationPracticeProgress()
        conversationPracticeTranslationQuizPresentation = ConversationPracticeTranslationQuizPresentation(library: library)
    }

    func refreshConversationPracticeProgress() {
        conversationPracticeProgress = RadixStudyPreferences.conversationPracticeProgress
    }

    func isFavoriteSentence(_ item: ConversationPracticeItem) -> Bool {
        store.isFavoriteSentence(item)
    }

    func toggleFavoriteSentence(_ item: ConversationPracticeItem) {
        store.toggleFavoriteSentence(item)
        loadFavoriteSentences()
        if let library = ConversationPracticeLibrary.favoriteSentencesLibrary(from: favoriteSentenceRecords) {
            store.registerConversationPracticeLibrary(library)
        }
        loadConversationPracticeLibrary()
    }

    func migratePhraseFavoritesToFavoriteSentences() {
        let existingIDs = Set(RadixStudyPreferences.favoriteSentences.map(\.id))
        var migratedRecords: [FavoriteSentenceRecord] = []
        for library in availableConversationPracticeLibrariesForMigration() {
            for item in library.items {
                guard store.isPhraseFavorite(item.phraseKey),
                      !existingIDs.contains(FavoriteSentenceRecord.identifier(for: item))
                else { continue }
                migratedRecords.append(FavoriteSentenceRecord(item: item))
            }
        }
        guard !migratedRecords.isEmpty else { return }
        RadixStudyPreferences.favoriteSentences = RadixStudyPreferences.favoriteSentences + migratedRecords
    }

    func availableConversationPracticeLibrariesForMigration() -> [ConversationPracticeLibrary] {
        let imported = Array(importedConversationPracticeLibraries.values)
        let bundled = ConversationPracticeTopic.defaults.compactMap {
            try? conversationPracticeService.loadLibrary(for: $0)
        }
        return bundled + imported
    }

    var isPhoneStudyPreviewActive: Bool {
        isPhone && (store.previewCharacter != nil || store.activeSidebarPhrasePreview != nil)
    }

    var phoneStudyPreview: some View {
        PhoneContextPreview(
            phrase: store.activeSidebarPhrasePreview,
            character: store.previewCharacter,
            listReturnTitle: store.sidebarPhraseLookupOverride == nil ? nil : selectedConversationPracticeTopic.title,
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
    case savedPages = "Saved Pages"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "Recent"
        case .favorites: return "Favorite"
        case .savedPages: return "Saved Pages"
        }
    }

    var emptyMessage: String {
        switch self {
        case .all: return "No recent study items yet."
        case .favorites: return "No favorite study items yet."
        case .savedPages: return "No saved pages yet."
        }
    }

    var legendText: String {
        switch self {
        case .all: return "Tap an item to preview it. Favorite the useful ones, then clear Recent."
        case .favorites: return "Tap a favorite character or phrase to preview it. Use the star to remove it from Favorites."
        case .savedPages: return "Saved pages gather the Practice, translation, quiz, and corrected-page work that came from that page."
        }
    }
}

enum ConversationPracticeSentenceDisplay: String, CaseIterable, Identifiable {
    case chinese = "Chinese"
    case english = "English"

    var id: String { rawValue }
}

struct ConversationPracticeReplacementReview: Identifiable {
    let id = UUID()
    let pack: ConversationPracticePack
    let existingTitle: String
    let existingSentenceCount: Int
    let replacementSentenceCount: Int
    let warningCount: Int
    let replacesBundledTopic: Bool

    var message: String {
        var lines = [
            "\(existingTitle) already exists.",
            "Current: \(existingSentenceCount) sentences",
            "New file: \(replacementSentenceCount) sentences"
        ]
        if warningCount > 0 {
            lines.append("\(warningCount) validation warning\(warningCount == 1 ? "" : "s")")
        }
        if replacesBundledTopic {
            lines.append("The built-in topic stays recoverable if you delete this imported replacement later.")
        }
        return lines.joined(separator: "\n")
    }
}
