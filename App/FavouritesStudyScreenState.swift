import SwiftUI

struct StudyNavigationScreenState {
    var selectedPhrase: PhraseItem?
    var focusedSection: FocusedStudySection?
    var usesTraditionalScript = RadixStudyPreferences.usesTraditionalScript
    var reviewScope = RadixStudyPreferences.initialGridScope
    var pageSortOrder = RadixStudyPreferences.pageSortOrder
    var showsCheckpoints = false
    var pendingCheckpointReturn: LocalDataSnapshot?
    var expandedSavedPageID: UUID?
    var pageReturnCollectionID: UUID?
}

struct StudySentenceScreenState {
    var filter: SentenceExampleStudyFilter = .all
    var searchText = ""
    var minimumCharacterCount = 2.0
    var pageIndex = 0
    var pageRecords: [SentenceExampleRecord] = []
    var resultCount = 0
    var isSelecting = false
    var selectedIDs = Set<UUID>()
    var revision = 0
    var statusMessage: String?
    var editDraft: SentenceExampleEditDraft?
    var pendingDeletion: PendingSentenceExampleDeletion?
    var showsDeleteFilteredConfirmation = false
    var showsDeleteSelectedConfirmation = false
    var exportDocument = BinaryFileDocument(data: Data())
    var exportFilename = "radix_sentence_database"
    var showsExporter = false
    var showsImporter = false
    var pendingImport: PendingSentenceDatabaseImport?
    var isRunningTransfer = false
    var showsClearConfirmation = false
}

struct StudyConversationPracticeScreenState {
    var topics = ConversationPracticeTopic.defaults
    var library: ConversationPracticeLibrary? = try? ConversationPracticeService().loadLibrary(for: .generalGreetings)
    var importedLibraries: [String: ConversationPracticeLibrary] = [:]
    var favoriteSentenceRecords = RadixStudyPreferences.favoriteSentences
    var showsImporter = false
    var showsPasteImporter = false
    var importMessage: String?
    var importError: String?
    var pendingDeletion: ConversationPracticeTopic?
    var pendingReplacement: ConversationPracticeReplacementReview?
    var sentenceDisplay: ConversationPracticeSentenceDisplay = .chinese
    var pageIndex = 0
    var selectedItemID: String?
    var progress = RadixStudyPreferences.conversationPracticeProgress
    var reviewPresentation: ConversationPracticeReviewPresentation?
    var quizPresentation: ConversationPracticeQuizPresentation?
}

struct StudyPageScreenState {
    var aiCleanedCollectionID: UUID?
    var aiCleanedSentencePageIndex = 0
    var aiCleanedSentencePageCache: StudyAICleanedSentencePageCache?
    var translationReportCollection: CharacterCollection?
    var translationReportDraft = ""
    var pendingDeleteCollection: CharacterCollection?
    var pendingOCRPromotion: StudyOCRPromotion?
    var actionMessage: String?
    var actionMessageCollectionID: UUID?
    var aiFallbackTask: BrowseAIFallbackTask?
    var automaticAIError = ""
    var isRunningAction = false
    var phrasesPresentation: StudyPagePhrasesPresentation?
}

struct StudyScreenState {
    var navigation = StudyNavigationScreenState()
    var sentences = StudySentenceScreenState()
    var conversationPractice = StudyConversationPracticeScreenState()
    var pages = StudyPageScreenState()

    var activeSectionTitle: String {
        if navigation.showsCheckpoints { return "Checkpoints" }
        if let focusedSection = navigation.focusedSection { return focusedSection.title }
        return navigation.reviewScope.title
    }

    mutating func presentFocusedSection(_ section: FocusedStudySection) {
        navigation.focusedSection = section
        pages.aiCleanedCollectionID = nil
    }

    mutating func presentReview(
        scope: StudyGridScope,
        expandedSavedPageID: UUID? = nil
    ) {
        clearFocusedSections()
        navigation.reviewScope = scope
        navigation.showsCheckpoints = false
        if scope == .savedPages, let expandedSavedPageID {
            navigation.expandedSavedPageID = expandedSavedPageID
        }
    }

    mutating func presentCheckpoints() {
        clearFocusedSections()
        navigation.showsCheckpoints = true
    }

    mutating func clearFocusedSections() {
        navigation.focusedSection = nil
        navigation.pageReturnCollectionID = nil
    }

    mutating func openAICleanedPage(collectionID: UUID) {
        navigation.focusedSection = nil
        pages.aiCleanedSentencePageIndex = 0
        pages.aiCleanedSentencePageCache = nil
        pages.aiCleanedCollectionID = collectionID
    }

    mutating func openConversationPractice(fromPageID pageID: UUID) {
        navigation.pageReturnCollectionID = pageID
        presentFocusedSection(.conversationPractice)
    }

    mutating func returnToOriginatingPage() -> UUID? {
        guard let pageID = navigation.pageReturnCollectionID else { return nil }
        navigation.pageReturnCollectionID = nil
        navigation.focusedSection = nil
        pages.aiCleanedCollectionID = nil
        navigation.reviewScope = .savedPages
        navigation.expandedSavedPageID = pageID
        return pageID
    }
}

extension FavouritesTab {
    var selectedPhrase: PhraseItem? {
        get { screenState.navigation.selectedPhrase }
        nonmutating set { screenState.navigation.selectedPhrase = newValue }
    }

    var focusedStudySection: FocusedStudySection? {
        get { screenState.navigation.focusedSection }
        nonmutating set { screenState.navigation.focusedSection = newValue }
    }

    var studyGridUsesTraditionalScript: Bool {
        get { screenState.navigation.usesTraditionalScript }
        nonmutating set { screenState.navigation.usesTraditionalScript = newValue }
    }

    var studyGridScope: StudyGridScope {
        get { screenState.navigation.reviewScope }
        nonmutating set { screenState.navigation.reviewScope = newValue }
    }

    var studyPageSortOrder: PageCollectionSortOrder {
        get { screenState.navigation.pageSortOrder }
        nonmutating set { screenState.navigation.pageSortOrder = newValue }
    }

    var showStudyCheckpoints: Bool {
        get { screenState.navigation.showsCheckpoints }
        nonmutating set { screenState.navigation.showsCheckpoints = newValue }
    }

    var pendingCheckpointReturn: LocalDataSnapshot? {
        get { screenState.navigation.pendingCheckpointReturn }
        nonmutating set { screenState.navigation.pendingCheckpointReturn = newValue }
    }

    var expandedStudySavedPageID: UUID? {
        get { screenState.navigation.expandedSavedPageID }
        nonmutating set { screenState.navigation.expandedSavedPageID = newValue }
    }

    var studyPageReturnCollectionID: UUID? {
        get { screenState.navigation.pageReturnCollectionID }
        nonmutating set { screenState.navigation.pageReturnCollectionID = newValue }
    }

    var studyAICleanedPageCollectionID: UUID? {
        get { screenState.pages.aiCleanedCollectionID }
        nonmutating set { screenState.pages.aiCleanedCollectionID = newValue }
    }

    var aiCleanedPageSentencePageIndex: Int {
        get { screenState.pages.aiCleanedSentencePageIndex }
        nonmutating set { screenState.pages.aiCleanedSentencePageIndex = newValue }
    }

    var aiCleanedPageSentencePageCache: StudyAICleanedSentencePageCache? {
        get { screenState.pages.aiCleanedSentencePageCache }
        nonmutating set { screenState.pages.aiCleanedSentencePageCache = newValue }
    }

    var sentenceExampleFilter: SentenceExampleStudyFilter {
        get { screenState.sentences.filter }
        nonmutating set { screenState.sentences.filter = newValue }
    }

    var sentenceExampleSearchText: String {
        get { screenState.sentences.searchText }
        nonmutating set { screenState.sentences.searchText = newValue }
    }

    var sentenceExampleMinimumCharacterCount: Double {
        get { screenState.sentences.minimumCharacterCount }
        nonmutating set { screenState.sentences.minimumCharacterCount = newValue }
    }

    var sentenceExamplePageIndex: Int {
        get { screenState.sentences.pageIndex }
        nonmutating set { screenState.sentences.pageIndex = newValue }
    }

    var sentenceExamplePageRecords: [SentenceExampleRecord] {
        get { screenState.sentences.pageRecords }
        nonmutating set { screenState.sentences.pageRecords = newValue }
    }

    var sentenceExampleResultCount: Int {
        get { screenState.sentences.resultCount }
        nonmutating set { screenState.sentences.resultCount = newValue }
    }

    var isSelectingSentenceExamples: Bool {
        get { screenState.sentences.isSelecting }
        nonmutating set { screenState.sentences.isSelecting = newValue }
    }

    var selectedSentenceExampleIDs: Set<UUID> {
        get { screenState.sentences.selectedIDs }
        nonmutating set { screenState.sentences.selectedIDs = newValue }
    }

    var sentenceExampleRevision: Int {
        get { screenState.sentences.revision }
        nonmutating set { screenState.sentences.revision = newValue }
    }

    var sentenceExampleStatusMessage: String? {
        get { screenState.sentences.statusMessage }
        nonmutating set { screenState.sentences.statusMessage = newValue }
    }

    var sentenceExampleEditDraft: SentenceExampleEditDraft? {
        get { screenState.sentences.editDraft }
        nonmutating set { screenState.sentences.editDraft = newValue }
    }

    var pendingSentenceExampleDeletion: PendingSentenceExampleDeletion? {
        get { screenState.sentences.pendingDeletion }
        nonmutating set { screenState.sentences.pendingDeletion = newValue }
    }

    var showDeleteFilteredSentenceExamplesConfirmation: Bool {
        get { screenState.sentences.showsDeleteFilteredConfirmation }
        nonmutating set { screenState.sentences.showsDeleteFilteredConfirmation = newValue }
    }

    var showDeleteSelectedSentenceExamplesConfirmation: Bool {
        get { screenState.sentences.showsDeleteSelectedConfirmation }
        nonmutating set { screenState.sentences.showsDeleteSelectedConfirmation = newValue }
    }

    var sentenceDatabaseExportDocument: BinaryFileDocument {
        get { screenState.sentences.exportDocument }
        nonmutating set { screenState.sentences.exportDocument = newValue }
    }

    var sentenceDatabaseExportFilename: String {
        get { screenState.sentences.exportFilename }
        nonmutating set { screenState.sentences.exportFilename = newValue }
    }

    var showSentenceDatabaseExporter: Bool {
        get { screenState.sentences.showsExporter }
        nonmutating set { screenState.sentences.showsExporter = newValue }
    }

    var showSentenceDatabaseImporter: Bool {
        get { screenState.sentences.showsImporter }
        nonmutating set { screenState.sentences.showsImporter = newValue }
    }

    var pendingSentenceDatabaseImport: PendingSentenceDatabaseImport? {
        get { screenState.sentences.pendingImport }
        nonmutating set { screenState.sentences.pendingImport = newValue }
    }

    var isRunningSentenceDatabaseTransfer: Bool {
        get { screenState.sentences.isRunningTransfer }
        nonmutating set { screenState.sentences.isRunningTransfer = newValue }
    }

    var showClearSentenceDatabaseConfirmation: Bool {
        get { screenState.sentences.showsClearConfirmation }
        nonmutating set { screenState.sentences.showsClearConfirmation = newValue }
    }

    var conversationPracticeTopics: [ConversationPracticeTopic] {
        get { screenState.conversationPractice.topics }
        nonmutating set { screenState.conversationPractice.topics = newValue }
    }

    var conversationPracticeLibrary: ConversationPracticeLibrary? {
        get { screenState.conversationPractice.library }
        nonmutating set { screenState.conversationPractice.library = newValue }
    }

    var importedConversationPracticeLibraries: [String: ConversationPracticeLibrary] {
        get { screenState.conversationPractice.importedLibraries }
        nonmutating set { screenState.conversationPractice.importedLibraries = newValue }
    }

    var favoriteSentenceRecords: [FavoriteSentenceRecord] {
        get { screenState.conversationPractice.favoriteSentenceRecords }
        nonmutating set { screenState.conversationPractice.favoriteSentenceRecords = newValue }
    }

    var showConversationPracticeImporter: Bool {
        get { screenState.conversationPractice.showsImporter }
        nonmutating set { screenState.conversationPractice.showsImporter = newValue }
    }

    var showConversationPracticePasteImporter: Bool {
        get { screenState.conversationPractice.showsPasteImporter }
        nonmutating set { screenState.conversationPractice.showsPasteImporter = newValue }
    }

    var conversationPracticeImportMessage: String? {
        get { screenState.conversationPractice.importMessage }
        nonmutating set { screenState.conversationPractice.importMessage = newValue }
    }

    var conversationPracticeImportError: String? {
        get { screenState.conversationPractice.importError }
        nonmutating set { screenState.conversationPractice.importError = newValue }
    }

    var pendingConversationPracticeDeletion: ConversationPracticeTopic? {
        get { screenState.conversationPractice.pendingDeletion }
        nonmutating set { screenState.conversationPractice.pendingDeletion = newValue }
    }

    var pendingConversationPracticeReplacement: ConversationPracticeReplacementReview? {
        get { screenState.conversationPractice.pendingReplacement }
        nonmutating set { screenState.conversationPractice.pendingReplacement = newValue }
    }

    var conversationPracticeSentenceDisplay: ConversationPracticeSentenceDisplay {
        get { screenState.conversationPractice.sentenceDisplay }
        nonmutating set { screenState.conversationPractice.sentenceDisplay = newValue }
    }

    var conversationPracticePageIndex: Int {
        get { screenState.conversationPractice.pageIndex }
        nonmutating set { screenState.conversationPractice.pageIndex = newValue }
    }

    var selectedConversationPracticeItemID: String? {
        get { screenState.conversationPractice.selectedItemID }
        nonmutating set { screenState.conversationPractice.selectedItemID = newValue }
    }

    var conversationPracticeProgress: ConversationPracticeProgressSnapshot {
        get { screenState.conversationPractice.progress }
        nonmutating set { screenState.conversationPractice.progress = newValue }
    }

    var conversationPracticeReviewPresentation: ConversationPracticeReviewPresentation? {
        get { screenState.conversationPractice.reviewPresentation }
        nonmutating set { screenState.conversationPractice.reviewPresentation = newValue }
    }

    var conversationPracticeQuizPresentation: ConversationPracticeQuizPresentation? {
        get { screenState.conversationPractice.quizPresentation }
        nonmutating set { screenState.conversationPractice.quizPresentation = newValue }
    }

    var studyTranslationReportCollection: CharacterCollection? {
        get { screenState.pages.translationReportCollection }
        nonmutating set { screenState.pages.translationReportCollection = newValue }
    }

    var studyTranslationReportDraft: String {
        get { screenState.pages.translationReportDraft }
        nonmutating set { screenState.pages.translationReportDraft = newValue }
    }

    var pendingStudyDeleteCollection: CharacterCollection? {
        get { screenState.pages.pendingDeleteCollection }
        nonmutating set { screenState.pages.pendingDeleteCollection = newValue }
    }

    var pendingStudyOCRPromotion: StudyOCRPromotion? {
        get { screenState.pages.pendingOCRPromotion }
        nonmutating set { screenState.pages.pendingOCRPromotion = newValue }
    }

    var studyPageActionMessage: String? {
        get { screenState.pages.actionMessage }
        nonmutating set { screenState.pages.actionMessage = newValue }
    }

    var studyPageActionMessageCollectionID: UUID? {
        get { screenState.pages.actionMessageCollectionID }
        nonmutating set { screenState.pages.actionMessageCollectionID = newValue }
    }

    var studyAIFallbackTask: BrowseAIFallbackTask? {
        get { screenState.pages.aiFallbackTask }
        nonmutating set { screenState.pages.aiFallbackTask = newValue }
    }

    var studyAutomaticAIError: String {
        get { screenState.pages.automaticAIError }
        nonmutating set { screenState.pages.automaticAIError = newValue }
    }

    var isRunningStudyPageAction: Bool {
        get { screenState.pages.isRunningAction }
        nonmutating set { screenState.pages.isRunningAction = newValue }
    }

    var studyPagePhrasesPresentation: StudyPagePhrasesPresentation? {
        get { screenState.pages.phrasesPresentation }
        nonmutating set { screenState.pages.phrasesPresentation = newValue }
    }
}
