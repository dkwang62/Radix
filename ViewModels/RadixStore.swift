import Foundation
import SwiftUI
import Combine

/*
 CHARACTER STUDIO ARCHITECTURE (RadixStore)
 =========================================
 RadixStore acts as the central state engine for the application. It manages the
 "Single Source of Truth" for search, navigation, and the Character Studio.
 
 THE VIRTUAL FILE CONCEPT:
 This store unifies three distinct data backends into a single cohesive experience:
 1. Dictionary (JSON): Foundational character data (radical, strokes, etymology).
 2. Phrases (SQLite): High-performance multi-character word database.
 3. User Data (Settings): Personal favorites and AI Prompt configurations.
 
 Persistence is handled automatically via a "Live Auto-Save" mechanism that
 routes changes to the correct backend file as they happen.
*/

struct RootsReturnContext: Equatable {
    let route: AppRoute
    let homeTab: HomeTab?
}

enum ImagePhraseHighlightRole {
    case target
    case phraseMember
}

enum QuickEditDestination: Identifiable, Equatable {
    case character(String)
    case phrase(String)
    case newCharacter
    case newPhrase(String = "")

    var id: String {
        switch self {
        case .character(let character):
            return "character:\(character)"
        case .phrase(let phrase):
            return "phrase:\(phrase)"
        case .newCharacter:
            return "newCharacter"
        case .newPhrase(let phrase):
            return phrase.isEmpty ? "newPhrase" : "newPhrase:\(phrase)"
        }
    }
}

@MainActor
final class RadixStore: ObservableObject {
    let preferences: any RadixPreferenceStore

    init(preferences: any RadixPreferenceStore = RadixPreferences.standard) {
        self.preferences = preferences
    }

    // MARK: - Navigation State
    @Published var navigationState = RadixNavigationState()
    @Published var presentationState = RadixPresentationState()
    
    // MARK: - Search State
    @Published var searchState = RadixSearchState()
    
    // MARK: - DataEdit (Character Studio) State
    @Published var dataEditFormState = RadixDataEditFormState()
    @Published var dataImportRevision = 0

    var dataEditLoadTask: Task<Void, Never>?
    /// Cache to avoid reloading heavy entries when toggling between AI/Data.
    var dataEditCache: [String: (entry: RawComponentEntry, phrases: [PhraseItem], isFav: Bool)] = [:]
    var dataEditEtymologyType: String?

    // MARK: - Browsing & Filter State
    @Published var browseFilterState = RadixBrowseFilterState()
    // Remembered bar state. The older rootBreadcrumb name is retained because
    // routing and saved behavior were built around that identifier.
    var rootBreadcrumb: [String] {
        get { userLibraryState.rememberedItems }
        set { userLibraryState.rememberedItems = newValue }
    }

    var rootBreadcrumbIndex: Int {
        get { userLibraryState.rememberedItemIndex }
        set { userLibraryState.rememberedItemIndex = newValue }
    }

    @Published private(set) var rootExplorerState = RadixRootExplorerState()

    var rootDerivatives: [ComponentItem] {
        get { rootExplorerState.derivatives }
        set { rootExplorerState.derivatives = newValue }
    }

    var rootDerivativesTotal: Int {
        get { rootExplorerState.derivativeTotal }
        set { rootExplorerState.derivativeTotal = newValue }
    }

    var availableRadicalFilters: [String] {
        get { rootExplorerState.availableRadicals }
        set { rootExplorerState.availableRadicals = newValue }
    }

    var availableStructureFilters: [String] {
        get { rootExplorerState.availableStructures }
        set { rootExplorerState.availableStructures = newValue }
    }

    @Published var collectionState = RadixCollectionState()
    @Published var browseGridState = RadixBrowseGridState()
    
    // MARK: - Computed Result Sets
    @Published private(set) var searchResults = RadixSearchResults()

    var results: [ComponentItem] {
        get { searchResults.characters }
        set { searchResults.characters = newValue }
    }

    var smartPhraseResults: [PhraseItem] {
        get { searchResults.phrases }
        set { searchResults.phrases = newValue }
    }

    var definitionCharacterResults: [ComponentItem] {
        get { searchResults.definitionCharacters }
        set { searchResults.definitionCharacters = newValue }
    }

    var definitionPhraseResults: [PhraseItem] {
        get { searchResults.definitionPhrases }
        set { searchResults.definitionPhrases = newValue }
    }

    @Published private(set) var lineageState = RadixLineageState()

    var lineageParents: [ComponentItem] {
        get { lineageState.parents }
        set { lineageState.parents = newValue }
    }

    var lineageDerivatives: [ComponentItem] {
        get { lineageState.derivatives }
        set { lineageState.derivatives = newValue }
    }

    var sortedLineageDerivatives: [ComponentItem] {
        get { lineageState.sortedDerivatives }
        set { lineageState.sortedDerivatives = newValue }
    }

    var phoneticFamily: [ComponentItem] {
        get { lineageState.phoneticFamily }
        set { lineageState.phoneticFamily = newValue }
    }

    var semanticFamily: [ComponentItem] {
        get { lineageState.semanticFamily }
        set { lineageState.semanticFamily = newValue }
    }

    var structureAnalysis: ComponentStructureAnalysis? {
        get { lineageState.structureAnalysis }
        set { lineageState.structureAnalysis = newValue }
    }

    var lineageSortMode: LineageSortMode {
        get { lineageState.sortMode }
        set { lineageState.sortMode = newValue }
    }

    var lineagePage: Int {
        get { lineageState.page }
        set { lineageState.page = newValue }
    }

    @Published private(set) var characterContextState = RadixCharacterContextState()

    var related: [ComponentItem] {
        get { characterContextState.relatedCharacters }
        set { characterContextState.relatedCharacters = newValue }
    }

    var phrases: [PhraseItem] {
        get { characterContextState.phrases }
        set { characterContextState.phrases = newValue }
    }

    var phraseLength: Int? {
        get { characterContextState.phraseLength }
        set { characterContextState.phraseLength = newValue }
    }

    var phraseLengthBinding: Binding<Int?> {
        Binding(
            get: { self.phraseLength },
            set: { self.phraseLength = $0 }
        )
    }

    var sharedComponentPeers: [ComponentItem] {
        get { characterContextState.sharedComponentPeers }
        set { characterContextState.sharedComponentPeers = newValue }
    }

    var sharedPeersByComponent: [String: [ComponentItem]] {
        get { characterContextState.sharedPeersByComponent }
        set { characterContextState.sharedPeersByComponent = newValue }
    }

    @Published private(set) var dataWorkspaceState = RadixDataWorkspaceState()

    var addedPhrases: [PhraseItem] {
        get { dataWorkspaceState.addedPhrases }
        set { dataWorkspaceState.addedPhrases = newValue }
    }

    var addedPhraseReviewPhrases: [PhraseItem] {
        get { dataWorkspaceState.addedPhraseReviewPhrases }
        set { dataWorkspaceState.addedPhraseReviewPhrases = newValue }
    }
    
    // MARK: - User Settings & Variances
    @Published private(set) var userLibraryState = RadixUserLibraryState()

    var favorites: Set<String> {
        get { userLibraryState.favoriteCharacters }
        set { userLibraryState.favoriteCharacters = newValue }
    }

    var favoriteAddedDates: [String: Date] {
        get { userLibraryState.favoriteCharacterDates }
        set { userLibraryState.favoriteCharacterDates = newValue }
    }

    var favoritePhrases: Set<String> {
        get { userLibraryState.favoritePhrases }
        set { userLibraryState.favoritePhrases = newValue }
    }

    var favoritePhraseDates: [String: Date] {
        get { userLibraryState.favoritePhraseDates }
        set { userLibraryState.favoritePhraseDates = newValue }
    }

    var overlayAddedDates: [String: Date] {
        get { userLibraryState.overlayAddedDates }
        set { userLibraryState.overlayAddedDates = newValue }
    }

    @Published var speechEnabled: Bool = true {
        didSet { preferences.set(speechEnabled, forKey: RadixPreferenceKey.speechEnabled) }
    }
    @Published private(set) var dataAuditState = RadixDataAuditState()

    var dictionaryVariances: [DictionaryVariance] {
        get { dataAuditState.dictionaryVariances }
        set { dataAuditState.dictionaryVariances = newValue }
    }

    var phraseVariances: [DictionaryVariance] {
        get { dataAuditState.phraseVariances }
        set { dataAuditState.phraseVariances = newValue }
    }

    var varianceMasterPhraseWords: Set<String>? {
        get { dataAuditState.varianceMasterPhraseWords }
        set { dataAuditState.varianceMasterPhraseWords = newValue }
    }

    var addedDictionaryCharacters: [String] {
        get { dataAuditState.addedDictionaryCharacters }
        set { dataAuditState.addedDictionaryCharacters = newValue }
    }

    var editedDictionaryCharacters: [String] {
        get { dataAuditState.editedDictionaryCharacters }
        set { dataAuditState.editedDictionaryCharacters = newValue }
    }

    var baseDictionaryCoreEditedCharacters: [String] {
        get { dataAuditState.baseDictionaryCoreEditedCharacters }
        set { dataAuditState.baseDictionaryCoreEditedCharacters = newValue }
    }

    var dictionaryCharactersWithNotes: [String] {
        get { dataAuditState.dictionaryCharactersWithNotes }
        set { dataAuditState.dictionaryCharactersWithNotes = newValue }
    }

    /// O(1) lookup companion for `editedDictionaryCharacters`. Always kept in sync.
    var editedDictionaryCharactersSet: Set<String> {
        get { dataAuditState.editedDictionaryCharacterSet }
        set { dataAuditState.editedDictionaryCharacterSet = newValue }
    }

    var changedDictionaryCharacters: [String] {
        get { dataAuditState.changedDictionaryCharacters }
        set { dataAuditState.changedDictionaryCharacters = newValue }
    }


    @Published private(set) var aiLinkState = RadixAILinkState()

    var activeSubject: ActiveSubject? {
        get { aiLinkState.activeSubject }
        set { aiLinkState.activeSubject = newValue }
    }

    var promptAutosaveStatus: String {
        get { aiLinkState.autosaveStatus }
        set { aiLinkState.autosaveStatus = newValue }
    }
    
    // MARK: - iPhone UI State
    
    // MARK: - AI Context State
    var promptConfig: PromptConfig {
        get { aiLinkState.promptConfig }
        set { aiLinkState.promptConfig = newValue }
    }

    var promptSelectedTaskIDs: [String] {
        get { aiLinkState.selectedTaskIDs }
        set { aiLinkState.selectedTaskIDs = newValue }
    }

    var selectedConversationPracticeTopicID: String {
        get { aiLinkState.selectedConversationPracticeTopicID }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            aiLinkState.selectedConversationPracticeTopicID = trimmed.isEmpty
                ? ConversationPracticeTopic.generalGreetings.id
                : trimmed
        }
    }

    var selectedConversationPracticeTopic: ConversationPracticeTopic {
        ConversationPracticeTopic.topic(for: selectedConversationPracticeTopicID)
    }

    var aiConversationEntryCount: Int {
        get { aiLinkState.conversationEntryCount }
        set {
            aiLinkState.conversationEntryCount = PromptConfig.normalizedConversationEntryCount(newValue)
        }
    }

    var aiSentenceExtractionDetail: SentenceExtractionDetail {
        get { aiLinkState.sentenceExtractionDetail }
        set { aiLinkState.sentenceExtractionDetail = newValue }
    }

    var shouldAutoOpenAILinkPrompt: Bool {
        get { aiLinkState.shouldAutoOpenPrompt }
        set { aiLinkState.shouldAutoOpenPrompt = newValue }
    }

    var shouldAutoOpenAILinkTask4: Bool {
        get { shouldAutoOpenAILinkPrompt }
        set { shouldAutoOpenAILinkPrompt = newValue }
    }

    var shouldAutoRunGeminiPhraseAPI: Bool {
        get { aiLinkState.shouldAutoRunGeminiPhraseAPI }
        set { aiLinkState.shouldAutoRunGeminiPhraseAPI = newValue }
    }

    @Published private(set) var aiProviderState = RadixAIProviderState()

    var defaultAIPreset: DefaultAIPreset {
        get { aiProviderState.defaultPreset }
        set {
            aiProviderState.defaultPreset = newValue
            persistPromptSettings()
        }
    }

    var customAIURLString: String {
        get { aiProviderState.customURLString }
        set {
            aiProviderState.customURLString = newValue
            persistPromptSettings()
        }
    }

    var openAIAPIKey: String {
        get { aiProviderState.openAIAPIKey }
        set {
            aiProviderState.openAIAPIKey = newValue
            persistPromptSettings()
        }
    }

    var geminiAPIKey: String {
        get { aiProviderState.geminiAPIKey }
        set {
            aiProviderState.geminiAPIKey = newValue
            persistPromptSettings()
        }
    }

    var claudeAPIKey: String {
        get { aiProviderState.claudeAPIKey }
        set {
            aiProviderState.claudeAPIKey = newValue
            persistPromptSettings()
        }
    }

    var deepSeekAPIKey: String {
        get { aiProviderState.deepSeekAPIKey }
        set {
            aiProviderState.deepSeekAPIKey = newValue
            persistPromptSettings()
        }
    }

    var customAIAPIKey: String {
        get { aiProviderState.customAIAPIKey }
        set {
            aiProviderState.customAIAPIKey = newValue
            persistPromptSettings()
        }
    }

    var geminiModelID: String {
        get { aiProviderState.geminiModelID }
        set {
            aiProviderState.geminiModelID = newValue
            persistPromptSettings()
        }
    }

    // MARK: - Repositories & Helpers
    let componentRepo = ComponentRepository()
    let phraseRepo = PhraseRepository()
    let entitlement = EntitlementManager()
    let speechService = CharacterSpeechService()
    var pendingDatasetAutosaveWorkItem: DispatchWorkItem?
    var pendingGridRecomputeWorkItem: DispatchWorkItem?
    var isApplyingDatasetEntry = false
    var allCharactersCache: [ComponentItem] = []
    var selectedBrowseCollectionCharacters: Set<String>? = nil
    var phraseCache: [String: [PhraseItem]] = [:]
    var conversationPracticePhraseCache: [String: PhraseItem] = [:]
    var conversationPracticeLinkedHintCache: [ConversationPracticeHintCacheKey: ConversationPracticeLinkedHints] = [:]
    @Published var favoriteSentenceRevision = 0
    var rootsDerivativesCache: [RootsCacheKey: RootsDerivativesCacheValue] = [:]

    struct RootsCacheKey: Hashable {
        let character: String
        let script: ScriptFilter
        let minStroke: Int
        let maxStroke: Int
        let radical: String
        let structure: String
    }

    struct RootsDerivativesCacheValue {
        let items: [ComponentItem]
        let total: Int
    }
    @Published var browseHighlightState = RadixBrowseHighlightState()

    var browsePagePhraseTileCache: [UUID: [Int: BrowseImagePhraseTileData]] = [:]
    var browsePagePhraseCandidateCache: [UUID: [BrowsePagePhraseCandidate]] = [:]

    var suppressHelpReset = false
    var loadingError: String? {
        get { dataWorkspaceState.loadingError }
        set { dataWorkspaceState.loadingError = newValue }
    }

    var dataEditSavePath: String {
        get { dataWorkspaceState.dictionaryOverlayPath }
        set { dataWorkspaceState.dictionaryOverlayPath = newValue }
    }

    var addPhrasesPath: String {
        get { dataWorkspaceState.addedPhrasesDatabasePath }
        set { dataWorkspaceState.addedPhrasesDatabasePath = newValue }
    }
}
