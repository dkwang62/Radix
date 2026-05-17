import Foundation
import SwiftUI
import Combine
import UniformTypeIdentifiers
import UIKit
#if targetEnvironment(macCatalyst)
import ApplicationServices
#endif

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

/// Toggles between grid and list views in the search results.
enum SmartResultsViewMode: String, CaseIterable, Identifiable {
    case grid = "Grid"
    case list = "List"

    var id: String { rawValue }
}

/// Primary navigation routes for the app sidebar.
enum AppRoute: String, CaseIterable, Identifiable {
    case search = "Search"
    case capture = "Capture"
    case lineage = "Lineage"
    case aiLink = "AI Link"
    case favourites = "Favourites"

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
    // MARK: - Navigation State
    @Published var route: AppRoute = .search {
        didSet {
        }
    }
    @Published var homeTab: HomeTab = .filter
    @Published var sidebarNavigationStyle: SidebarNavigationStyle = .descriptive {
        didSet { UserDefaults.standard.set(sidebarNavigationStyle.rawValue, forKey: sidebarNavigationStyleKey) }
    }
    @Published var rootsReturnContext: RootsReturnContext?
    @Published var previewCharacter: String? {
        didSet {
            rememberLastPreviewedCharacter(previewCharacter)
        }
    }
    @Published var history: [String] = []
    @Published var showLineageExplorer: Bool = false // retained for legacy, no sheet currently
    @Published var showPaywall: Bool = false
    @Published var paywallFeatureName: String = "Pro Feature"
    
    // MARK: - Search State
    @Published var query: String = ""
    @Published var searchMode: SearchMode = .smart
    @Published var scriptFilter: ScriptFilter = .any
    @Published var hasPerformedSearch: Bool = false
    @Published var lastSearchQuery: String = ""
    @Published var searchHistory: [String] = []
    
    // MARK: - DataEdit (Character Studio) State
    @Published var dataEditCharacter: String = ""
    @Published var dataEditDefinition: String = ""
    @Published var dataEditPinyin: String = ""
    @Published var dataEditDecomposition: String = ""
    @Published var dataEditRadical: String = ""
    @Published var dataEditStrokes: String = ""
    @Published var dataEditCompounds: String = ""
    @Published var dataEditEtymHint: String = ""
    @Published var dataEditEtymDetails: String = ""
    @Published var dataEditNotes: String = ""
    @Published var dataEditRelatedCharacters: String = ""
    @Published var dataEditIsFavourite: Bool = false
    @Published var dataEditPhrases: [PhraseItem] = []
    @Published var dataEditAutoSaveStatus: String = ""
    @Published private(set) var dataEditFocusRequestID: Int = 0
    @Published private(set) var phraseEditFocusRequestID: Int = 0
    @Published private(set) var phraseEditRequestedWord: String = ""
    var dataEditLoadTask: Task<Void, Never>?
    /// Cache to avoid reloading heavy entries when toggling between AI/Data.
    var dataEditCache: [String: (entry: RawComponentEntry, phrases: [PhraseItem], isFav: Bool)] = [:]
    var dataEditEtymologyType: String?
    @Published var dataEditVariant: String = ""
    @Published var dataEditAdditionalVariants: String = ""  // comma-separated
    
    // MARK: - Browsing & Filter State
    @Published var smartResultsViewMode: SmartResultsViewMode = .grid
    @Published var favoritesOnlyFilter: Bool = false
    @Published var strokeMinFilter: Int = 0 {
        didSet {
            guard oldValue != strokeMinFilter else { return }
            gridPage = 0
            scheduleGridRecompute()
        }
    }
    @Published var strokeMaxFilter: Int = 30 {
        didSet {
            // Always pin to full range; hidden in UI but kept for compatibility
            if strokeMaxFilter != 30 {
                strokeMaxFilter = 30
                return
            }
            guard oldValue != strokeMaxFilter else { return }
            gridPage = 0
            scheduleGridRecompute()
        }
    }
    @Published var selectedRadicalFilter: String = "none" {
        didSet {
            guard oldValue != selectedRadicalFilter else { return }
            gridPage = 0
            scheduleGridRecompute()
        }
    }
    @Published var selectedStructureFilter: String = "none" {
        didSet {
            guard oldValue != selectedStructureFilter else { return }
            gridPage = 0
            scheduleGridRecompute()
        }
    }
    // Roots-specific filters
    @Published var rootMinStroke: Int = 0 {
        didSet {
            guard oldValue != rootMinStroke else { return }
            if let current = previewCharacter {
                loadSharedComponentPeers(for: current)
                loadSharedPeersByComponent(for: current)
                loadRootDerivatives(for: current)
            }
        }
    }
    @Published var rootMaxStroke: Int = 30 {
        didSet {
            if rootMaxStroke < 0 {
                rootMaxStroke = 0
                return
            }
            if rootMaxStroke > 30 {
                rootMaxStroke = 30
                return
            }
            guard oldValue != rootMaxStroke else { return }
            if let current = previewCharacter {
                loadSharedComponentPeers(for: current)
                loadSharedPeersByComponent(for: current)
                loadRootDerivatives(for: current)
            }
        }
    }
    @Published var rootRadicalFilter: String = "none" {
        didSet {
            guard oldValue != rootRadicalFilter else { return }
            if let current = previewCharacter {
                loadSharedComponentPeers(for: current)
                loadSharedPeersByComponent(for: current)
                loadRootDerivatives(for: current)
            }
        }
    }
    @Published var rootStructureFilter: String = "none" {
        didSet {
            guard oldValue != rootStructureFilter else { return }
            if let current = previewCharacter {
                loadSharedComponentPeers(for: current)
                loadSharedPeersByComponent(for: current)
                loadRootDerivatives(for: current)
            }
        }
    }
    // Remembered bar state. The older rootBreadcrumb name is retained because
    // routing and saved behavior were built around that identifier.
    @Published var rootBreadcrumb: [String] = []
    @Published var rootBreadcrumbIndex: Int = 0
    @Published var rootDerivatives: [ComponentItem] = []
    @Published var rootDerivativesTotal: Int = 0
    @Published var availableRadicalFilters: [String] = ["none"]
    @Published var availableStructureFilters: [String] = ["none"]
    @Published var gridSortMode: GridSortMode = .characterFrequency {
        didSet {
            guard oldValue != gridSortMode else { return }
            gridPage = 0
            scheduleGridRecompute()
        }
    }
    @Published var gridScriptFilter: ScriptFilter = .any {
        didSet {
            guard oldValue != gridScriptFilter else { return }
            gridPage = 0
            scheduleGridRecompute()
        }
    }
    @Published var selectedBrowseCollectionID: UUID? = nil {
        didSet {
            guard oldValue != selectedBrowseCollectionID else { return }
            selectedBrowseCollectionCharacters = selectedBrowseCollectionID.flatMap { collection(id: $0).map { Set($0.characters) } }
            clearBrowseMemoryHighlight()
            if selectedBrowseCollectionID != nil {
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
    @Published var selectedAICollectionID: UUID? = nil {
        didSet {
            guard oldValue != selectedAICollectionID else { return }
            persistSelectedAICollection()
        }
    }
    @Published var gridFilteredAllCount: Int = 0
    @Published var gridFilteredComponentCount: Int = 0
    @Published var gridPage: Int = 0
    @Published var allGridItems: [ComponentItem] = []
    @Published var allReadingOrderCharacters: [String] = []
    
    // MARK: - Computed Result Sets
    @Published var results: [ComponentItem] = []
    @Published var definitionCharacterResults: [ComponentItem] = []
    @Published var definitionPhraseResults: [PhraseItem] = []
    @Published var smartPhraseResults: [PhraseItem] = []
    @Published var lineageParents: [ComponentItem] = []
    @Published var lineageDerivatives: [ComponentItem] = []
    @Published var sortedLineageDerivatives: [ComponentItem] = []
    @Published var phoneticFamily: [ComponentItem] = []
    @Published var semanticFamily: [ComponentItem] = []
    @Published var structureAnalysis: ComponentStructureAnalysis?
    @Published var lineageSortMode: LineageSortMode = .usage
    @Published var lineagePage: Int = 0
    @Published var related: [ComponentItem] = []
    @Published var phrases: [PhraseItem] = []
    @Published var phraseLength: Int? = nil
    @Published var sharedComponentPeers: [ComponentItem] = []
    @Published var sharedPeersByComponent: [String: [ComponentItem]] = [:]
    @Published var addedPhrases: [PhraseItem] = []
    
    // MARK: - User Settings & Variances
    @Published var favorites: Set<String> = []
    @Published var favoriteAddedDates: [String: Date] = [:]
    @Published var favoritePhrases: Set<String> = []
    @Published var favoritePhraseDates: [String: Date] = [:]
    @Published var overlayAddedDates: [String: Date] = [:]
    @Published var speechEnabled: Bool = true {
        didSet { UserDefaults.standard.set(speechEnabled, forKey: speechEnabledKey) }
    }
    @Published var activeFavouriteCharacter: String? = nil
    @Published var dictionaryVariances: [DictionaryVariance] = []
    @Published var phraseVariances: [DictionaryVariance] = []
    @Published var addedDictionaryCharacters: [String] = []
    @Published var editedDictionaryCharacters: [String] = []
    @Published var baseDictionaryCoreEditedCharacters: [String] = []
    @Published var dictionaryCharactersWithNotes: [String] = []
    /// O(1) lookup companion for `editedDictionaryCharacters`. Always kept in sync.
    @Published var editedDictionaryCharactersSet: Set<String> = []
    @Published var changedDictionaryCharacters: [String] = []
    @Published var quickEditDestination: QuickEditDestination? = nil
    @Published var allCollections: [CharacterCollection] = []
    @Published var activeSubject: ActiveSubject? = nil
    @Published var promptAutosaveStatus: String = "Changes save automatically."
    
    // MARK: - iPhone UI State
    @Published var showiPhoneDetail: Bool = false
    
    // MARK: - AI Context State
    @Published var promptConfig: PromptConfig = .streamlitDefault
    @Published var promptSelectedTaskIDs: [String] = PromptConfig.defaultSelectedTaskIDs
    @Published var shouldAutoOpenAILinkTask4 = false
    @Published var shouldAutoRunGeminiPhraseAPI = false
    @Published var defaultAIPreset: DefaultAIPreset = .chatGPT {
        didSet { persistPromptSettings() }
    }
    @Published var customAIURLString: String = "" {
        didSet { persistPromptSettings() }
    }
    @Published var openAIAPIKey: String = "" {
        didSet { persistPromptSettings() }
    }
    @Published var geminiAPIKey: String = "" {
        didSet { persistPromptSettings() }
    }
    @Published var claudeAPIKey: String = "" {
        didSet { persistPromptSettings() }
    }
    @Published var deepSeekAPIKey: String = "" {
        didSet { persistPromptSettings() }
    }
    @Published var customAIAPIKey: String = "" {
        didSet { persistPromptSettings() }
    }
    @Published var geminiModelID: String = "gemini-2.5-flash-lite" {
        didSet { persistPromptSettings() }
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
    var imagePhraseContext: ImagePhraseContext?
    var imagePhraseHighlightOffsets: Set<Int> = []
    // Keep phrase-origin highlight state in the store, not in Browse UI views.
    // iPhone phrase previews can drill into component characters; when returning
    // to Browse, this anchor restores the original full phrase highlight instead
    // of leaving the last previewed character highlighted. Future refactors should
    // preserve this store-level ownership so layout/navigation changes do not
    // break phrase highlighting.
    var anchoredImagePhraseContext: ImagePhraseContext?
    var anchoredImagePhraseHighlightOffsets: Set<Int> = []
    var anchoredImagePhraseWord: String?
    var anchoredImagePhraseCollectionID: UUID?
    var imagePhraseHighlightStateByCollectionID: [UUID: ImagePhraseHighlightState] = [:]
    @Published var imagePhraseHighlightRevision: Int = 0
    @Published var imageBrowsePhrasePreview: PhraseItem?
    @Published var sidebarPhrasePreview: PhraseItem?
    @Published var pendingBrowseScrollTarget: BrowseScrollTarget?
    @Published var browseHighlightedCharacter: String?
    @Published var browseMemoryHighlightCollectionID: UUID?
    @Published var browseMemoryHighlightOffsets: Set<Int> = []
    var browseMemoryHighlightedItem: String?
    let imagePhraseHighlightLengths = [2, 3, 4]
    var suppressHelpReset = false
    @Published private(set) var loadingError: String?
    @Published private(set) var dataEditSavePath: String = ""
    @Published var addPhrasesPath: String = ""
    @Published var showBrowseHelp: Bool = true
    @Published var showComponentHelp: Bool = true
    @Published var activeCaptureDraft = CaptureDraft()

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
        if rootBreadcrumb.isEmpty {
            seedBreadcrumbFromFavorites()
        }
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
        showLineageExplorer = false
        showBrowseHelp = true
        showComponentHelp = true
        
        previewCharacter = nil
        showiPhoneDetail = false
    }

    func loadSidebarNavigationStyle() {
        if let saved = UserDefaults.standard.string(forKey: sidebarNavigationStyleKey),
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
        #if targetEnvironment(macCatalyst)
        return 225
        #else
        return 12
        #endif
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
        guard let saved = UserDefaults.standard.array(forKey: searchHistoryKey) as? [String] else { return }
        searchHistory = saved
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    func appendSearchHistory(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        searchHistory.append(trimmed)
        UserDefaults.standard.set(searchHistory, forKey: searchHistoryKey)
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
        UserDefaults.standard.set(key, forKey: lastPreviewCharacterKey)
    }

    func restoreLastPreviewedCharacterIfNeeded() {
        guard previewCharacter == nil else { return }
        guard let saved = UserDefaults.standard.string(forKey: lastPreviewCharacterKey) else { return }
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
            if rootBreadcrumb.isEmpty {
                seedBreadcrumbFromFavorites()
            }
        } else if rootBreadcrumb.isEmpty {
            seedBreadcrumbFromFavorites()
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
            UserDefaults.standard.set(candidate, forKey: lastPreviewCharacterKey)
            refreshPhrases(for: candidate)
            loadSharedComponentPeers(for: candidate)
            loadSharedPeersByComponent(for: candidate)
            loadRootDerivatives(for: candidate)
        } else if isCompleteRestore {
            previewCharacter = nil
            UserDefaults.standard.removeObject(forKey: lastPreviewCharacterKey)
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
        if UserDefaults.standard.object(forKey: speechEnabledKey) != nil {
            speechEnabled = UserDefaults.standard.bool(forKey: speechEnabledKey)
        } else if UserDefaults.standard.object(forKey: speakOnSelectionKey) != nil ||
                    UserDefaults.standard.object(forKey: speakOnPreviewKey) != nil {
            let legacySelection = UserDefaults.standard.bool(forKey: speakOnSelectionKey)
            let legacyPreview = UserDefaults.standard.bool(forKey: speakOnPreviewKey)
            speechEnabled = legacySelection || legacyPreview
        }
        if let data = UserDefaults.standard.data(forKey: promptConfigKey), let saved = try? JSONDecoder().decode(PromptConfig.self, from: data) { promptConfig = saved.normalized() }
        if let savedSelection = UserDefaults.standard.array(forKey: promptTaskSelectionKey) as? [String] { promptSelectedTaskIDs = savedSelection }
        if let rawPreset = UserDefaults.standard.string(forKey: defaultAIPresetKey),
           let preset = DefaultAIPreset(rawValue: rawPreset) {
            defaultAIPreset = preset
        }
        if let savedCustomURL = UserDefaults.standard.string(forKey: customAIURLKey) {
            customAIURLString = savedCustomURL
        }
        if let savedOpenAIAPIKey = UserDefaults.standard.string(forKey: openAIAPIKeyKey) {
            openAIAPIKey = savedOpenAIAPIKey
        }
        if let savedGeminiAPIKey = UserDefaults.standard.string(forKey: geminiAPIKeyKey) {
            geminiAPIKey = savedGeminiAPIKey
        }
        if let savedClaudeAPIKey = UserDefaults.standard.string(forKey: claudeAPIKeyKey) {
            claudeAPIKey = savedClaudeAPIKey
        }
        if let savedDeepSeekAPIKey = UserDefaults.standard.string(forKey: deepSeekAPIKeyKey) {
            deepSeekAPIKey = savedDeepSeekAPIKey
        }
        if let savedCustomAIAPIKey = UserDefaults.standard.string(forKey: customAIAPIKeyKey) {
            customAIAPIKey = savedCustomAIAPIKey
        }
        if let savedGeminiModelID = UserDefaults.standard.string(forKey: geminiModelIDKey),
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
        if let data = try? JSONEncoder().encode(promptConfig) { UserDefaults.standard.set(data, forKey: promptConfigKey) }
        UserDefaults.standard.set(promptSelectedTaskIDs, forKey: promptTaskSelectionKey)
        UserDefaults.standard.set(defaultAIPreset.rawValue, forKey: defaultAIPresetKey)
        UserDefaults.standard.set(customAIURLString, forKey: customAIURLKey)
        UserDefaults.standard.set(openAIAPIKey, forKey: openAIAPIKeyKey)
        UserDefaults.standard.set(geminiAPIKey, forKey: geminiAPIKeyKey)
        UserDefaults.standard.set(claudeAPIKey, forKey: claudeAPIKeyKey)
        UserDefaults.standard.set(deepSeekAPIKey, forKey: deepSeekAPIKeyKey)
        UserDefaults.standard.set(customAIAPIKey, forKey: customAIAPIKeyKey)
        UserDefaults.standard.set(geminiModelID, forKey: geminiModelIDKey)
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
