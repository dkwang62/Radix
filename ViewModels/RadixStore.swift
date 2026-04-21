import Foundation
import SwiftUI
import Combine
import UniformTypeIdentifiers
import UIKit
import AVFoundation

/*
 CHARACTER STUDIO ARCHITECTURE (RadixStore)
 =========================================
 RadixStore acts as the central state engine for the application. It manages the
 "Single Source of Truth" for search, navigation, and the Character Studio.
 
 THE VIRTUAL FILE CONCEPT:
 This store unifies three distinct data backends into a single cohesive experience:
 1. Dictionary (JSON): Foundational character data (radical, strokes, etymology).
 2. Phrases (SQLite): High-performance multi-character word database.
 3. User Data (Settings): Personal Favourites and AI Prompt configurations.
 
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

/// Sorting modes for the discovery grid.
enum GridSortMode: String, CaseIterable, Identifiable {
    case componentFrequency = "Components"
    case characterFrequency = "All"

    var id: String { rawValue }
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
final class CharacterSpeechCoordinator {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        synthesizer.stopSpeaking(at: .immediate)

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = preferredVoice()
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        utterance.prefersAssistiveTechnologySettings = true
        synthesizer.speak(utterance)
    }

    private func preferredVoice() -> AVSpeechSynthesisVoice? {
        for language in ["zh-CN", "zh-TW", "zh-HK"] {
            if let voice = AVSpeechSynthesisVoice(language: language) {
                return voice
            }
        }

        return AVSpeechSynthesisVoice(language: Locale.preferredLanguages.first ?? Locale.current.identifier)
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
            #if !targetEnvironment(macCatalyst)
            if UIDevice.current.userInterfaceIdiom == .phone {
                // iPhone: preview should only appear after explicit tap/preview action.
                return
            }
            #endif
            // iPad/Mac: keep preview aligned to selection when switching modes.
            if let sel = selectedCharacter { previewCharacter = sel }
            else { previewCharacter = nil }
        }
    }
    @Published var homeTab: HomeTab = .filter
    @Published var selectedCharacter: String? {
        didSet {
            rememberLastPreviewedCharacter(selectedCharacter)
        }
    }
    @Published var previewCharacter: String? {
        didSet {
            rememberLastPreviewedCharacter(previewCharacter)
        }
    }
    @Published private(set) var history: [String] = []
    @Published var showLineageExplorer: Bool = false // retained for legacy, no sheet currently
    @Published var showPaywall: Bool = false
    @Published var paywallFeatureName: String = "Pro Feature"
    
    // MARK: - Search State
    @Published var query: String = ""
    @Published var searchMode: SearchMode = .smart
    @Published var scriptFilter: ScriptFilter = .any
    @Published var hasPerformedSearch: Bool = false
    @Published private(set) var lastSearchQuery: String = ""
    
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
    @Published var dataEditRelatedCharacters: String = ""
    @Published var dataEditIsFavourite: Bool = false
    @Published var dataEditPhrases: [PhraseItem] = []
    @Published private(set) var dataEditAutoSaveStatus: String = ""
    @Published private(set) var dataEditFocusRequestID: Int = 0
    @Published private(set) var phraseEditFocusRequestID: Int = 0
    @Published private(set) var phraseEditRequestedWord: String = ""
    private var dataEditLoadTask: Task<Void, Never>?
    /// Cache to avoid reloading heavy entries when toggling between AI/Data.
    private var dataEditCache: [String: (entry: RawComponentEntry, phrases: [PhraseItem], isFav: Bool)] = [:]
    private var dataEditEtymologyType: String?
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
            if let current = selectedCharacter ?? previewCharacter {
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
            if let current = selectedCharacter ?? previewCharacter {
                loadSharedComponentPeers(for: current)
                loadSharedPeersByComponent(for: current)
                loadRootDerivatives(for: current)
            }
        }
    }
    @Published var rootRadicalFilter: String = "none" {
        didSet {
            guard oldValue != rootRadicalFilter else { return }
            if let current = selectedCharacter ?? previewCharacter {
                loadSharedComponentPeers(for: current)
                loadSharedPeersByComponent(for: current)
                loadRootDerivatives(for: current)
            }
        }
    }
    @Published var rootStructureFilter: String = "none" {
        didSet {
            guard oldValue != rootStructureFilter else { return }
            if let current = selectedCharacter ?? previewCharacter {
                loadSharedComponentPeers(for: current)
                loadSharedPeersByComponent(for: current)
                loadRootDerivatives(for: current)
            }
        }
    }
    // Breadcrumb for Roots/Components Explorer
    @Published private(set) var rootBreadcrumb: [String] = []
    @Published private(set) var rootBreadcrumbIndex: Int = 0
    @Published private(set) var rootDerivatives: [ComponentItem] = []
    @Published private(set) var rootDerivativesTotal: Int = 0
    @Published private(set) var availableRadicalFilters: [String] = ["none"]
    @Published private(set) var availableStructureFilters: [String] = ["none"]
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
    @Published private(set) var gridFilteredAllCount: Int = 0
    @Published private(set) var gridFilteredComponentCount: Int = 0
    @Published var gridPage: Int = 0
    @Published private(set) var allGridItems: [ComponentItem] = []
    
    // MARK: - Computed Result Sets
    @Published private(set) var results: [ComponentItem] = []
    @Published private(set) var definitionCharacterResults: [ComponentItem] = []
    @Published private(set) var definitionPhraseResults: [PhraseItem] = []
    @Published private(set) var smartPhraseResults: [PhraseItem] = []
    @Published private(set) var lineageParents: [ComponentItem] = []
    @Published private(set) var lineageDerivatives: [ComponentItem] = []
    @Published private(set) var sortedLineageDerivatives: [ComponentItem] = []
    @Published private(set) var phoneticFamily: [ComponentItem] = []
    @Published private(set) var semanticFamily: [ComponentItem] = []
    @Published private(set) var structureAnalysis: ComponentStructureAnalysis?
    @Published var lineageSortMode: LineageSortMode = .usage
    @Published var lineagePage: Int = 0
    @Published private(set) var related: [ComponentItem] = []
    @Published private(set) var phrases: [PhraseItem] = []
    @Published var phraseLength: Int = 2
    @Published private(set) var sharedComponentPeers: [ComponentItem] = []
    @Published private(set) var sharedPeersByComponent: [String: [ComponentItem]] = [:]
    @Published private(set) var addedPhrases: [PhraseItem] = []
    
    // MARK: - User Settings & Variances
    @Published private(set) var favorites: Set<String> = []
    @Published private(set) var favoriteAddedDates: [String: Date] = [:]
    @Published private(set) var favoritePhrases: Set<String> = []
    @Published private(set) var favoritePhraseDates: [String: Date] = [:]
    @Published private(set) var overlayAddedDates: [String: Date] = [:]
    @Published var speechEnabled: Bool = true {
        didSet { UserDefaults.standard.set(speechEnabled, forKey: speechEnabledKey) }
    }
    @Published var activeFavouriteCharacter: String? = nil
    @Published private(set) var dictionaryVariances: [DictionaryVariance] = []
    @Published private(set) var phraseVariances: [DictionaryVariance] = []
    @Published private(set) var addedDictionaryCharacters: [String] = []
    @Published private(set) var editedDictionaryCharacters: [String] = []
    /// O(1) lookup companion for `editedDictionaryCharacters`. Always kept in sync.
    @Published private(set) var editedDictionaryCharactersSet: Set<String> = []
    @Published private(set) var changedDictionaryCharacters: [String] = []
    @Published var quickEditDestination: QuickEditDestination? = nil
    
    // MARK: - iPhone UI State
    @Published var showiPhoneDetail: Bool = false
    
    // MARK: - AI Context State
    @Published var promptConfig: PromptConfig = .streamlitDefault
    @Published var promptSelectedTaskIDs: [String] = PromptConfig.streamlitDefault.tasks.map(\.id)

    // MARK: - Repositories & Helpers
    private let componentRepo = ComponentRepository()
    private let phraseRepo = PhraseRepository()
    private let entitlement = EntitlementManager()
    private let speechCoordinator = CharacterSpeechCoordinator()
    private let favoritesKey = "radix.favorites"
    private let favoriteEntriesKey = "radix.favoriteEntries"
    private let favoritePhrasesKey = "radix.favoritePhrases"
    private let favoritePhraseDatesKey = "radix.favoritePhraseDates"
    private let overlayAddedDatesKey = "radix.overlayAddedDates"
    private let speechEnabledKey = "radix.speechEnabled"
    private let speakOnSelectionKey = "radix.speakOnSelection"
    private let speakOnPreviewKey = "radix.speakOnPreview"
    private let promptConfigKey = "radix.promptConfig"
    private let promptTaskSelectionKey = "radix.promptSelectedTaskIDs"
    private let lastPreviewCharacterKey = "radix.lastPreviewCharacter"
    private var pendingSearchWorkItem: DispatchWorkItem?
    private var pendingDatasetAutosaveWorkItem: DispatchWorkItem?
    private var pendingGridRecomputeWorkItem: DispatchWorkItem?
    private var isApplyingDatasetEntry = false
    private var allCharactersCache: [ComponentItem] = []
    private var phraseCache: [String: [PhraseItem]] = [:]
    private var lastPreviewTap: (character: String, time: Date)?
    var suppressHelpReset = false
    @Published private(set) var loadingError: String?
    @Published private(set) var dataEditSavePath: String = ""
    @Published private(set) var addPhrasesPath: String = ""
    @Published var showBrowseHelp: Bool = true
    @Published var showComponentHelp: Bool = true

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
        loadPromptSettings()
        promptConfig = promptConfig.normalized()
        if promptSelectedTaskIDs.isEmpty {
            promptSelectedTaskIDs = promptConfig.tasks.map(\.id)
        }
        loadFavorites()
        seedBreadcrumbFromFavorites()
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
        
        // Start with no preselected character unless we can restore the last preview
        selectedCharacter = nil
        previewCharacter = nil
        restoreLastPreviewedCharacterIfNeeded()
        showiPhoneDetail = false
    }

    // MARK: - Search & Navigation
    
    func performSearch(customQuery: String? = nil) {
        let targetQuery = customQuery ?? query
        let trimmed = targetQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            clearSearch()
            return
        }

        hasPerformedSearch = true
        lastSearchQuery = trimmed

        // Detect Exact English:
        // 1. Starts with '=' (e.g. =car)
        // 2. Enclosed in quotes (straight or curly)
        let hasEqualPrefix = trimmed.hasPrefix("=")
        let hasQuotes = (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) ||
                        (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) ||
                        (trimmed.hasPrefix("‘") && trimmed.hasSuffix("’")) ||
                        (trimmed.hasPrefix("“") && trimmed.hasSuffix("”"))
        
        let isForcedEnglish = hasEqualPrefix || hasQuotes
        
        let searchQuery: String = {
            if hasEqualPrefix {
                return String(trimmed.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if hasQuotes {
                return String(trimmed.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return trimmed
        }()

        switch searchMode {
        case .smart:
            if isForcedEnglish {
                results = componentRepo.searchDefinitions(query: searchQuery, scriptFilter: .any, isStrict: true)
                smartPhraseResults = phraseRepo.searchByDefinition(term: searchQuery, isStrict: true)
                definitionCharacterResults = []
                definitionPhraseResults = []
            } else {
                results = componentRepo.search(query: searchQuery, scriptFilter: .any)
                let meaningPhrases = searchQuery.count >= 2
                    ? phraseRepo.searchByDefinition(term: searchQuery)
                    : []
                let pinyinPhrases = normalizedCompactQuery(searchQuery).count > 2
                    ? phraseRepo.searchByPinyin(term: searchQuery)
                    : []
                smartPhraseResults = mergePhraseResults(primary: meaningPhrases, secondary: pinyinPhrases)
                definitionCharacterResults = []
                definitionPhraseResults = []
            }
        case .definition:
            definitionCharacterResults = componentRepo.searchDefinitions(query: searchQuery, scriptFilter: .any, isStrict: isForcedEnglish)
            definitionPhraseResults = phraseRepo.searchByDefinition(term: searchQuery, isStrict: isForcedEnglish)
            smartPhraseResults = []
            results = []
        }
        
        if customQuery == nil {
            query = ""
        }
    }

    func clearSearch() {
        results = []
        smartPhraseResults = []
        definitionCharacterResults = []
        definitionPhraseResults = []
        hasPerformedSearch = false
    }

    func showPaywall(for feature: EntitlementManager.FeatureGate) {
        paywallFeatureName = feature.rawValue
        showPaywall = true
    }

    var speechMenuSymbolName: String {
        if speechEnabled {
            return "speaker.wave.2"
        }
        return "speaker.slash"
    }

    func select(character: String, announce: Bool = true) {
        let trimmedCharacter = character.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedCharacter.count == 1 else { return }

        // 1. Instant UI update for selection
        selectedCharacter = trimmedCharacter
        previewCharacter = trimmedCharacter
        #if targetEnvironment(macCatalyst)
        showiPhoneDetail = true
        #else
        if UIDevice.current.userInterfaceIdiom == .phone {
            if route == .lineage || route == .search {
                // Roots or Search tabs: keep user in the tab (no navigation push)
                showiPhoneDetail = false
            } else {
                showiPhoneDetail = true
            }
        } else {
            showiPhoneDetail = true
        }
        #endif
        if !suppressHelpReset {
            showBrowseHelp = false
            showComponentHelp = false
        }
        pushRootBreadcrumb(trimmedCharacter)
        
        // 2. Clear previous data instantly to prevent showing old info
        phrases = []
        related = []
        lineageParents = []
        lineageDerivatives = []
        
        // 3. Load heavy data in background to prevent sluggishness
        Task {
            let derivatives = componentRepo.related(for: trimmedCharacter, scriptFilter: scriptFilter)
            let parents = componentRepo.components(for: trimmedCharacter, scriptFilter: scriptFilter)
            let phonetic = componentRepo.pronunciationFamily(for: trimmedCharacter).compactMap { componentRepo.byCharacter[$0] }
            let semantic = componentRepo.semanticFamily(for: trimmedCharacter).compactMap { componentRepo.byCharacter[$0] }
            let analysis = componentRepo.analyzeStructure(for: trimmedCharacter)
            
            await MainActor.run {
                // Ensure we are still on the same character before applying results
                guard selectedCharacter == trimmedCharacter else { return }
                
                self.lineageParents = parents
                self.lineageDerivatives = derivatives
                self.sortedLineageDerivatives = derivatives.sorted(by: frequencySortPredicate)
                self.phoneticFamily = phonetic
                self.semanticFamily = semantic
                self.structureAnalysis = analysis
                self.lineagePage = 0
                self.related = derivatives
                
                self.refreshPhrases(for: trimmedCharacter)
            }
        }

        // Roots data should reflect the selected character (not previews)
        loadSharedComponentPeers(for: trimmedCharacter)
        loadSharedPeersByComponent(for: trimmedCharacter)
        loadRootDerivatives(for: trimmedCharacter)
        // Breadcrumbs track explicit selections globally.

        if announce && speechEnabled {
            speechCoordinator.speak(trimmedCharacter)
        }
    }

    func preview(character: String, announce: Bool = true) {
        // Two quick previews on the same character count as a selection (double-click alternative)
        let now = Date()
        if let last = lastPreviewTap, last.character == character, now.timeIntervalSince(last.time) < 0.8 {
            lastPreviewTap = nil
            select(character: character, announce: announce)
            return
        } else {
            lastPreviewTap = (character, now)
        }

        #if targetEnvironment(macCatalyst)
        // Mac: Keep distinction
        previewCharacter = character
        refreshPhrases()
        if homeTab == .dataEdit {
            loadDataEditEntry(for: character)
        }
        showiPhoneDetail = true
        #else
        if UIDevice.current.userInterfaceIdiom == .phone {
            // iPhone: Stay within current tab without pushing legacy views
            if route == .search {
                // Both Smart Search and Browse tabs should keep user in place
                browsePreview(character: character, announce: announce)
            } else if route == .lineage {
                // Roots tab: preview only; do not push detail or breadcrumb
                previewCharacter = character
                refreshPhrases(for: character)
                showiPhoneDetail = false
            } else if route == .aiLink || route == .favourites {
                // AI Link and Favourites should preview in-place and let the
                // shared header handle promotion to a selection.
                previewCharacter = character
                refreshPhrases(for: character)
                showiPhoneDetail = false
            } else {
                // Other tabs: behave like select (opens detail)
                select(character: character)
            }
        } else {
            // iPad: Keep distinction (Desktop-like)
            previewCharacter = character
            refreshPhrases()
            if homeTab == .dataEdit {
                loadDataEditEntry(for: character)
            }
            showiPhoneDetail = true
        }
        #endif

        if announce && speechEnabled {
            speechCoordinator.speak(character)
        }
    }

    /// iPhone Browse: preview without pushing detail
    func browsePreview(character: String, announce: Bool = true) {
        previewCharacter = character
        showiPhoneDetail = false
        // Lightweight refresh for preview context
        refreshPhrases(for: character)
        showBrowseHelp = false
        showComponentHelp = false

        if announce && speechEnabled {
            speechCoordinator.speak(character)
        }
    }

    func enterLineage() {
        if let target = previewCharacter ?? selectedCharacter {
            if let selectedCharacter, selectedCharacter != target {
                history.append(selectedCharacter)
            }
            select(character: target)
        } else {
            // Allow opening Roots with no selection to show empty-state card
            previewCharacter = nil
            selectedCharacter = nil
        }
        route = .lineage
        showComponentHelp = true
        #if !targetEnvironment(macCatalyst)
        if UIDevice.current.userInterfaceIdiom == .phone {
            showiPhoneDetail = false
        }
        #endif
    }

    func enterAILink() {
        if let target = previewCharacter ?? selectedCharacter {
            if selectedCharacter != target {
                select(character: target)
            }
        } else {
            previewCharacter = nil
            selectedCharacter = nil
        }
        route = .aiLink
    }

    func goToAILink(character: String) {
        select(character: character, announce: false)
        route = .aiLink
        #if !targetEnvironment(macCatalyst)
        if UIDevice.current.userInterfaceIdiom == .phone {
            showiPhoneDetail = false
        }
        #endif
    }

    func goToSearchRoot() {
        route = .search
        homeTab = .smart
        activeFavouriteCharacter = nil
        restoreLastPreviewedCharacterIfNeeded()
    }

    func goToFavourites() {
        route = .favourites
        activeFavouriteCharacter = nil
    }

    func goToBrowse() {
        route = .search
        homeTab = .filter
        gridSortMode = .characterFrequency
        activeFavouriteCharacter = nil
        showBrowseHelp = true
        showComponentHelp = false
        restoreLastPreviewedCharacterIfNeeded()
    }

    func goToDataEdit() {
        route = .search
        homeTab = .dataEdit
        startBlankDataEdit()
        requestDataEditDictionaryFocus()
    }

    func goToRoots(character: String) {
        select(character: character, announce: false)
        route = .lineage
        showComponentHelp = true
        #if !targetEnvironment(macCatalyst)
        if UIDevice.current.userInterfaceIdiom == .phone {
            showiPhoneDetail = false
        }
        #endif
    }

    func openQuickCharacterEditor(_ character: String) {
        let trimmed = character.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 1 else { return }
        select(character: trimmed, announce: false)
        loadDataEditEntry(for: trimmed)
        quickEditDestination = .character(trimmed)
    }

    func openNewCharacterEditor() {
        quickEditDestination = .newCharacter
    }

    func openQuickPhraseEditor(word: String) {
        let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedWord.isEmpty else { return }
        quickEditDestination = .phrase(simplifiedText(trimmedWord))
    }

    func openNewPhraseEditor() {
        quickEditDestination = .newPhrase
    }

    func selectFavouriteCharacter(_ character: String) {
        activeFavouriteCharacter = character
        preview(character: character)
    }

    func isTraditional(_ character: String) -> Bool {
        componentRepo.isTraditionalForGrid(character)
    }

    func isSimplified(_ character: String) -> Bool {
        componentRepo.isSimplifiedForGrid(character)
    }

    func goBack() {
        if route == .aiLink { route = .lineage; return }
        if route == .favourites { route = .search; return }
        if route == .lineage { route = .search; return }
        if let previous = history.popLast() {
            select(character: previous)
            route = .lineage
        } else {
            route = .search
        }
    }

    func refreshPhrases(for char: String? = nil) {
        let target = char ?? previewCharacter ?? selectedCharacter
        guard let targetToLoad = target else {
            phrases = []
            return
        }
        
        let length = phraseLength
        let cacheKey = "\(targetToLoad)|\(length)"
        
        if let cached = phraseCache[cacheKey] {
            phrases = cached
            return
        }
        
        // Run database query in background to prevent sluggishness
        Task {
            let primary = phraseRepo.phrases(containing: targetToLoad, length: length)
            let counterpart = componentRepo.counterpart(for: targetToLoad)
            
            var finalPhrases: [PhraseItem] = primary
            
            if let counterpart, counterpart != targetToLoad {
                let secondary = phraseRepo.phrases(containing: counterpart, length: length)
                var seen = Set<String>(primary.map { $0.id })
                for phrase in secondary {
                    if !seen.contains(phrase.id) {
                        seen.insert(phrase.id)
                        finalPhrases.append(phrase)
                    }
                }
            }
            
            let result = finalPhrases.sorted(by: phrasePinyinSortPredicate)
            await MainActor.run {
                // Ensure we are still looking at the same character/length before updating
                if (char ?? previewCharacter ?? selectedCharacter) == targetToLoad && phraseLength == length {
                    self.phrases = result
                    self.phraseCache[cacheKey] = result
                }
            }
        }
    }

    func phraseMatches(for character: String, length: Int? = nil) -> [PhraseItem] {
        let targetToLoad = character.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !targetToLoad.isEmpty else { return [] }

        let phraseLength = length ?? self.phraseLength
        let cacheKey = "\(targetToLoad)|\(phraseLength)"
        if let cached = phraseCache[cacheKey] {
            return cached
        }

        let primary = phraseRepo.phrases(containing: targetToLoad, length: phraseLength)
        let counterpart = componentRepo.counterpart(for: targetToLoad)
        var finalPhrases = primary

        if let counterpart, counterpart != targetToLoad {
            let secondary = phraseRepo.phrases(containing: counterpart, length: phraseLength)
            var seen = Set<String>(primary.map { $0.id })
            for phrase in secondary where !seen.contains(phrase.id) {
                seen.insert(phrase.id)
                finalPhrases.append(phrase)
            }
        }

        let result = finalPhrases.sorted(by: phrasePinyinSortPredicate)
        phraseCache[cacheKey] = result
        return result
    }

    func isPhraseInBase(_ word: String) -> Bool {
        phraseRepo.isInBase(word: word)
    }

    func isPhraseInAdd(_ word: String) -> Bool {
        phraseRepo.isInAdd(word: word)
    }

    func mergedPhrase(for word: String) -> PhraseItem? {
        let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedWord.isEmpty else { return nil }
        return phraseRepo.fetchPhrase(for: trimmedWord)
    }

    func simplifiedText(_ value: String) -> String {
        componentRepo.simplifiedText(value)
    }

    var favoriteItems: [ComponentItem] {
        favorites.compactMap { componentRepo.byCharacter[$0] }
            .sorted {
                let lhsDate = favoriteAddedDates[$0.character]
                let rhsDate = favoriteAddedDates[$1.character]

                switch (lhsDate, rhsDate) {
                case let (lhs?, rhs?):
                    if lhs != rhs { return lhs > rhs }
                case (.some, nil):
                    return true
                case (nil, .some):
                    return false
                case (nil, nil):
                    break
                }

                return $0.character < $1.character
            }
    }

    /// Favorited phrases sorted by date added (most recent first).
    var favoritePhrasesItems: [PhraseItem] {
        phraseRepo.fetchPhrases(matching: favoritePhrases)
            .sorted {
                let l = favoritePhraseDates[$0.word]
                let r = favoritePhraseDates[$1.word]
                switch (l, r) {
                case let (lhs?, rhs?): return lhs > rhs
                case (.some, nil): return true
                case (nil, .some): return false
                default: return $0.word < $1.word
                }
            }
    }

    func item(for character: String?) -> ComponentItem? {
        guard let character else { return nil }
        return componentRepo.byCharacter[character]
    }

    func structureText(for character: String) -> String? {
        let key = character.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.count == 1 else { return nil }
        let raw = componentRepo.entry(for: key)?.meta
        let value = (raw?.decomposition ?? raw?.idc ?? item(for: key)?.decomposition ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    func meaningText(for character: String) -> String? {
        let key = character.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.count == 1 else { return nil }
        let value = (componentRepo.entry(for: key)?.meta.definition ?? item(for: key)?.definition ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    func counterpart(for character: String?) -> ComponentItem? {
        guard let character else { return nil }
        guard let counterpartChar = componentRepo.counterpart(for: character) else { return nil }
        return componentRepo.byCharacter[counterpartChar]
    }

    /// Returns all script variant ComponentItems for a character, in order.
    func allVariants(for character: String?) -> [ComponentItem] {
        guard let character else { return [] }
        return componentRepo.allVariants(for: character).compactMap { componentRepo.byCharacter[$0] }
    }

    func isFavorite(_ character: String) -> Bool {
        favorites.contains(character)
    }

    func isPhraseFavorite(_ word: String) -> Bool {
        favoritePhrases.contains(word)
    }

    func togglePhraseFavorite(_ word: String) {
        if favoritePhrases.contains(word) {
            favoritePhrases.remove(word)
            favoritePhraseDates.removeValue(forKey: word)
        } else {
            favoritePhrases.insert(word)
            favoritePhraseDates[word] = Date()
            appendPhraseCharactersToBreadcrumb(word)
        }
        UserDefaults.standard.set(Array(favoritePhrases), forKey: favoritePhrasesKey)
        persistFavoritePhraseDates()
    }

    private func persistFavoritePhraseDates() {
        let encoded = favoritePhraseDates.mapValues { $0.timeIntervalSince1970 }
        UserDefaults.standard.set(encoded, forKey: favoritePhraseDatesKey)
    }

    func persistOverlayAddedDates() {
        let encoded = overlayAddedDates.mapValues { $0.timeIntervalSince1970 }
        UserDefaults.standard.set(encoded, forKey: overlayAddedDatesKey)
    }

    func favoriteAddedDate(for character: String) -> Date? {
        favoriteAddedDates[character]
    }

    func setSearchMode(_ mode: SearchMode) {
        searchMode = mode
        performSearch()
    }

    func setScriptFilter(_ filter: ScriptFilter) {
        scriptFilter = filter
        if let selectedCharacter {
            select(character: selectedCharacter, announce: false)
        }
    }

    func setLineageSortMode(_ mode: LineageSortMode) {
        lineageSortMode = mode
        lineagePage = 0
    }

    func toggleFavorite(character: String) {
        if favorites.contains(character) {
            favorites.remove(character)
            favoriteAddedDates.removeValue(forKey: character)
        } else {
            favorites.insert(character)
            favoriteAddedDates[character] = Date()
            pushRootBreadcrumb(character)
        }
        Task {
            persistFavorites()
        }
    }

    func setFavorite(character: String, isFavorite: Bool) {
        if isFavorite {
            favorites.insert(character)
            if favoriteAddedDates[character] == nil {
                favoriteAddedDates[character] = Date()
            }
            pushRootBreadcrumb(character)
        } else {
            favorites.remove(character)
            favoriteAddedDates.removeValue(forKey: character)
        }
        Task {
            persistFavorites()
        }
    }

    // MARK: - Character Studio (DataEdit) Operations
    
    func loadDataEditEntry(for character: String) {
        let key = character.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.count == 1 else { return }

        // If cached, hydrate instantly to keep UI smooth when switching tabs.
        if let cached = dataEditCache[key] {
            let currentPhrases = phraseRepo.fetchAddedPhrases()
            dataEditCache[key] = (entry: cached.entry, phrases: currentPhrases, isFav: cached.isFav)
            dataEditCharacter = key
            dataEditPhrases = currentPhrases
            applyDataEditEntryToForm(cached.entry, currentPhrases, cached.isFav)
            dataEditAutoSaveStatus = "Ready to edit \(key)"
            return
        }

        dataEditLoadTask?.cancel()
        isApplyingDatasetEntry = true
        dataEditAutoSaveStatus = "Loading \(key)..."

        dataEditLoadTask = Task { [weak self] in
            guard let self else { return }
            let entry = componentRepo.entry(for: key) ?? emptyEntryTemplate()
            let currentPhrases = phraseRepo.fetchAddedPhrases()
            let isFav = favorites.contains(key)

            if Task.isCancelled { return }

            dataEditCache[key] = (entry: entry, phrases: currentPhrases, isFav: isFav)

            if Task.isCancelled { return }

            await MainActor.run { [weak self] in
                guard let self else { return }
                dataEditCharacter = key
                dataEditPhrases = currentPhrases
                applyDataEditEntryToForm(entry, currentPhrases, isFav)
                isApplyingDatasetEntry = false
                dataEditAutoSaveStatus = "Ready to edit \(key)"
            }
        }
    }

    func restoreFromLibrary() {
        let key = dataEditCharacter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.count == 1 else { return }
        restoreDictionaryCharacterFromLibrary(key)
    }

    func restoreDictionaryCharacterFromLibrary(_ character: String) {
        let key = character.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.count == 1 else { return }
        pendingDatasetAutosaveWorkItem?.cancel()
        pendingDatasetAutosaveWorkItem = nil

        guard componentRepo.baseEntry(for: key) != nil else {
            dataEditAutoSaveStatus = "Only built-in characters can be reverted."
            return
        }

        do {
            componentRepo.restoreEntryFromBase(character: key)
            try persistDictionaryOverlay()
            try persistDataEditAndRefresh()

            if let restoredEntry = componentRepo.entry(for: key) {
                dataEditCharacter = key
                dataEditPhrases = phraseRepo.fetchAddedPhrases()
                applyDataEditEntryToForm(restoredEntry, dataEditPhrases, favorites.contains(key))
                dataEditCache[key] = (entry: restoredEntry, phrases: dataEditPhrases, isFav: favorites.contains(key))
            }

            dataEditAutoSaveStatus = "Reverted to main dictionary."
        } catch {
            dataEditAutoSaveStatus = "Library error: \(error.localizedDescription)"
        }
    }

    func createCustomDictionaryEntry(character: String) throws {
        let key = character.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.count == 1 else {
            throw NSError(domain: "Radix", code: 2, userInfo: [NSLocalizedDescriptionKey: "Enter exactly one Chinese character."])
        }

        if let existing = componentRepo.entry(for: key) {
            dataEditCharacter = key
            applyDataEditEntryToForm(existing, phraseRepo.fetchAddedPhrases(), favorites.contains(key))
            dataEditAutoSaveStatus = componentRepo.baseEntry(for: key) == nil
                ? "Custom character already exists."
                : "That character is already in the built-in dictionary, so it was opened for editing instead."
            return
        }

        dataEditCharacter = key
        dataEditPhrases = phraseRepo.fetchAddedPhrases()
        let entry = emptyEntryTemplate()
        applyDataEditEntryToForm(entry, dataEditPhrases, favorites.contains(key))
        pendingDatasetAutosaveWorkItem?.cancel()
        pendingDatasetAutosaveWorkItem = nil
        dataEditAutoSaveStatus = "New character loaded into the editor."
    }

    func discardCurrentDataEditDraft() {
        pendingDatasetAutosaveWorkItem?.cancel()
        pendingDatasetAutosaveWorkItem = nil

        let key = dataEditCharacter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.count == 1 else {
            clearDataEditForm()
            dataEditAutoSaveStatus = "Draft cleared."
            return
        }

        if componentRepo.entry(for: key) != nil {
            loadDataEditEntry(for: key)
        } else {
            clearDataEditForm()
            dataEditAutoSaveStatus = "Draft cleared."
        }
    }

    func startBlankDataEdit() {
        pendingDatasetAutosaveWorkItem?.cancel()
        pendingDatasetAutosaveWorkItem = nil
        clearDataEditForm()
        dataEditPhrases = phraseRepo.fetchAddedPhrases()
        dataEditAutoSaveStatus = "Open a character to start editing."
    }

    func saveCurrentDictionaryDraft() throws {
        pendingDatasetAutosaveWorkItem?.cancel()
        pendingDatasetAutosaveWorkItem = nil
        try saveDataEdit(reloadCaches: true)
    }

    func resetStudioToMaster() throws {
        try componentRepo.loadFromBundle()
        try removeDictionaryOverlayFiles()
        try persistDataEditAndRefresh()
        
        if !dataEditCharacter.isEmpty {
            loadDataEditEntry(for: dataEditCharacter)
        }
        
        dataEditAutoSaveStatus = "Dictionary changes reset to Master copy."
    }

    func removeDataEditPhrase(word: String) {
        guard phraseRepo.isInAdd(word: word) else {
            dataEditAutoSaveStatus = "Only custom phrases can be edited here."
            return
        }
        dataEditPhrases.removeAll(where: { $0.word == word })
        addedPhrases.removeAll(where: { $0.word == word }) // immediate UI update for Added list
        do {
            try phraseRepo.deletePhrase(word: word)
            refreshPhraseBackedViews(for: dataEditCharacter)
            dataEditAutoSaveStatus = "Phrase removed from your custom list."
        } catch {
            dataEditAutoSaveStatus = "Delete failed: \(error.localizedDescription)"
        }
    }

    func addCustomPhrase(word: String, pinyin: String, meanings: String) throws {
        let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedWord.isEmpty else { return }

        try phraseRepo.addOrUpdatePhrase(
            word: trimmedWord,
            pinyin: pinyin.trimmingCharacters(in: .whitespacesAndNewlines),
            meanings: meanings.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        refreshPhraseBackedViews(for: dataEditCharacter.trimmingCharacters(in: .whitespacesAndNewlines))
        dataEditAutoSaveStatus = "Custom phrase saved."
    }

    func saveDataEdit(reloadCaches: Bool = true) throws {
        let key = dataEditCharacter.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasDictionaryTarget = key.count == 1

        if hasDictionaryTarget {
            componentRepo.replaceEntry(character: key, entry: buildDataEditEntryFromForm())
            // Stamp the save time so the list can sort by recency
            if overlayAddedDates[key] == nil {
                overlayAddedDates[key] = Date()
                persistOverlayAddedDates()
            }
        }
        
        var blockedBuiltInWords: [String] = []
        for p in dataEditPhrases {
            let trimmedWord = p.word.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedWord.isEmpty {
                if phraseRepo.isInBase(word: trimmedWord) && !phraseRepo.isInAdd(word: trimmedWord) {
                    // Keep built-in phrases outside the custom-editing flow.
                    blockedBuiltInWords.append(trimmedWord)
                    continue
                }
                try phraseRepo.addOrUpdatePhrase(word: trimmedWord, pinyin: p.pinyin, meanings: p.meanings)
            }
        }

        if hasDictionaryTarget {
            dataEditCache[key] = (
                entry: buildDataEditEntryFromForm(),
                phrases: dataEditPhrases,
                isFav: dataEditIsFavourite
            )
        }
        
        if hasDictionaryTarget {
            setFavorite(character: key, isFavorite: dataEditIsFavourite)
        }
        
        if reloadCaches {
            if hasDictionaryTarget {
                try persistDictionaryOverlay()
                try persistDataEditAndRefresh()
                refreshPhraseBackedViews(for: key)
            } else {
                refreshPhraseBackedViews(for: nil)
            }
            if blockedBuiltInWords.isEmpty {
                dataEditAutoSaveStatus = hasDictionaryTarget ? "All changes saved." : "Custom phrases saved."
            } else {
                dataEditAutoSaveStatus = "Some entries match built-in phrases and were not saved: \(blockedBuiltInWords.joined(separator: ", "))"
            }
        } else {
            // Lightweight auto-save: persist only the datasets that were actually edited.
            if hasDictionaryTarget {
                try persistDictionaryOverlay()
                refreshAddedDictionaryCharacters()
            }
            dataEditAutoSaveStatus = blockedBuiltInWords.isEmpty
                ? (hasDictionaryTarget ? "Auto-saved." : "Custom phrases auto-saved.")
                : "Built-in phrase matches were skipped during auto-save."
        }
    }

    func scheduleDataEditAutoSave() {
        guard !isApplyingDatasetEntry else { return }
        pendingDatasetAutosaveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            do {
                try self.saveDataEdit(reloadCaches: false)
            } catch {
                self.dataEditAutoSaveStatus = "Auto-save failed: \(error.localizedDescription)"
            }
        }
        pendingDatasetAutosaveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2), execute: work)
    }

    func flushPendingDataEditAutoSave() {
        pendingDatasetAutosaveWorkItem?.cancel()
        pendingDatasetAutosaveWorkItem = nil
        guard !isApplyingDatasetEntry else { return }
        do {
            try saveDataEdit(reloadCaches: false)
        } catch {
            dataEditAutoSaveStatus = "Auto-save failed: \(error.localizedDescription)"
        }
    }

    func deleteCurrentDataEditEntry() throws {
        let key = dataEditCharacter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.count == 1 else { return }
        guard componentRepo.baseEntry(for: key) == nil else {
            throw NSError(domain: "Radix", code: 3, userInfo: [NSLocalizedDescriptionKey: "Only custom added characters can be deleted. Use Restore for built-in characters."])
        }
        componentRepo.deleteEntry(character: key)
        try persistDictionaryOverlay()
        try persistDataEditAndRefresh()
        dataEditCharacter = ""
        dataEditDefinition = ""
        dataEditPinyin = ""
        dataEditDecomposition = ""
        dataEditRadical = ""
        dataEditStrokes = ""
        dataEditCompounds = ""
        dataEditEtymHint = ""
        dataEditEtymDetails = ""
        dataEditRelatedCharacters = ""
        dataEditIsFavourite = false
        dataEditAutoSaveStatus = "Custom character deleted."
    }

    func currentDataEditSnapshotJSON() -> String? {
        let key = dataEditCharacter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.count == 1, let entry = componentRepo.entry(for: key) else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(entry) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func portableBackupPackage() -> UnifiedPackage {
        let sortedFavorites = Array(favorites).sorted()
        let sortedFavoritePhrases = Array(favoritePhrases).sorted()
        return UnifiedPackage(
            schemaVersion: 2,
            dictionary: nil,
            dictionaryOverlay: componentRepo.overlayPackage(),
            phrases: phraseRepo.fetchAddedPhrases(),
            profile: UserProfile(
                schemaVersion: 2,
                favouritesList: sortedFavorites,
                favouriteEntries: sortedFavorites.map { FavouriteProfileEntry(character: $0, addedAt: favoriteAddedDates[$0]) },
                favouritePhrasesList: sortedFavoritePhrases,
                favouritePhraseEntries: sortedFavoritePhrases.map { FavouritePhraseProfileEntry(word: $0, addedAt: favoritePhraseDates[$0]) },
                selectedCharacter: selectedCharacter,
                searchMode: searchMode.rawValue,
                scriptFilter: scriptFilter.rawValue,
                promptConfig: promptConfig,
                promptSelectedTaskIDs: promptSelectedTaskIDs
            )
        )
    }

    func fullDatasetExportPackage() -> FullDatasetExportPackage {
        FullDatasetExportPackage(
            schemaVersion: 1,
            exportedAt: Date(),
            dictionary: componentRepo.rawMap,
            phrases: phraseRepo.fetchAllPhrases()
        )
    }

    func mergedDictionaryExportRecords() -> [DictionaryExportRecord] {
        componentRepo.rawMap.keys.sorted().compactMap { character in
            guard let entry = componentRepo.rawMap[character] else { return nil }
            let item = componentRepo.byCharacter[character]
            return DictionaryExportRecord(
                character: character,
                entry: entry,
                pinyin: item?.pinyinText ?? "",
                definition: item?.definition ?? "",
                decomposition: item?.decomposition ?? "",
                radical: item?.radical ?? "",
                strokes: item?.strokes
            )
        }
    }

    func mergedPhrasesForExport() -> [PhraseItem] {
        phraseRepo.fetchAllPhrases()
    }

    func importDataEditData(_ data: Data, mode: RestoreMode = .additive) throws {
        if let package = try? JSONDecoder().decode(UnifiedPackage.self, from: data) {
            let backupOverlay = package.dictionaryOverlay
                ?? ComponentRepository.makeOverlay(base: componentRepo.baseRawMap, effective: package.dictionary ?? [:])

            switch mode {

            case .additive:
                // Dictionary: only insert entries not already present on this device.
                // Deletions and edits from the backup are ignored so local data wins.
                let now = Date()
                for (char, entry) in backupOverlay.upserts where componentRepo.overlayUpserts[char] == nil {
                    componentRepo.addEntry(character: char, entry: entry)
                    if overlayAddedDates[char] == nil { overlayAddedDates[char] = now }
                }
                persistOverlayAddedDates()
                // Phrases: insert only words not already in the add-DB.
                try phraseRepo.addPhrasesAdditively(package.phrases)
                // Profile: union favourites; keep local settings (searchMode, templates etc).
                applyImportedProfileAdditive(package.profile)

            case .complete:
                // Dictionary: apply the backup overlay in full, replacing everything.
                componentRepo.applyOverlay(backupOverlay)
                overlayAddedDates = [:]
                let now = Date()
                for char in backupOverlay.upserts.keys where overlayAddedDates[char] == nil {
                    overlayAddedDates[char] = now
                }
                persistOverlayAddedDates()
                // Phrases: replace the add-DB entirely with backup contents.
                try phraseRepo.replaceAllPhrases(package.phrases)
                // Profile: replace everything — favourites, settings, templates.
                applyImportedProfile(package.profile)
            }

            try persistDictionaryOverlay()
            try persistDataEditAndRefresh()
        } else {
            // Legacy plain-map format — always a full replace.
            let map = try JSONDecoder().decode([String: RawComponentEntry].self, from: data)
            try componentRepo.loadFromBundle()
            let overlay = ComponentRepository.makeOverlay(base: componentRepo.baseRawMap, effective: map)
            componentRepo.applyOverlay(overlay)
            try persistDictionaryOverlay()
            try persistDataEditAndRefresh()
        }

        if !dataEditCharacter.isEmpty { loadDataEditEntry(for: dataEditCharacter) }
        refreshAddedPhrases()
    }

    /// Additive profile merge: unions favourites, ignores settings/templates so local values win.
    private func applyImportedProfileAdditive(_ profile: UserProfile) {
        // Union favourite characters
        let backupFavEntries = profile.favouriteEntries ?? profile.favouritesList.map {
            FavouriteProfileEntry(character: $0, addedAt: nil)
        }
        for entry in backupFavEntries where componentRepo.hasCharacter(entry.character) {
            favorites.insert(entry.character)
            if favoriteAddedDates[entry.character] == nil {
                favoriteAddedDates[entry.character] = entry.addedAt
            }
        }
        persistFavorites()

        // Union favourite phrases
        let backupPhraseEntries = profile.favouritePhraseEntries
            ?? (profile.favouritePhrasesList ?? []).map { FavouritePhraseProfileEntry(word: $0, addedAt: nil) }
        for entry in backupPhraseEntries {
            let word = entry.word.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !word.isEmpty else { continue }
            favoritePhrases.insert(word)
            if favoritePhraseDates[word] == nil { favoritePhraseDates[word] = entry.addedAt }
        }
        persistFavoritePhrases()
        // searchMode, scriptFilter, promptConfig, promptSelectedTaskIDs — intentionally not touched.
    }

    func calculateDictionaryVariances() {
        let masterRepo = ComponentRepository()
        let masterPhraseRepo = PhraseRepository()
        do {
            try masterRepo.loadFromBundle()
            let masterMap = masterRepo.rawMap
            let studioMap = componentRepo.rawMap
            
            var dictVars: [DictionaryVariance] = []
            for char in studioMap.keys {
                if masterMap[char] == nil {
                    dictVars.append(DictionaryVariance(character: char, type: .added))
                }
            }
            for char in masterMap.keys {
                if studioMap[char] == nil {
                    dictVars.append(DictionaryVariance(character: char, type: .missing))
                }
            }
            self.dictionaryVariances = dictVars.sorted { $0.character < $1.character }
            
            try masterPhraseRepo.openMasterBundleOnly()
            let masterPhrases = Set(masterPhraseRepo.fetchAllPhrases().map(\.word))
            let studioPhrases = Set(phraseRepo.fetchAllPhrases().map(\.word))
            
            var phVars: [DictionaryVariance] = []
            for word in studioPhrases {
                if !masterPhrases.contains(word) {
                    phVars.append(DictionaryVariance(character: word, type: .added))
                }
            }
            for word in masterPhrases {
                if !studioPhrases.contains(word) {
                    phVars.append(DictionaryVariance(character: word, type: .missing))
                }
            }
            self.phraseVariances = phVars.sorted { $0.character < $1.character }
            
        } catch {
            dataEditAutoSaveStatus = "Variance check failed: \(error.localizedDescription)"
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
        applyPhraseScriptFilter(to: smartPhraseResults)
    }

    var filteredDefinitionPhraseResults: [PhraseItem] {
        applyPhraseScriptFilter(to: definitionPhraseResults)
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

    private func buildGridItemsWithCounts() -> (items: [ComponentItem], allCount: Int, componentCount: Int) {
        let lower = min(strokeMinFilter, strokeMaxFilter)
        let upper = max(strokeMinFilter, strokeMaxFilter)
        var items = allCharactersCache
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
            case .componentFrequency:
                return componentPool.sorted(by: usageSortPredicate)
            case .characterFrequency:
                return items.sorted(by: frequencySortPredicate)
            }
        }()

        return (items: sorted, allCount: items.count, componentCount: componentPool.count)
    }

    var gridBatchSize: Int {
        #if targetEnvironment(macCatalyst)
        return 225
        #else
        if UIDevice.current.userInterfaceIdiom == .pad {
            return 96
        }
        return 120
        #endif
    }
    var gridPageCount: Int {
        let count = allGridItems.count
        return count == 0 ? 1 : Int(ceil(Double(count) / Double(gridBatchSize)))
    }
    var pagedGridItems: [ComponentItem] {
        let page = min(max(0, gridPage), max(0, gridPageCount - 1))
        let start = page * gridBatchSize
        let end = min(start + gridBatchSize, allGridItems.count)
        guard start < end else { return [] }
        return Array(allGridItems[start..<end])
    }
    func nextGridPage() {
        guard gridPage + 1 < gridPageCount else { return }
        gridPage += 1
    }
    func previousGridPage() {
        guard gridPage > 0 else { return }
        gridPage -= 1
    }

    func setGridSortMode(_ mode: GridSortMode) { gridSortMode = mode }
    func setGridScriptFilter(_ filter: ScriptFilter) { gridScriptFilter = filter }
    @discardableResult
    func focusGridCharacter(_ character: String) -> Bool {
        guard let index = allGridItems.firstIndex(where: { $0.character == character }) else {
            previewCharacter = character
            return false
        }
        gridPage = index / gridBatchSize
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

    // MARK: - AI Template Persistence
    func selectAllPromptTasks() {
        promptSelectedTaskIDs = promptConfig.tasks.map(\.id)
        persistPromptSettings()
    }
    func setPromptPreamble(_ value: String) {
        promptConfig.preamble = value
        persistPromptSettings()
    }
    func setPromptEpilogue(_ value: String) {
        promptConfig.epilogue = value
        persistPromptSettings()
    }
    func setPromptTaskTitle(taskID: String, title: String) {
        guard let idx = promptConfig.tasks.firstIndex(where: { $0.id == taskID }) else { return }
        promptConfig.tasks[idx].title = title
        persistPromptSettings()
    }
    func setPromptTaskTemplate(taskID: String, template: String) {
        guard let idx = promptConfig.tasks.firstIndex(where: { $0.id == taskID }) else { return }
        promptConfig.tasks[idx].template = template
        persistPromptSettings()
    }
    func addPromptTask() {
        let next = (promptConfig.tasks.count + 1)
        var id = "task\(next)"
        var suffix = 1
        while promptConfig.tasks.contains(where: { $0.id == id }) {
            suffix += 1
            id = "task\(next)_\(suffix)"
        }
        let task = PromptTask(id: id, title: "Task \(next)", template: "Task \(next)\n\n")
        promptConfig.tasks.append(task)
        promptSelectedTaskIDs.append(id)
        persistPromptSettings()
    }
    func removePromptTask(taskID: String) {
        promptConfig.tasks.removeAll { $0.id == taskID }
        promptSelectedTaskIDs.removeAll { $0 == taskID }
        persistPromptSettings()
    }
    func resetPromptConfigToDefaults() {
        promptConfig = .streamlitDefault
        promptSelectedTaskIDs = promptConfig.tasks.map(\.id)
        persistPromptSettings()
    }
    func setPromptTask(_ taskID: String, enabled: Bool) {
        if enabled {
            if !promptSelectedTaskIDs.contains(taskID) { promptSelectedTaskIDs.append(taskID) }
        } else {
            promptSelectedTaskIDs.removeAll { $0 == taskID }
        }
        persistPromptSettings()
    }

    func promptText(for character: String) -> String {
        let char = character.trimmingCharacters(in: .whitespacesAndNewlines)
        let item = componentRepo.byCharacter[char]
        let analysis = componentRepo.analyzeStructure(for: char)
        let pFamily = componentRepo.pronunciationFamily(for: char)
        let sFamily = componentRepo.semanticFamily(for: char)
        let context = PromptRenderContext(
            char: char,
            definitionEN: item?.definition ?? "",
            decomposition: item?.decomposition.isEmpty == false ? (item?.decomposition ?? "") : "None",
            semantic: analysis?.semantic ?? "None",
            phonetic: analysis?.phonetic ?? "None",
            phoneticPinyin: analysis?.phoneticPinyin ?? "None",
            isSoundMatch: String(analysis?.isSoundMatch ?? false),
            pronunciationFamily: pFamily.isEmpty ? "None" : pFamily.joined(separator: ", "),
            semanticFamily: sFamily.isEmpty ? "None" : sFamily.joined(separator: ", ")
        )
        return promptConfig.renderPrompt(selectedTaskIDs: promptSelectedTaskIDs, context: context)
    }

    // MARK: - Private Utilities
    
    private func persistDataEditAndRefresh() throws {
        phraseCache.removeAll()
        refreshAddedDictionaryCharacters()
        if hasPerformedSearch { performSearch(customQuery: lastSearchQuery) }
        recomputeGridItems()
        if let current = previewCharacter ?? selectedCharacter, componentRepo.hasCharacter(current) {
            select(character: current, announce: false)
        }
        // Heavy work off main thread
        Task {
            let allChars = componentRepo.search(query: "", scriptFilter: .any, limit: Int.max)
            let radicals = ["none"] + componentRepo.availableRadicals()
            let structures = ["none"] + componentRepo.availableStructures()
            await MainActor.run {
                allCharactersCache = allChars
                availableRadicalFilters = radicals
                availableStructureFilters = structures
                if !radicals.contains(rootRadicalFilter) { rootRadicalFilter = "none" }
                if !structures.contains(rootStructureFilter) { rootStructureFilter = "none" }
            }
            await MainActor.run { calculateDictionaryVariances() }
        }
    }

    private func applyDataEditEntryToForm(_ entry: RawComponentEntry, _ phrases: [PhraseItem], _ isFav: Bool) {
        isApplyingDatasetEntry = true
        defer { isApplyingDatasetEntry = false }
        let meta = entry.meta
        dataEditVariant = meta.variant?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        dataEditAdditionalVariants = (meta.additionalVariants ?? []).joined(separator: ", ")
        dataEditDefinition = meta.definition ?? ""
        dataEditPinyin = meta.pinyin?.list.joined(separator: "\n") ?? ""
        dataEditDecomposition = (meta.decomposition ?? meta.idc ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        dataEditRadical = meta.radical ?? ""
        switch meta.strokes {
        case .int(let value): dataEditStrokes = String(value)
        case .string(let value): dataEditStrokes = value
        case .none: dataEditStrokes = ""
        }
        dataEditCompounds = (meta.compounds?.list ?? []).joined(separator: "\n")
        dataEditEtymologyType = meta.etymology?.type
        dataEditEtymHint = meta.etymology?.hint?.text ?? ""
        dataEditEtymDetails = meta.etymology?.details?.text ?? ""
        dataEditRelatedCharacters = entry.relatedCharacters.joined(separator: "\n")
        dataEditIsFavourite = isFav
    }

    private func buildDataEditEntryFromForm() -> RawComponentEntry {
        let pinyinParts = splitCSVOrLines(dataEditPinyin)
        let pinyinValue: StringOrMany = pinyinParts.count <= 1
            ? .single(pinyinParts.first ?? "")
            : .many(pinyinParts)
        let strokesText = dataEditStrokes.trimmingCharacters(in: .whitespacesAndNewlines)
        let strokesValue: IntOrString = Int(strokesText).map(IntOrString.int) ?? .string(strokesText)
        let etymology = RawEtymology(
            type: dataEditEtymologyType?.trimmingCharacters(in: .whitespacesAndNewlines),
            hint: .single(dataEditEtymHint.trimmingCharacters(in: .whitespacesAndNewlines)),
            details: .single(dataEditEtymDetails.trimmingCharacters(in: .whitespacesAndNewlines))
        )
        let decompValue = dataEditDecomposition.trimmingCharacters(in: .whitespacesAndNewlines)
        return RawComponentEntry(
            relatedCharacters: splitCSVOrLines(dataEditRelatedCharacters),
            meta: RawMeta(variant: {
                let trimmed = dataEditVariant.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }(), additionalVariants: {
                let parts = splitCSVOrLines(dataEditAdditionalVariants)
                return parts.isEmpty ? nil : parts
            }(), pinyin: pinyinValue, definition: dataEditDefinition.trimmingCharacters(in: .whitespacesAndNewlines), decomposition: decompValue, idc: decompValue, radical: dataEditRadical.trimmingCharacters(in: .whitespacesAndNewlines), strokes: strokesValue, compounds: .many(splitCSVOrLines(dataEditCompounds)), etymology: etymology)
        )
    }

    private func splitCSVOrLines(_ value: String) -> [String] {
        value.split(whereSeparator: { $0 == "\n" || $0 == "," }).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private func clearDataEditForm() {
        isApplyingDatasetEntry = true
        defer { isApplyingDatasetEntry = false }
        dataEditCharacter = ""
        dataEditDefinition = ""
        dataEditPinyin = ""
        dataEditDecomposition = ""
        dataEditRadical = ""
        dataEditStrokes = ""
        dataEditCompounds = ""
        dataEditVariant = ""
        dataEditAdditionalVariants = ""
        dataEditEtymologyType = nil
        dataEditEtymHint = ""
        dataEditEtymDetails = ""
        dataEditRelatedCharacters = ""
        dataEditIsFavourite = false
    }

    private func refreshAllCharactersCache() {
        allCharactersCache = componentRepo.search(query: "", scriptFilter: .any, limit: Int.max)
    }

    private func refreshAddedDictionaryCharacters() {
        rootsDerivativesCache.removeAll()
        let allChanged = componentRepo.changedCharacters
        let added = Set(componentRepo.addedCharacters)
        // Sort by overlayAddedDates desc (most recently added first), then alphabetically
        let sorted = allChanged.sorted {
            let lhsDate = overlayAddedDates[$0]
            let rhsDate = overlayAddedDates[$1]
            switch (lhsDate, rhsDate) {
            case let (l?, r?): return l > r
            case (.some, nil): return true
            case (nil, .some): return false
            default: return $0 < $1
            }
        }
        addedDictionaryCharacters = sorted.filter { added.contains($0) }
        changedDictionaryCharacters = sorted
        editedDictionaryCharacters = sorted.filter { !added.contains($0) }
        editedDictionaryCharactersSet = Set(editedDictionaryCharacters)
    }

    private func scheduleGridRecompute() {
        pendingGridRecomputeWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.recomputeGridItems() }
        pendingGridRecomputeWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(40), execute: work)
    }

    private func recomputeGridItems() {
        // Move heavy filtering/sorting to a background task
        Task {
            let result = buildGridItemsWithCounts()
            await MainActor.run {
                allGridItems = result.items
                gridFilteredAllCount = result.allCount
                gridFilteredComponentCount = result.componentCount
            }
        }
    }

    private func isNoFilter(_ value: String) -> Bool {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == "none" || normalized == "any"
    }

    private func rootFilterPredicate(_ item: ComponentItem) -> Bool {
        let lower = min(rootMinStroke, rootMaxStroke)
        let upper = max(rootMinStroke, rootMaxStroke)
        let strokeValue = item.strokes ?? 999
        let strokeMatch = strokeValue >= lower && strokeValue <= upper
        let radicalMatch = isNoFilter(rootRadicalFilter) || item.radical == rootRadicalFilter
        let structure = componentRepo.structureKey(for: item)
        let structureMatch = isNoFilter(rootStructureFilter) || structure == rootStructureFilter
        return strokeMatch && radicalMatch && structureMatch
    }

    private func usageSortPredicate(_ lhs: ComponentItem, _ rhs: ComponentItem) -> Bool {
        // Prioritize characters with at least 5 usages (important components)
        let lhsGroup = lhs.usageCount >= 5 ? 0 : 1
        let rhsGroup = rhs.usageCount >= 5 ? 0 : 1
        if lhsGroup != rhsGroup { return lhsGroup < rhsGroup }
        
        if lhsGroup == 0 {
            // Group 0: Major components sorted by usage count
            if lhs.usageCount != rhs.usageCount { return lhs.usageCount > rhs.usageCount }
        }
        
        // Tie-breaker for all: Ranking (top 6,000) then raw frequency
        let lRank = lhs.rank ?? 999999
        let rRank = rhs.rank ?? 999999
        if lRank != rRank { return lRank < rRank }
        
        if lhs.freqPerMillion != rhs.freqPerMillion { return lhs.freqPerMillion > rhs.freqPerMillion }
        return lhs.character < rhs.character
    }

    private func frequencySortPredicate(_ lhs: ComponentItem, _ rhs: ComponentItem) -> Bool {
        // Primary sort: Rank (1 to 6,000). Unranked characters (nil) are treated as 999,999.
        let lRank = lhs.rank ?? 999999
        let rRank = rhs.rank ?? 999999
        if lRank != rRank { return lRank < rRank }
        
        // Secondary sort: Raw frequency for unranked items
        if lhs.freqPerMillion != rhs.freqPerMillion { return lhs.freqPerMillion > rhs.freqPerMillion }
        
        // Tertiary sort: Usage count
        if lhs.usageCount != rhs.usageCount { return lhs.usageCount > rhs.usageCount }
        
        return lhs.character < rhs.character
    }

    private func isLikelyPinyinQuery(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return false }
        return trimmed.unicodeScalars.allSatisfy { CharacterSet.letters.union(.decimalDigits).union(.whitespaces).contains($0) }
    }

    private func normalizedCompactQuery(_ text: String) -> String {
        let mutable = NSMutableString(string: text.lowercased()) as CFMutableString
        CFStringTransform(mutable, nil, kCFStringTransformStripDiacritics, false)
        return (mutable as String).filter { $0.isLetter || $0.isNumber }
    }

    private func containsChineseCharacters(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            if (0x4E00...0x9FFF).contains(scalar.value) || (0x3400...0x4DBF).contains(scalar.value) {
                return true
            }
        }
        return false
    }

    private func mergePhraseResults(primary: [PhraseItem], secondary: [PhraseItem]) -> [PhraseItem] {
        var seen = Set<String>()
        var out: [PhraseItem] = []
        for item in (primary + secondary) {
            if !seen.contains(item.word) {
                seen.insert(item.word)
                out.append(item)
            }
        }
        return out
    }

    private func phrasePinyinSortPredicate(_ lhs: PhraseItem, _ rhs: PhraseItem) -> Bool {
        let lhsPinyin = normalizedCompactQuery(lhs.pinyin)
        let rhsPinyin = normalizedCompactQuery(rhs.pinyin)
        if lhsPinyin != rhsPinyin { return lhsPinyin < rhsPinyin }
        if lhs.pinyin != rhs.pinyin { return lhs.pinyin < rhs.pinyin }
        return lhs.word < rhs.word
    }

    func exportProfileData() throws -> Data {
        let sortedFavorites = Array(favorites).sorted()
        let sortedFavoritePhrases = Array(favoritePhrases).sorted()
        let profile = UserProfile(
            schemaVersion: 2,
            favouritesList: sortedFavorites,
            favouriteEntries: sortedFavorites.map { FavouriteProfileEntry(character: $0, addedAt: favoriteAddedDates[$0]) },
            favouritePhrasesList: sortedFavoritePhrases,
            favouritePhraseEntries: sortedFavoritePhrases.map { FavouritePhraseProfileEntry(word: $0, addedAt: favoritePhraseDates[$0]) },
            selectedCharacter: selectedCharacter,
            searchMode: searchMode.rawValue,
            scriptFilter: scriptFilter.rawValue,
            promptConfig: promptConfig,
            promptSelectedTaskIDs: promptSelectedTaskIDs
        )
        return try JSONEncoder().encode(profile)
    }

    func importProfileData(_ data: Data) throws {
        let profile = try JSONDecoder().decode(UserProfile.self, from: data)
        applyImportedProfile(profile)
    }

    func refreshAddedPhrases() {
        addedPhrases = phraseRepo.fetchAddedPhrases()
    }

    func loadSharedComponentPeers(for character: String) {
        sharedComponentPeers = componentRepo.sharedComponentPeers(for: character, scriptFilter: scriptFilter)
            .filter(rootFilterPredicate)
            .sorted(by: usageSortPredicate)
    }

    func loadSharedPeersByComponent(for character: String) {
        let raw = componentRepo.sharedPeersByComponent(for: character, scriptFilter: scriptFilter)
        var filtered: [String: [ComponentItem]] = [:]
        for (key, list) in raw {
            let keep = list
                .filter(rootFilterPredicate)
                .sorted(by: usageSortPredicate)
            if !keep.isEmpty { filtered[key] = keep }
        }
        sharedPeersByComponent = filtered

        // Derivatives are loaded separately via loadRootDerivatives; no coupling needed here
    }

    func rootInitialGridItems(limit: Int = Int.max) -> (items: [ComponentItem], total: Int) {
        let filtered = allCharactersCache
            .filter(rootFilterPredicate)
            .filter { item in
                switch scriptFilter {
                case .any:
                    return true
                case .simplified:
                    return componentRepo.isSimplifiedForGrid(item.character)
                case .traditional:
                    return componentRepo.isTraditionalForGrid(item.character)
                }
            }
            .sorted(by: frequencySortPredicate)
        return (Array(filtered.prefix(limit)), filtered.count)
    }

    func loadRootDerivatives(for character: String) {
        let key = RootsCacheKey(character: character, script: scriptFilter, minStroke: rootMinStroke, maxStroke: rootMaxStroke, radical: rootRadicalFilter, structure: rootStructureFilter)
        if let cached = rootsDerivativesCache[key] {
            rootDerivatives = cached.items
            rootDerivativesTotal = cached.total
            return
        }

        // Prefer current script filter; fall back to .any to avoid empties (e.g., 一)
        let preferred = componentRepo.related(for: character, scriptFilter: scriptFilter, max: 8000)
        let relatedAny = componentRepo.related(for: character, scriptFilter: .any, max: 8000)
        let universe = componentRepo.containingCharacters(for: character, scriptFilter: scriptFilter, max: 8000)
        let universeAny = componentRepo.containingCharacters(for: character, scriptFilter: .any, max: 8000)
        let rawIDs = componentRepo.entry(for: character)?.relatedCharacters ?? []
        let rawFromIDs = rawIDs.compactMap { componentRepo.byCharacter[$0] }.filter { componentRepo.matchesScriptFilter(item: $0, filter: scriptFilter) }

        // Prefer explicit related list; else raw IDs; else containment universe.
        let baseSet: [ComponentItem] = {
            if !preferred.isEmpty { return preferred }
            if !relatedAny.isEmpty { return relatedAny }
            if !rawFromIDs.isEmpty { return rawFromIDs }
            if !universe.isEmpty { return universe }
            return universeAny
        }()

        // Apply roots filters (min strokes + structure) to derivatives
        let filtered = baseSet.filter(rootFilterPredicate)

        // If filters remove everything, fall back to unfiltered base to avoid empty UI
        let finalSet = filtered.isEmpty ? baseSet : filtered

        let sorted = finalSet.sorted(by: frequencySortPredicate)
        let displayLimit = 500
        let limited = Array(sorted.prefix(displayLimit))
        rootDerivatives = limited
        rootDerivativesTotal = sorted.count
        rootsDerivativesCache[key] = RootsDerivativesCacheValue(items: limited, total: sorted.count)
    }

    // MARK: - Roots Breadcrumbs
    func resetRootBreadcrumb(to character: String) {
        pushRootBreadcrumb(character)
    }

    func pushRootBreadcrumb(_ character: String) {
        guard componentRepo.hasCharacter(character) else { return }
        if let existing = rootBreadcrumb.firstIndex(of: character) {
            rootBreadcrumb.remove(at: existing)
        }
        rootBreadcrumb.insert(character, at: 0)
        rootBreadcrumbIndex = 0
    }

    func stepRootBreadcrumb(by delta: Int) -> String? {
        let newIndex = rootBreadcrumbIndex + delta
        guard rootBreadcrumb.indices.contains(newIndex) else { return nil }
        rootBreadcrumbIndex = newIndex
        return rootBreadcrumb[newIndex]
    }

    var canRootGoBack: Bool { rootBreadcrumbIndex > 0 }
    var canRootGoForward: Bool { rootBreadcrumbIndex + 1 < rootBreadcrumb.count }

    func activateBreadcrumbCharacter(_ character: String) {
        let key = character.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.count == 1, componentRepo.hasCharacter(key) else { return }
        pushRootBreadcrumb(key)

        switch route {
        case .search:
            switch homeTab {
            case .smart:
                let pinyinText = item(for: key)?.pinyinText.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let searchText = pinyinText.isEmpty ? key : pinyinText
                query = searchText
                previewCharacter = key
                performSearch(customQuery: searchText)
                refreshPhrases(for: key)
            case .filter:
                _ = focusGridCharacter(key)
                refreshPhrases(for: key)
            case .favourites:
                setFavorite(character: key, isFavorite: !favorites.contains(key))
            case .dataEdit:
                openQuickCharacterEditor(key)
            }
        case .lineage:
            select(character: key, announce: false)
            loadSharedComponentPeers(for: key)
            loadSharedPeersByComponent(for: key)
            loadRootDerivatives(for: key)
        case .aiLink:
            previewCharacter = key
            refreshPhrases(for: key)
        case .favourites:
            setFavorite(character: key, isFavorite: !favorites.contains(key))
        }
    }

    // MARK: - Roots Cache
    private struct RootsCacheKey: Hashable {
        let character: String
        let script: ScriptFilter
        let minStroke: Int
        let maxStroke: Int
        let radical: String
        let structure: String
    }
    private struct RootsDerivativesCacheValue {
        let items: [ComponentItem]
        let total: Int
    }
    private var rootsDerivativesCache: [RootsCacheKey: RootsDerivativesCacheValue] = [:]

    func setAddPhrasesFile(url: URL) throws {
        try phraseRepo.setAddDBOverride(url)
        addPhrasesPath = phraseRepo.currentAddDBPath
        refreshPhraseBackedViews(for: dataEditCharacter)
        dataEditAutoSaveStatus = "Using custom phrases file: \(url.lastPathComponent)"
    }

    func restoreDefaultAddPhrasesFile() throws {
        try phraseRepo.restoreDefaultAddDB()
        addPhrasesPath = phraseRepo.currentAddDBPath
        refreshPhraseBackedViews(for: dataEditCharacter)
        dataEditAutoSaveStatus = "Using default phrases_add.db"
    }

    func exportAddPhrasesDB() throws -> Data {
        let url = phraseRepo.currentAddDBURL
        return try Data(contentsOf: url)
    }

    private func refreshPhraseBackedViews(for character: String?) {
        phraseCache.removeAll()
        refreshAddedPhrases()
        syncDataEditPhraseCaches()
        dataEditPhrases = addedPhrases

        if let character, !character.isEmpty {
            let entry = componentRepo.entry(for: character) ?? emptyEntryTemplate()
            applyDataEditEntryToForm(entry, addedPhrases, favorites.contains(character))
        }

        refreshPhrases()
        if hasPerformedSearch || !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            performSearch()
        }
    }

    private func syncDataEditPhraseCaches() {
        for (key, value) in dataEditCache {
            dataEditCache[key] = (entry: value.entry, phrases: addedPhrases, isFav: value.isFav)
        }
    }

    private func loadFavorites() {
        if let data = UserDefaults.standard.data(forKey: favoriteEntriesKey),
           let entries = try? JSONDecoder().decode([FavouriteProfileEntry].self, from: data) {
            applyFavoriteEntries(entries)
        } else if let saved = UserDefaults.standard.array(forKey: favoritesKey) as? [String] {
            applyFavoriteCharacters(saved)
        }

        if let savedPhrases = UserDefaults.standard.array(forKey: favoritePhrasesKey) as? [String] {
            favoritePhrases = Set(savedPhrases)
        }

        if let rawPhraseDates = UserDefaults.standard.dictionary(forKey: favoritePhraseDatesKey) as? [String: Double] {
            favoritePhraseDates = rawPhraseDates.mapValues { Date(timeIntervalSince1970: $0) }
        }

        if let rawOverlayDates = UserDefaults.standard.dictionary(forKey: overlayAddedDatesKey) as? [String: Double] {
            overlayAddedDates = rawOverlayDates.mapValues { Date(timeIntervalSince1970: $0) }
        }
    }

    private func seedBreadcrumbFromFavorites() {
        var seeded: [String] = []
        var seen = Set<String>()

        let sortedFavoriteCharacters = favorites.sorted {
            let lhsDate = favoriteAddedDates[$0]
            let rhsDate = favoriteAddedDates[$1]
            switch (lhsDate, rhsDate) {
            case let (lhs?, rhs?):
                if lhs != rhs { return lhs > rhs }
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            case (nil, nil):
                break
            }
            return $0 < $1
        }

        func append(_ character: String) {
            guard character.count == 1, componentRepo.hasCharacter(character), !seen.contains(character) else { return }
            seen.insert(character)
            seeded.append(character)
        }

        sortedFavoriteCharacters.forEach(append)

        let sortedFavoritePhrases = favoritePhrases.sorted {
            let lhsDate = favoritePhraseDates[$0]
            let rhsDate = favoritePhraseDates[$1]
            switch (lhsDate, rhsDate) {
            case let (lhs?, rhs?):
                if lhs != rhs { return lhs > rhs }
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            case (nil, nil):
                break
            }
            return $0 < $1
        }

        for phrase in sortedFavoritePhrases {
            for character in phrase.map(String.init) {
                append(character)
            }
        }

        rootBreadcrumb = seeded
        rootBreadcrumbIndex = seeded.isEmpty ? 0 : min(rootBreadcrumbIndex, seeded.count - 1)
    }

    private func appendPhraseCharactersToBreadcrumb(_ word: String) {
        for character in word.map(String.init) {
            pushRootBreadcrumb(character)
        }
    }

    private func requestDataEditDictionaryFocus() {
        dataEditFocusRequestID += 1
    }

    private func requestPhraseEditFocus() {
        phraseEditFocusRequestID += 1
    }

    private func rememberLastPreviewedCharacter(_ character: String?) {
        guard let character else { return }
        let key = character.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.count == 1, componentRepo.hasCharacter(key) else { return }
        UserDefaults.standard.set(key, forKey: lastPreviewCharacterKey)
    }

    private func restoreLastPreviewedCharacterIfNeeded() {
        guard selectedCharacter == nil, previewCharacter == nil else { return }
        guard let saved = UserDefaults.standard.string(forKey: lastPreviewCharacterKey) else { return }
        let key = saved.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.count == 1, componentRepo.hasCharacter(key) else { return }

        selectedCharacter = key
        previewCharacter = key
        refreshPhrases(for: key)
        loadSharedComponentPeers(for: key)
        loadSharedPeersByComponent(for: key)
        loadRootDerivatives(for: key)
    }

    private func persistFavorites() {
        let sortedFavorites = Array(favorites).sorted()
        let entries = sortedFavorites.map { FavouriteProfileEntry(character: $0, addedAt: favoriteAddedDates[$0]) }
        UserDefaults.standard.set(sortedFavorites, forKey: favoritesKey)
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: favoriteEntriesKey)
        }
    }

    private func persistFavoritePhrases() {
        UserDefaults.standard.set(Array(favoritePhrases), forKey: favoritePhrasesKey)
        persistFavoritePhraseDates()
    }

    private func applyFavoriteCharacters(_ characters: [String]) {
        favorites = Set(characters.filter { componentRepo.hasCharacter($0) })
        favoriteAddedDates = [:]
    }

    private func applyFavoriteEntries(_ entries: [FavouriteProfileEntry]) {
        var characters = Set<String>()
        var datedEntries: [String: Date] = [:]

        for entry in entries {
            guard componentRepo.hasCharacter(entry.character) else { continue }
            characters.insert(entry.character)
            if let addedAt = entry.addedAt {
                datedEntries[entry.character] = addedAt
            }
        }

        favorites = characters
        favoriteAddedDates = datedEntries
    }

    private func applyFavoritePhraseWords(_ words: [String]) {
        favoritePhrases = Set(words)
        favoritePhraseDates = [:]
    }

    private func applyFavoritePhraseEntries(_ entries: [FavouritePhraseProfileEntry]) {
        var words = Set<String>()
        var datedEntries: [String: Date] = [:]

        for entry in entries {
            let trimmedWord = entry.word.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedWord.isEmpty else { continue }
            words.insert(trimmedWord)
            if let addedAt = entry.addedAt {
                datedEntries[trimmedWord] = addedAt
            }
        }

        favoritePhrases = words
        favoritePhraseDates = datedEntries
    }

    private func applyImportedProfile(_ profile: UserProfile) {
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
        }

        searchMode = SearchMode(rawValue: profile.searchMode ?? "") ?? .smart
        scriptFilter = ScriptFilter(rawValue: profile.scriptFilter ?? "") ?? .any
        if let cfg = profile.promptConfig { promptConfig = cfg.normalized() }
        if let selected = profile.promptSelectedTaskIDs { promptSelectedTaskIDs = selected }
        persistPromptSettings()
        if let candidate = profile.selectedCharacter, componentRepo.hasCharacter(candidate) {
            selectedCharacter = candidate
        }
        performSearch()
        if let selectedCharacter {
            select(character: selectedCharacter, announce: false)
        }
    }

    private func loadPromptSettings() {
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
    }

    func speakCharacter(_ character: String) {
        speechCoordinator.speak(character)
    }

    private func persistPromptSettings() {
        if let data = try? JSONEncoder().encode(promptConfig) { UserDefaults.standard.set(data, forKey: promptConfigKey) }
        UserDefaults.standard.set(promptSelectedTaskIDs, forKey: promptTaskSelectionKey)
    }

    private func loadDictionaryRepository() throws {
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

    private func persistDictionaryOverlay() throws {
        dataEditSavePath = dictionaryOverlayFileURL.path
        if componentRepo.hasOverlayChanges {
            try componentRepo.saveOverlay(to: dictionaryOverlayFileURL)
        } else if FileManager.default.fileExists(atPath: dictionaryOverlayFileURL.path) {
            try FileManager.default.removeItem(at: dictionaryOverlayFileURL)
        }
    }

    private func removeDictionaryOverlayFiles() throws {
        if FileManager.default.fileExists(atPath: dictionaryOverlayFileURL.path) {
            try FileManager.default.removeItem(at: dictionaryOverlayFileURL)
        }
        if FileManager.default.fileExists(atPath: legacyEditableDictionaryFileURL.path) {
            try FileManager.default.removeItem(at: legacyEditableDictionaryFileURL)
        }
    }

    private var dictionaryOverlayFileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("component_map_changes.json")
    }

    private var legacyEditableDictionaryFileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("component_map_editable.json")
    }

    private func emptyEntryTemplate() -> RawComponentEntry {
        RawComponentEntry(relatedCharacters: [], meta: RawMeta(variant: nil, additionalVariants: nil, pinyin: .single(""), definition: "", decomposition: "", idc: "", radical: "", strokes: .string(""), compounds: .many([]), etymology: RawEtymology(type: "", hint: .single(""), details: .single(""))))
    }
}
