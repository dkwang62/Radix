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

/// Determines the primary search logic (Smart vs exact Definition).
enum SearchMode: String, CaseIterable, Identifiable, Codable {
    case smart = "Smart"
    case definition = "Definition"

    var id: String { rawValue }
}

/// Sorting logic for character lineage exploration.
enum LineageSortMode: String, CaseIterable, Identifiable {
    case usage = "Usage"
    case frequency = "Frequency"

    var id: String { rawValue }
}

/// Primary navigation routes for the app sidebar.
enum AppRoute: String, CaseIterable, Identifiable {
    case search = "Search"
    case capture = "Capture"
    case lineage = "Lineage"
    case aiLink = "AI Link"
    case favourites = "Favourites"
    case settings = "Settings"

    var id: String { rawValue }
}

/// Nested tabs within the Search route.
enum HomeTab: String, CaseIterable, Identifiable {
    case smart = "Smart Search"
    case filter = "Filter"
    case favourites = "Favourites"
    case dataEdit = "DataEdit"

    var id: String { rawValue }
    
    var index: Int {
        switch self {
        case .smart: return 0
        case .filter: return 1
        case .favourites: return 3
        case .dataEdit: return 5
        }
    }
    
    static func fromIndex(_ index: Int) -> HomeTab {
        switch index {
        case 1: return .filter
        case 3: return .favourites
        case 5: return .dataEdit
        default: return .smart
        }
    }
}

enum SidebarNavigationStyle: String, CaseIterable, Identifiable, Codable {
    case descriptive = "Descriptive"
    case compact = "Compact"

    var id: String { rawValue }

    var displayName: String { rawValue }

    static func fromStoredValue(_ value: String) -> SidebarNavigationStyle? {
        if value == "Full" { return .descriptive }
        return SidebarNavigationStyle(rawValue: value)
    }
}

struct RootsReturnContext: Equatable {
    let route: AppRoute
    let homeTab: HomeTab?
}

/// Sorting modes for the discovery grid.
enum GridSortMode: String, CaseIterable, Identifiable {
    case readingOrder = "Reading Order"
    case componentFrequency = "Components"
    case characterFrequency = "All"

    var id: String { rawValue }
}

enum ImagePhraseHighlightRole {
    case target
    case phraseMember
}

enum QuickEditDestination: Identifiable, Equatable {
    case character(String)
    case phrase(String)
    case newCharacter
    case newPhrase

    var id: String {
        switch self {
        case .character(let character):
            return "character:\(character)"
        case .phrase(let phrase):
            return "phrase:\(phrase)"
        case .newCharacter:
            return "newCharacter"
        case .newPhrase:
            return "newPhrase"
        }
    }
}

@MainActor
/// Controls how an imported backup interacts with existing data on the device.
enum RestoreMode {
    /// Merges backup into existing data — existing entries are kept, only new ones are added.
    case additive
    /// Replaces all existing data with the backup — existing entries are overwritten or removed.
    case complete
}

@MainActor
final class RadixStore: ObservableObject {
    let preferences: RadixPreferences = .standard

    // MARK: - Navigation State
    @Published private(set) var navigationState = RadixNavigationState()

    var route: AppRoute {
        get { navigationState.route }
        set { navigationState.route = newValue }
    }

    var homeTab: HomeTab {
        get { navigationState.homeTab }
        set { navigationState.homeTab = newValue }
    }

    var sidebarNavigationStyle: SidebarNavigationStyle {
        get { navigationState.sidebarNavigationStyle }
        set {
            navigationState.sidebarNavigationStyle = newValue
            preferences.set(newValue.rawValue, forKey: sidebarNavigationStyleKey)
        }
    }

    var rootsReturnContext: RootsReturnContext? {
        get { navigationState.rootsReturnContext }
        set { navigationState.rootsReturnContext = newValue }
    }

    var previewCharacter: String? {
        get { navigationState.previewCharacter }
        set {
            navigationState.previewCharacter = newValue
            rememberLastPreviewedCharacter(newValue)
        }
    }

    var history: [String] {
        get { navigationState.history }
        set { navigationState.history = newValue }
    }
    @Published private(set) var presentationState = RadixPresentationState()

    var showPaywall: Bool { get { presentationState.showsPaywall } set { presentationState.showsPaywall = newValue } }
    var paywallFeatureName: String { get { presentationState.paywallFeatureName } set { presentationState.paywallFeatureName = newValue } }
    
    // MARK: - Search State
    @Published private(set) var searchState = RadixSearchState()

    var query: String {
        get { searchState.query }
        set { searchState.query = newValue }
    }

    var searchMode: SearchMode {
        get { searchState.mode }
        set { searchState.mode = newValue }
    }

    var scriptFilter: ScriptFilter {
        get { searchState.scriptFilter }
        set { searchState.scriptFilter = newValue }
    }

    var hasPerformedSearch: Bool {
        get { searchState.hasPerformedSearch }
        set { searchState.hasPerformedSearch = newValue }
    }

    var lastSearchQuery: String {
        get { searchState.lastQuery }
        set { searchState.lastQuery = newValue }
    }

    var searchHistory: [String] {
        get { searchState.history }
        set { searchState.history = newValue }
    }
    
    // MARK: - DataEdit (Character Studio) State
    @Published private(set) var dataEditFormState = RadixDataEditFormState()

    var dataEditCharacter: String { get { dataEditFormState.character } set { dataEditFormState.character = newValue } }
    var dataEditDefinition: String { get { dataEditFormState.definition } set { dataEditFormState.definition = newValue } }
    var dataEditPinyin: String { get { dataEditFormState.pinyin } set { dataEditFormState.pinyin = newValue } }
    var dataEditDecomposition: String { get { dataEditFormState.decomposition } set { dataEditFormState.decomposition = newValue } }
    var dataEditRadical: String { get { dataEditFormState.radical } set { dataEditFormState.radical = newValue } }
    var dataEditStrokes: String { get { dataEditFormState.strokes } set { dataEditFormState.strokes = newValue } }
    var dataEditCompounds: String { get { dataEditFormState.compounds } set { dataEditFormState.compounds = newValue } }
    var dataEditEtymHint: String { get { dataEditFormState.etymologyHint } set { dataEditFormState.etymologyHint = newValue } }
    var dataEditEtymDetails: String { get { dataEditFormState.etymologyDetails } set { dataEditFormState.etymologyDetails = newValue } }
    var dataEditNotes: String { get { dataEditFormState.notes } set { dataEditFormState.notes = newValue } }
    var dataEditRelatedCharacters: String { get { dataEditFormState.relatedCharacters } set { dataEditFormState.relatedCharacters = newValue } }
    var dataEditIsFavourite: Bool { get { dataEditFormState.isFavourite } set { dataEditFormState.isFavourite = newValue } }
    var dataEditPhrases: [PhraseItem] { get { dataEditFormState.phrases } set { dataEditFormState.phrases = newValue } }
    var dataEditAutoSaveStatus: String { get { dataEditFormState.autosaveStatus } set { dataEditFormState.autosaveStatus = newValue } }
    var dataEditVariant: String { get { dataEditFormState.variant } set { dataEditFormState.variant = newValue } }
    var dataEditAdditionalVariants: String { get { dataEditFormState.additionalVariants } set { dataEditFormState.additionalVariants = newValue } }

    func dataEditBinding<Value>(_ keyPath: WritableKeyPath<RadixDataEditFormState, Value>) -> Binding<Value> {
        Binding(
            get: { self.dataEditFormState[keyPath: keyPath] },
            set: { self.dataEditFormState[keyPath: keyPath] = $0 }
        )
    }

    @Published private(set) var dataEditFocusRequestID: Int = 0
    @Published private(set) var phraseEditFocusRequestID: Int = 0
    @Published private(set) var phraseEditRequestedWord: String = ""
    var dataEditLoadTask: Task<Void, Never>?
    /// Cache to avoid reloading heavy entries when toggling between AI/Data.
    var dataEditCache: [String: (entry: RawComponentEntry, phrases: [PhraseItem], isFav: Bool)] = [:]
    var dataEditEtymologyType: String?

    // MARK: - Browsing & Filter State
    @Published private(set) var browseFilterState = RadixBrowseFilterState()

    var favoritesOnlyFilter: Bool {
        get { browseFilterState.favoritesOnly }
        set { browseFilterState.favoritesOnly = newValue }
    }

    var strokeMinFilter: Int {
        get { browseFilterState.minimumStroke }
        set {
            guard browseFilterState.minimumStroke != newValue else { return }
            browseFilterState.minimumStroke = newValue
            gridPage = 0
            scheduleGridRecompute()
        }
    }

    var strokeMaxFilter: Int {
        get { browseFilterState.maximumStroke }
        set {
            let pinnedValue = 30
            guard browseFilterState.maximumStroke != pinnedValue || newValue != pinnedValue else { return }
            browseFilterState.maximumStroke = pinnedValue
            gridPage = 0
            scheduleGridRecompute()
        }
    }

    var selectedRadicalFilter: String {
        get { browseFilterState.radical }
        set {
            guard browseFilterState.radical != newValue else { return }
            browseFilterState.radical = newValue
            gridPage = 0
            scheduleGridRecompute()
        }
    }

    var selectedStructureFilter: String {
        get { browseFilterState.structure }
        set {
            guard browseFilterState.structure != newValue else { return }
            browseFilterState.structure = newValue
            gridPage = 0
            scheduleGridRecompute()
        }
    }

    // Roots-specific filters
    var rootMinStroke: Int {
        get { browseFilterState.rootMinimumStroke }
        set {
            guard browseFilterState.rootMinimumStroke != newValue else { return }
            browseFilterState.rootMinimumStroke = newValue
            reloadRootContextForFilterChange()
        }
    }

    var rootMaxStroke: Int {
        get { browseFilterState.rootMaximumStroke }
        set {
            let clampedValue = min(max(newValue, 0), 30)
            guard browseFilterState.rootMaximumStroke != clampedValue || newValue != clampedValue else { return }
            browseFilterState.rootMaximumStroke = clampedValue
            reloadRootContextForFilterChange()
        }
    }

    var rootRadicalFilter: String {
        get { browseFilterState.rootRadical }
        set {
            guard browseFilterState.rootRadical != newValue else { return }
            browseFilterState.rootRadical = newValue
            reloadRootContextForFilterChange()
        }
    }

    var rootStructureFilter: String {
        get { browseFilterState.rootStructure }
        set {
            guard browseFilterState.rootStructure != newValue else { return }
            browseFilterState.rootStructure = newValue
            reloadRootContextForFilterChange()
        }
    }

    func browseFilterBinding<Value>(_ keyPath: ReferenceWritableKeyPath<RadixStore, Value>) -> Binding<Value> {
        Binding(
            get: { self[keyPath: keyPath] },
            set: { self[keyPath: keyPath] = $0 }
        )
    }

    private func reloadRootContextForFilterChange() {
        guard let current = previewCharacter else { return }
        loadSharedComponentPeers(for: current)
        loadSharedPeersByComponent(for: current)
        loadRootDerivatives(for: current)
    }
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

    var gridSortMode: GridSortMode {
        get { browseFilterState.gridSortMode }
        set {
            guard browseFilterState.gridSortMode != newValue else { return }
            browseFilterState.gridSortMode = newValue
            gridPage = 0
            scheduleGridRecompute()
        }
    }

    var gridScriptFilter: ScriptFilter {
        get { browseFilterState.gridScriptFilter }
        set {
            guard browseFilterState.gridScriptFilter != newValue else { return }
            browseFilterState.gridScriptFilter = newValue
            gridPage = 0
            scheduleGridRecompute()
        }
    }
    @Published private(set) var collectionState = RadixCollectionState()

    var allCollections: [CharacterCollection] {
        get { collectionState.collections }
        set { collectionState.collections = newValue }
    }

    var selectedBrowseCollectionID: UUID? {
        get { collectionState.selectedBrowseCollectionID }
        set {
            guard collectionState.selectedBrowseCollectionID != newValue else { return }
            collectionState.selectedBrowseCollectionID = newValue
            selectedBrowseCollectionCharacters = newValue.flatMap { collection(id: $0).map { Set($0.characters) } }
            clearBrowseMemoryHighlight()
            if newValue != nil {
                browseHighlightedCharacter = nil
            }
            if let selectedBrowseCollection {
                activeSubject = .collection(selectedBrowseCollection)
            } else if case .collection = activeSubject {
                activeSubject = nil
            }
            gridPage = 0
            scheduleGridRecompute()
        }
    }
    var shouldOpenBrowsePages: Bool { get { presentationState.shouldOpenBrowsePages } set { presentationState.shouldOpenBrowsePages = newValue } }
    var shouldOpenAddedPhraseReview: Bool { get { presentationState.shouldOpenAddedPhraseReview } set { presentationState.shouldOpenAddedPhraseReview = newValue } }
    var shouldStartBrowseCamera: Bool { get { presentationState.shouldStartBrowseCamera } set { presentationState.shouldStartBrowseCamera = newValue } }
    var selectedAICollectionID: UUID? {
        get { collectionState.selectedAICollectionID }
        set {
            guard collectionState.selectedAICollectionID != newValue else { return }
            collectionState.selectedAICollectionID = newValue
            persistSelectedAICollection()
        }
    }
    @Published private(set) var browseGridState = RadixBrowseGridState()

    var gridFilteredAllCount: Int {
        get { browseGridState.filteredAllCount }
        set { browseGridState.filteredAllCount = newValue }
    }

    var gridFilteredComponentCount: Int {
        get { browseGridState.filteredComponentCount }
        set { browseGridState.filteredComponentCount = newValue }
    }

    var gridPage: Int {
        get { browseGridState.page }
        set { browseGridState.page = newValue }
    }

    var allGridItems: [ComponentItem] {
        get { browseGridState.items }
        set { browseGridState.items = newValue }
    }

    var allReadingOrderCharacters: [String] {
        get { browseGridState.readingOrderCharacters }
        set { browseGridState.readingOrderCharacters = newValue }
    }
    
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

    @Published var addedPhrases: [PhraseItem] = []
    
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
        didSet { preferences.set(speechEnabled, forKey: speechEnabledKey) }
    }
    var activeFavouriteCharacter: String? { get { presentationState.activeFavouriteCharacter } set { presentationState.activeFavouriteCharacter = newValue } }
    @Published private(set) var dataAuditState = RadixDataAuditState()

    var dictionaryVariances: [DictionaryVariance] {
        get { dataAuditState.dictionaryVariances }
        set { dataAuditState.dictionaryVariances = newValue }
    }

    var phraseVariances: [DictionaryVariance] {
        get { dataAuditState.phraseVariances }
        set { dataAuditState.phraseVariances = newValue }
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

    var quickEditDestination: QuickEditDestination? { get { presentationState.quickEditDestination } set { presentationState.quickEditDestination = newValue } }
    @Published var activeSubject: ActiveSubject? = nil

    @Published private(set) var aiLinkState = RadixAILinkState()

    var promptAutosaveStatus: String {
        get { aiLinkState.autosaveStatus }
        set { aiLinkState.autosaveStatus = newValue }
    }
    
    // MARK: - iPhone UI State
    var showiPhoneDetail: Bool { get { presentationState.showsPhoneDetail } set { presentationState.showsPhoneDetail = newValue } }
    
    // MARK: - AI Context State
    var promptConfig: PromptConfig {
        get { aiLinkState.promptConfig }
        set { aiLinkState.promptConfig = newValue }
    }

    var promptSelectedTaskIDs: [String] {
        get { aiLinkState.selectedTaskIDs }
        set { aiLinkState.selectedTaskIDs = newValue }
    }

    var shouldAutoOpenAILinkTask4: Bool {
        get { aiLinkState.shouldAutoOpenTask4 }
        set { aiLinkState.shouldAutoOpenTask4 = newValue }
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
    private let entitlement = EntitlementManager()
    let speechService = CharacterSpeechService()
    let favoritesKey = "radix.favorites"
    let favoriteEntriesKey = "radix.favoriteEntries"
    let favoritePhrasesKey = "radix.favoritePhrases"
    let favoritePhraseDatesKey = "radix.favoritePhraseDates"
    let overlayAddedDatesKey = "radix.overlayAddedDates"
    private let speechEnabledKey = "radix.speechEnabled"
    private let speakOnSelectionKey = "radix.speakOnSelection"
    private let speakOnPreviewKey = "radix.speakOnPreview"
    let promptConfigKey = "radix.promptConfig"
    let promptTaskSelectionKey = "radix.promptSelectedTaskIDs"
    let defaultAIPresetKey = "radix.defaultAIPreset"
    let customAIURLKey = "radix.customAIURL"
    let openAIAPIKeyKey = "radix.openAIAPIKey"
    let geminiAPIKeyKey = "radix.geminiAPIKey"
    let claudeAPIKeyKey = "radix.claudeAPIKey"
    let deepSeekAPIKeyKey = "radix.deepSeekAPIKey"
    let customAIAPIKeyKey = "radix.customAIAPIKey"
    let geminiModelIDKey = "radix.geminiModelID"
    let collectionsKey = "radix.characterCollections"
    let selectedAICollectionKey = "radix.selectedAICollectionID"
    private let lastPreviewCharacterKey = "radix.lastPreviewCharacter"
    let searchHistoryKey = "radix.searchHistory"
    let rootBreadcrumbKey = "radix.rootBreadcrumb"
    let sidebarNavigationStyleKey = "radix.sidebarNavigationStyle"
    private var pendingSearchWorkItem: DispatchWorkItem?
    var pendingDatasetAutosaveWorkItem: DispatchWorkItem?
    var pendingGridRecomputeWorkItem: DispatchWorkItem?
    var isApplyingDatasetEntry = false
    var allCharactersCache: [ComponentItem] = []
    var selectedBrowseCollectionCharacters: Set<String>? = nil
    var phraseCache: [String: [PhraseItem]] = [:]
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
    @Published private(set) var browseHighlightState = RadixBrowseHighlightState()

    var imagePhraseContext: ImagePhraseContext? {
        get { browseHighlightState.phraseContext }
        set { browseHighlightState.phraseContext = newValue }
    }

    var imagePhraseHighlightOffsets: Set<Int> {
        get { browseHighlightState.phraseOffsets }
        set { browseHighlightState.phraseOffsets = newValue }
    }

    // Keep phrase-origin highlight state in the store, not in Browse UI views.
    // iPhone phrase previews can drill into component characters; when returning
    // to Browse, this anchor restores the original full phrase highlight instead
    // of leaving the last previewed character highlighted. Future refactors should
    // preserve this store-level ownership so layout/navigation changes do not
    // break phrase highlighting.
    var anchoredImagePhraseContext: ImagePhraseContext? {
        get { browseHighlightState.anchoredPhraseContext }
        set { browseHighlightState.anchoredPhraseContext = newValue }
    }

    var anchoredImagePhraseHighlightOffsets: Set<Int> {
        get { browseHighlightState.anchoredPhraseOffsets }
        set { browseHighlightState.anchoredPhraseOffsets = newValue }
    }

    var anchoredImagePhraseWord: String? {
        get { browseHighlightState.anchoredPhraseWord }
        set { browseHighlightState.anchoredPhraseWord = newValue }
    }

    var anchoredImagePhraseCollectionID: UUID? {
        get { browseHighlightState.anchoredCollectionID }
        set { browseHighlightState.anchoredCollectionID = newValue }
    }

    var browsePagePhraseTileCache: [UUID: [Int: BrowseImagePhraseTileData]] = [:]
    var browsePagePhraseCandidateCache: [UUID: [BrowsePagePhraseCandidate]] = [:]

    var imagePhraseHighlightRevision: Int {
        get { browseHighlightState.revision }
        set { browseHighlightState.revision = newValue }
    }

    var imageBrowsePhrasePreview: PhraseItem? {
        get { browseHighlightState.imagePhrasePreview }
        set { browseHighlightState.imagePhrasePreview = newValue }
    }

    var sidebarPhrasePreview: PhraseItem? {
        get { browseHighlightState.sidebarPhrasePreview }
        set { browseHighlightState.sidebarPhrasePreview = newValue }
    }

    var pendingBrowseScrollTarget: BrowseScrollTarget? {
        get { browseHighlightState.pendingScrollTarget }
        set { browseHighlightState.pendingScrollTarget = newValue }
    }

    var browseHighlightedCharacter: String? {
        get { browseHighlightState.highlightedCharacter }
        set { browseHighlightState.highlightedCharacter = newValue }
    }

    var browseMemoryHighlightCollectionID: UUID? {
        get { browseHighlightState.memoryCollectionID }
        set { browseHighlightState.memoryCollectionID = newValue }
    }

    var browseMemoryHighlightOffsets: Set<Int> {
        get { browseHighlightState.memoryOffsets }
        set { browseHighlightState.memoryOffsets = newValue }
    }

    var browseMemoryHighlightedItem: String? {
        get { browseHighlightState.memoryHighlightedItem }
        set { browseHighlightState.memoryHighlightedItem = newValue }
    }

    var suppressHelpReset = false
    @Published private(set) var loadingError: String?
    @Published private(set) var dataEditSavePath: String = ""
    @Published var addPhrasesPath: String = ""
    var showBrowseHelp: Bool { get { presentationState.showsBrowseHelp } set { presentationState.showsBrowseHelp = newValue } }
    var showComponentHelp: Bool { get { presentationState.showsComponentHelp } set { presentationState.showsComponentHelp = newValue } }
    var activeCaptureDraft: CaptureDraft { get { presentationState.activeCaptureDraft } set { presentationState.activeCaptureDraft = newValue } }

    func presentationBinding<Value>(_ keyPath: ReferenceWritableKeyPath<RadixStore, Value>) -> Binding<Value> {
        Binding(
            get: { self[keyPath: keyPath] },
            set: { self[keyPath: keyPath] = $0 }
        )
    }

    // MARK: - Core Lifecycle
    
    /// Initializes the store by loading the dictionary and phrase database.
    func initialize() async {
        do {
            try loadDictionaryRepository()
            try phraseRepo.openFromBundle()
            setupInitialState()
        } catch {
            loadingError = error.localizedDescription
        }
    }

    /// Isolated initialization for unit tests using a temporary SQLite database.
    func initializeForTesting() async {
        do {
            try componentRepo.loadFromBundle()
            try phraseRepo.openForTesting()
            setupInitialState()
        } catch {
            loadingError = error.localizedDescription
        }
    }

    private func setupInitialState() {
        availableRadicalFilters = ["none"] + componentRepo.availableRadicals()
        availableStructureFilters = ["none"] + componentRepo.availableStructures()
        if !availableRadicalFilters.contains(selectedRadicalFilter) { selectedRadicalFilter = "none" }
        if !availableRadicalFilters.contains(rootRadicalFilter) { rootRadicalFilter = "none" }
        if !availableStructureFilters.contains(selectedStructureFilter) { selectedStructureFilter = "none" }
        if !availableStructureFilters.contains(rootStructureFilter) { rootStructureFilter = "none" }
        dataEditSavePath = dictionaryOverlayFileURL.path
        loadSidebarNavigationStyle()
        loadPromptSettings()
        promptConfig = promptConfig.normalized()
        promptSelectedTaskIDs = PromptTaskSelection.normalized(
            promptSelectedTaskIDs,
            availableIDs: promptConfig.tasks.map(\.id),
            defaultIDs: PromptConfig.defaultSelectedTaskIDs
        )
        loadCollections()
        loadFavorites()
        loadSearchHistory()
        loadRootBreadcrumb()
        clearSearch()
        refreshAllCharactersCache()
        recomputeGridItems()
        refreshAddedPhrases()
        refreshAddedDictionaryCharacters()
        calculateDictionaryVariances()
        dataEditPhrases = addedPhrases
        addPhrasesPath = phraseRepo.currentAddDBPath
        // Do not preload a default character; start empty
        // (shared component peers/derivatives will load on first selection)
        sharedComponentPeers = []
        sharedPeersByComponent = [:]
        // Ensure app boots into Browse (filter tab) on all devices
        route = .search
        homeTab = .filter
        showBrowseHelp = true
        showComponentHelp = true
        
        previewCharacter = nil
        showiPhoneDetail = false
    }

    func loadSidebarNavigationStyle() {
        if let saved = preferences.string(forKey: sidebarNavigationStyleKey),
           let style = SidebarNavigationStyle.fromStoredValue(saved) {
            sidebarNavigationStyle = style
        } else {
            sidebarNavigationStyle = .descriptive
        }
    }


    // MARK: - Filter Logic & Caching
    
    var filteredResults: [ComponentItem] {
        applyScriptFilter(to: results)
    }

    var filteredDefinitionCharacterResults: [ComponentItem] {
        applyScriptFilter(to: definitionCharacterResults)
    }

    var filteredSmartPhraseResults: [PhraseItem] {
        sortPhrasesByPinyin(applyPhraseScriptFilter(to: smartPhraseResults))
    }

    var filteredDefinitionPhraseResults: [PhraseItem] {
        sortPhrasesByPinyin(applyPhraseScriptFilter(to: definitionPhraseResults))
    }

    private func applyScriptFilter(to items: [ComponentItem]) -> [ComponentItem] {
        items.filter { item in
            switch scriptFilter {
            case .any: return true
            case .simplified: return componentRepo.isSimplifiedForGrid(item.character)
            case .traditional: return componentRepo.isTraditionalForGrid(item.character)
            }
        }
    }

    private func applyPhraseScriptFilter(to items: [PhraseItem]) -> [PhraseItem] {
        items.filter { item in
            switch scriptFilter {
            case .any: return true
            case .simplified:
                let first = String(item.word.prefix(1))
                return componentRepo.isSimplifiedForGrid(first)
            case .traditional:
                let first = String(item.word.prefix(1))
                return componentRepo.isTraditionalForGrid(first)
            }
        }
    }

    var smartFilteredResults: [ComponentItem] {
        let lower = min(strokeMinFilter, strokeMaxFilter)
        let upper = max(strokeMinFilter, strokeMaxFilter)
        return results.filter { item in
            let strokeValue = item.strokes ?? 999
            let strokeMatch = strokeValue >= lower && strokeValue <= upper
            let favoritesMatch = !favoritesOnlyFilter || favorites.contains(item.character)
            let radicalMatch = isNoFilter(selectedRadicalFilter) || item.radical == selectedRadicalFilter
            let structure = componentRepo.structureKey(for: item)
            let structureMatch = isNoFilter(selectedStructureFilter) || structure == selectedStructureFilter
            return strokeMatch && favoritesMatch && radicalMatch && structureMatch
        }
    }

    func buildGridItemsWithCounts() -> (items: [ComponentItem], allCount: Int, componentCount: Int, readingOrder: [String]) {
        let lower = min(strokeMinFilter, strokeMaxFilter)
        let upper = max(strokeMinFilter, strokeMaxFilter)

        // Reading-order mode: preserve full sequence including duplicates
        if gridSortMode == .readingOrder, let collection = selectedBrowseCollection {
            // Filter the full character sequence (with duplicates) through active filters
            let filteredOrdered: [String] = collection.characters.filter { char in
                guard let item = componentRepo.byCharacter[char] else { return false }
                let strokeValue = item.strokes ?? 999
                let strokeMatch = strokeValue >= lower && strokeValue <= upper
                let radicalMatch = isNoFilter(selectedRadicalFilter) || item.radical == selectedRadicalFilter
                let structure = componentRepo.structureKey(for: item)
                let structureMatch = isNoFilter(selectedStructureFilter) || structure == selectedStructureFilter
                let scriptMatch: Bool = {
                    switch gridScriptFilter {
                    case .any: return true
                    case .simplified: return componentRepo.isSimplifiedForGrid(char)
                    case .traditional: return componentRepo.isTraditionalForGrid(char)
                    }
                }()
                return strokeMatch && radicalMatch && structureMatch && scriptMatch
            }
            // Unique items for counts
            var seen = Set<String>()
            let uniqueItems: [ComponentItem] = filteredOrdered.compactMap { char in
                guard seen.insert(char).inserted else { return nil }
                return componentRepo.byCharacter[char]
            }
            let componentPool = uniqueItems.filter { componentRepo.isUsedComponent($0.character) }
            return (items: uniqueItems, allCount: filteredOrdered.count, componentCount: componentPool.count, readingOrder: filteredOrdered)
        }

        var items = allCharactersCache
        if let collectionCharacters = selectedBrowseCollectionCharacters {
            items = items.filter { collectionCharacters.contains($0.character) }
        }
        items = items.filter { item in
            let strokeValue = item.strokes ?? 999
            let strokeMatch = strokeValue >= lower && strokeValue <= upper
            let radicalMatch = isNoFilter(selectedRadicalFilter) || item.radical == selectedRadicalFilter
            let structure = componentRepo.structureKey(for: item)
            let structureMatch = isNoFilter(selectedStructureFilter) || structure == selectedStructureFilter
            return strokeMatch && radicalMatch && structureMatch
        }

        items = items.filter { item in
            switch gridScriptFilter {
            case .any:
                return true
            case .simplified:
                return componentRepo.isSimplifiedForGrid(item.character)
            case .traditional:
                return componentRepo.isTraditionalForGrid(item.character)
            }
        }

        let componentPool = items.filter { componentRepo.isUsedComponent($0.character) }
        let sorted: [ComponentItem] = {
            switch gridSortMode {
            case .readingOrder:
                return items.sorted(by: frequencySortPredicate)
            case .componentFrequency:
                return componentPool.sorted(by: usageSortPredicate)
            case .characterFrequency:
                return items.sorted(by: frequencySortPredicate)
            }
        }()

        return (items: sorted, allCount: items.count, componentCount: componentPool.count, readingOrder: [])
    }

    var gridBatchSize: Int {
        BrowseGridLayout.current.dictionaryPageSize
    }
    var gridPageCount: Int {
        let count = gridSortMode == .readingOrder ? allReadingOrderCharacters.count : allGridItems.count
        return GridPaging.pageCount(totalCount: count, pageSize: gridBatchSize)
    }
    var pagedGridItems: [ComponentItem] {
        GridPaging.pageSlice(allGridItems, page: gridPage, pageSize: gridBatchSize).items
    }
    /// Paged slice of the full reading-order sequence (with duplicates), as (offset, character) pairs.
    var pagedReadingOrderItems: [(offset: Int, character: String)] {
        let slice = GridPaging.pageSlice(allReadingOrderCharacters, page: gridPage, pageSize: gridBatchSize)
        return slice.items.enumerated().map { (slice.start + $0.offset, $0.element) }
    }
    func nextGridPage() {
        gridPage = GridPaging.nextPage(current: gridPage, pageCount: gridPageCount)
    }
    func previousGridPage() {
        gridPage = GridPaging.previousPage(current: gridPage)
    }

    func setGridSortMode(_ mode: GridSortMode) { gridSortMode = mode }
    func setGridScriptFilter(_ filter: ScriptFilter) { gridScriptFilter = filter }
    @discardableResult
    func focusGridCharacter(_ character: String) -> Bool {
        guard let index = allGridItems.firstIndex(where: { $0.character == character }) else {
            previewCharacter = character
            return false
        }
        gridPage = GridPaging.pageForIndex(index, pageSize: gridBatchSize)
        previewCharacter = character
        return true
    }

    func radicalFilterLabel(_ radical: String) -> String {
        if isNoFilter(radical) {
            return "none"
        }
        guard let strokes = componentRepo.byCharacter[radical]?.strokes, strokes > 0 else {
            return radical
        }
        let unit = strokes == 1 ? "stroke" : "strokes"
        return "\(radical) (\(strokes) \(unit))"
    }

    // MARK: - Lineage Logic
    var lineageBatchSize: Int {
        RadixPlatform.isDesktop ? 225 : 12
    }
    var pagedLineageDerivatives: [ComponentItem] {
        let baseItems = sortedLineageDerivatives
        let limitedItems = entitlement.limitLineage(baseItems)
        
        let start = min(max(0, lineagePage), max(0, lineagePageCount - 1)) * lineageBatchSize
        let end = min(start + lineageBatchSize, limitedItems.count)
        guard start < end else { return [] }
        return Array(limitedItems[start..<end])
    }
    
    var lineagePageCount: Int {
        let count = entitlement.limitLineage(sortedLineageDerivatives).count
        return count == 0 ? 1 : Int(ceil(Double(count) / Double(lineageBatchSize)))
    }
    func nextLineagePage() {
        guard lineagePage + 1 < lineagePageCount else { return }
        lineagePage += 1
    }
    func previousLineagePage() {
        guard lineagePage > 0 else { return }
        lineagePage -= 1
    }

    // MARK: - Private Utilities











































    func loadSearchHistory() {
        guard let saved = preferences.array(forKey: searchHistoryKey) as? [String] else { return }
        searchHistory = saved
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    func appendSearchHistory(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        searchHistory.append(trimmed)
        preferences.set(searchHistory, forKey: searchHistoryKey)
    }



    func pushPhraseBreadcrumb(_ phrase: PhraseItem) {
        pushRootBreadcrumbItem(phrase.word)
    }

    func requestDataEditDictionaryFocus() {
        dataEditFocusRequestID += 1
    }

    func requestPhraseEditFocus() {
        phraseEditFocusRequestID += 1
    }

    func rememberLastPreviewedCharacter(_ character: String?) {
        guard let character else { return }
        let key = character.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.count == 1, componentRepo.hasCharacter(key) else { return }
        preferences.set(key, forKey: lastPreviewCharacterKey)
    }

    func restoreLastPreviewedCharacterIfNeeded() {
        guard previewCharacter == nil else { return }
        guard let saved = preferences.string(forKey: lastPreviewCharacterKey) else { return }
        let key = saved.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.count == 1, componentRepo.hasCharacter(key) else { return }

        previewCharacter = key
        refreshPhrases(for: key)
        loadSharedComponentPeers(for: key)
        loadSharedPeersByComponent(for: key)
        loadRootDerivatives(for: key)
    }

    func applyImportedProfile(_ profile: UserProfile, mode: RestoreMode) {
        let isCompleteRestore = mode == .complete

        if let entries = profile.favouriteEntries, !entries.isEmpty {
            applyFavoriteEntries(entries)
        } else {
            applyFavoriteCharacters(profile.favouritesList)
        }
        persistFavorites()

        if let phraseEntries = profile.favouritePhraseEntries, !phraseEntries.isEmpty {
            applyFavoritePhraseEntries(phraseEntries)
            persistFavoritePhrases()
        } else if let phraseWords = profile.favouritePhrasesList {
            applyFavoritePhraseWords(phraseWords)
            persistFavoritePhrases()
        } else if isCompleteRestore {
            applyFavoritePhraseWords([])
            persistFavoritePhrases()
        }

        if let rememberedList = profile.rememberedList {
            applyRootBreadcrumb(rememberedList)
        } else if isCompleteRestore {
            applyRootBreadcrumb([])
        }

        if let searchHistory = profile.searchHistory {
            applySearchHistory(searchHistory)
        } else if isCompleteRestore {
            applySearchHistory([])
        }

        searchMode = SearchMode(rawValue: profile.searchMode ?? "") ?? .smart
        scriptFilter = ScriptFilter(rawValue: profile.scriptFilter ?? "") ?? .any
        if let importedRoute = AppRoute(rawValue: profile.route ?? "") {
            route = importedRoute
        } else if isCompleteRestore {
            route = .search
        }
        if let importedHomeTab = HomeTab(rawValue: profile.homeTab ?? "") {
            homeTab = importedHomeTab
        } else if isCompleteRestore {
            homeTab = .filter
        }
        if let importedSidebarStyle = SidebarNavigationStyle.fromStoredValue(profile.sidebarNavigationStyle ?? "") {
            sidebarNavigationStyle = importedSidebarStyle
        } else if isCompleteRestore {
            sidebarNavigationStyle = .descriptive
        }
        if let importedPhraseLength = profile.phraseLength, (2...7).contains(importedPhraseLength) {
            phraseLength = importedPhraseLength
        } else if isCompleteRestore {
            phraseLength = nil
        }
        if let cfg = profile.promptConfig {
            promptConfig = cfg.normalized()
        } else if isCompleteRestore {
            promptConfig = .streamlitDefault
        }
        if let selected = profile.promptSelectedTaskIDs {
            promptSelectedTaskIDs = selected
        } else if isCompleteRestore {
            promptSelectedTaskIDs = PromptConfig.defaultSelectedTaskIDs
        }
        if let aiSettings = profile.defaultAISettings {
            defaultAIPreset = aiSettings.preset
            customAIURLString = aiSettings.customURLString
        } else if isCompleteRestore {
            defaultAIPreset = .chatGPT
            customAIURLString = ""
        }
        persistPromptSettings()

        if let candidate = profile.previewCharacter, componentRepo.hasCharacter(candidate) {
            previewCharacter = candidate
            preferences.set(candidate, forKey: lastPreviewCharacterKey)
            refreshPhrases(for: candidate)
            loadSharedComponentPeers(for: candidate)
            loadSharedPeersByComponent(for: candidate)
            loadRootDerivatives(for: candidate)
        } else if isCompleteRestore {
            previewCharacter = nil
            preferences.removeObject(forKey: lastPreviewCharacterKey)
            phrases = []
            sharedComponentPeers = []
            sharedPeersByComponent = [:]
            rootDerivatives = []
            rootDerivativesTotal = 0
        }

        let restoredQuery = profile.lastSearchQuery?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let restoredQuery, !restoredQuery.isEmpty {
            query = profile.currentSearchQuery?.trimmingCharacters(in: .whitespacesAndNewlines) ?? restoredQuery
            performSearch(customQuery: restoredQuery, recordHistory: false)
        } else {
            clearSearch()
            query = profile.currentSearchQuery?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
    }

    func loadPromptSettings() {
        if preferences.object(forKey: speechEnabledKey) != nil {
            speechEnabled = preferences.bool(forKey: speechEnabledKey)
        } else if preferences.object(forKey: speakOnSelectionKey) != nil ||
                    preferences.object(forKey: speakOnPreviewKey) != nil {
            let legacySelection = preferences.bool(forKey: speakOnSelectionKey)
            let legacyPreview = preferences.bool(forKey: speakOnPreviewKey)
            speechEnabled = legacySelection || legacyPreview
        }
        if let data = preferences.data(forKey: promptConfigKey), let saved = try? JSONDecoder().decode(PromptConfig.self, from: data) { promptConfig = saved.normalized() }
        if let savedSelection = preferences.array(forKey: promptTaskSelectionKey) as? [String] { promptSelectedTaskIDs = savedSelection }
        if let rawPreset = preferences.string(forKey: defaultAIPresetKey),
           let preset = DefaultAIPreset(rawValue: rawPreset) {
            defaultAIPreset = preset
        }
        if let savedCustomURL = preferences.string(forKey: customAIURLKey) {
            customAIURLString = savedCustomURL
        }
        if let savedOpenAIAPIKey = preferences.string(forKey: openAIAPIKeyKey) {
            openAIAPIKey = savedOpenAIAPIKey
        }
        if let savedGeminiAPIKey = preferences.string(forKey: geminiAPIKeyKey) {
            geminiAPIKey = savedGeminiAPIKey
        }
        if let savedClaudeAPIKey = preferences.string(forKey: claudeAPIKeyKey) {
            claudeAPIKey = savedClaudeAPIKey
        }
        if let savedDeepSeekAPIKey = preferences.string(forKey: deepSeekAPIKeyKey) {
            deepSeekAPIKey = savedDeepSeekAPIKey
        }
        if let savedCustomAIAPIKey = preferences.string(forKey: customAIAPIKeyKey) {
            customAIAPIKey = savedCustomAIAPIKey
        }
        if let savedGeminiModelID = preferences.string(forKey: geminiModelIDKey),
           !savedGeminiModelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            geminiModelID = savedGeminiModelID
        }
    }

    func speakCharacter(_ character: String) {
        guard speechEnabled else { return }
        let target = character
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 70_000_000)
            speechService.speak(target)
        }
    }

    func speakPhrase(_ phrase: PhraseItem) {
        guard speechEnabled else { return }
        speechService.speakPhrase(phrase)
    }

    @discardableResult
    func speakCharacters(in text: String) -> Int {
        speechService.speakCharacters(in: text)
    }

    func persistPromptSettings() {
        if let data = try? JSONEncoder().encode(promptConfig) { preferences.set(data, forKey: promptConfigKey) }
        preferences.set(promptSelectedTaskIDs, forKey: promptTaskSelectionKey)
        preferences.set(defaultAIPreset.rawValue, forKey: defaultAIPresetKey)
        preferences.set(customAIURLString, forKey: customAIURLKey)
        preferences.set(openAIAPIKey, forKey: openAIAPIKeyKey)
        preferences.set(geminiAPIKey, forKey: geminiAPIKeyKey)
        preferences.set(claudeAPIKey, forKey: claudeAPIKeyKey)
        preferences.set(deepSeekAPIKey, forKey: deepSeekAPIKeyKey)
        preferences.set(customAIAPIKey, forKey: customAIAPIKeyKey)
        preferences.set(geminiModelID, forKey: geminiModelIDKey)
        updatePromptAutosaveStatus()
    }












    func mergeImportedCollections(_ importedCollections: [CharacterCollection]?, selectedAICollectionID importedSelectedID: UUID?) {
        guard let importedCollections else { return }
        var mergedByID = Dictionary(uniqueKeysWithValues: allCollections.map { ($0.id, $0) })
        for collection in sanitizeCollections(importedCollections) {
            mergedByID[collection.id] = collection
        }
        allCollections = Array(mergedByID.values)
        sortCollections()
        persistCollections()

        if let importedSelectedID, collection(id: importedSelectedID) != nil {
            selectedAICollectionID = importedSelectedID
        }
        if let selectedBrowseCollectionID, collection(id: selectedBrowseCollectionID) == nil {
            self.selectedBrowseCollectionID = nil
        }
    }

    func replaceCollections(with importedCollections: [CharacterCollection]?, selectedAICollectionID importedSelectedID: UUID?) {
        allCollections = sanitizeCollections(importedCollections ?? [])
        sortCollections()
        persistCollections()

        if let importedSelectedID, collection(id: importedSelectedID) != nil {
            selectedAICollectionID = importedSelectedID
        } else {
            selectedAICollectionID = nil
        }

        if let selectedBrowseCollectionID, collection(id: selectedBrowseCollectionID) == nil {
            self.selectedBrowseCollectionID = nil
        }
    }

    func loadDictionaryRepository() throws {
        try componentRepo.loadFromBundle()

        if FileManager.default.fileExists(atPath: dictionaryOverlayFileURL.path) {
            let data = try Data(contentsOf: dictionaryOverlayFileURL)
            let overlay = try JSONDecoder().decode(DictionaryOverlayPackage.self, from: data)
            componentRepo.applyOverlay(overlay)
        } else if FileManager.default.fileExists(atPath: legacyEditableDictionaryFileURL.path) {
            let data = try Data(contentsOf: legacyEditableDictionaryFileURL)
            let legacyMap = try JSONDecoder().decode([String: RawComponentEntry].self, from: data)
            let overlay = ComponentRepository.makeOverlay(base: componentRepo.baseRawMap, effective: legacyMap)
            componentRepo.applyOverlay(overlay)
            try persistDictionaryOverlay()
            try? FileManager.default.removeItem(at: legacyEditableDictionaryFileURL)
        }
    }

    func persistDictionaryOverlay() throws {
        dataEditSavePath = dictionaryOverlayFileURL.path
        if componentRepo.hasOverlayChanges {
            try componentRepo.saveOverlay(to: dictionaryOverlayFileURL)
        } else if FileManager.default.fileExists(atPath: dictionaryOverlayFileURL.path) {
            try FileManager.default.removeItem(at: dictionaryOverlayFileURL)
        }
    }

    func removeDictionaryOverlayFiles() throws {
        if FileManager.default.fileExists(atPath: dictionaryOverlayFileURL.path) {
            try FileManager.default.removeItem(at: dictionaryOverlayFileURL)
        }
        if FileManager.default.fileExists(atPath: legacyEditableDictionaryFileURL.path) {
            try FileManager.default.removeItem(at: legacyEditableDictionaryFileURL)
        }
    }

    var dictionaryOverlayFileURL: URL {
        if let projectURL = ProjectLiveDataLocator.file(named: "component_map_changes.json") {
            return projectURL
        }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("component_map_changes.json")
    }

    var legacyEditableDictionaryFileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("component_map_editable.json")
    }

    func emptyEntryTemplate() -> RawComponentEntry {
        RawComponentEntry(relatedCharacters: [], meta: RawMeta(variant: nil, additionalVariants: nil, pinyin: .single(""), definition: "", decomposition: "", idc: "", radical: "", strokes: .string(""), compounds: .many([]), etymology: RawEtymology(type: "", hint: .single(""), details: .single("")), notes: .many([])))
    }

    func updatePromptAutosaveStatus(now: Date = Date()) {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let savedText = formatter.localizedString(for: now, relativeTo: now)
        promptAutosaveStatus = "Changes save automatically. Last saved \(savedText)."
    }

    func sanitizeCollections(_ collections: [CharacterCollection]) -> [CharacterCollection] {
        collections.map { collection in
            var copy = collection
            copy.characters = collection.characters.filter { componentRepo.hasCharacter($0) }
            return copy
        }.filter { !$0.characters.isEmpty }
    }
}
