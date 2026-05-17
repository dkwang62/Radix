import Foundation

struct FavouriteProfileEntry: Codable {
    let character: String
    let addedAt: Date?

    enum CodingKeys: String, CodingKey {
        case character
        case addedAt = "added_at"
    }
}

struct FavouritePhraseProfileEntry: Codable {
    let word: String
    let addedAt: Date?

    enum CodingKeys: String, CodingKey {
        case word
        case addedAt = "added_at"
    }
}

enum DefaultAIPreset: String, Codable, CaseIterable, Hashable {
    case deepSeek
    case gemini
    case claude
    case chatGPT
    case custom

    var displayName: String {
        switch self {
        case .deepSeek: return "DeepSeek"
        case .gemini: return "Gemini"
        case .claude: return "Claude"
        case .chatGPT: return "ChatGPT"
        case .custom: return "Custom AI"
        }
    }

    var baseURLString: String {
        switch self {
        case .deepSeek: return "https://chat.deepseek.com/"
        case .gemini: return "https://gemini.google.com/"
        case .claude: return "https://claude.ai/new"
        case .chatGPT: return "https://chatgpt.com/"
        case .custom: return ""
        }
    }
}

struct DefaultAISettings: Codable, Hashable {
    var preset: DefaultAIPreset = .chatGPT
    var customURLString: String = ""
}

struct UserProfile: Codable {
    let schemaVersion: Int
    let favouritesList: [String]
    let favouriteEntries: [FavouriteProfileEntry]?
    let favouritePhrasesList: [String]?
    let favouritePhraseEntries: [FavouritePhraseProfileEntry]?
    let rememberedList: [String]?
    let searchHistory: [String]?
    let previewCharacter: String?
    let lastSearchQuery: String?
    let currentSearchQuery: String?
    let searchMode: String?
    let scriptFilter: String?
    let homeTab: String?
    let sidebarNavigationStyle: String?
    let route: String?
    let phraseLength: Int?
    let promptConfig: PromptConfig?
    let promptSelectedTaskIDs: [String]?
    let defaultAISettings: DefaultAISettings?

    init(
        schemaVersion: Int,
        favouritesList: [String],
        favouriteEntries: [FavouriteProfileEntry]? = nil,
        favouritePhrasesList: [String]? = nil,
        favouritePhraseEntries: [FavouritePhraseProfileEntry]? = nil,
        rememberedList: [String]? = nil,
        searchHistory: [String]? = nil,
        previewCharacter: String? = nil,
        lastSearchQuery: String? = nil,
        currentSearchQuery: String? = nil,
        searchMode: String? = nil,
        scriptFilter: String? = nil,
        homeTab: String? = nil,
        sidebarNavigationStyle: String? = nil,
        route: String? = nil,
        phraseLength: Int? = nil,
        promptConfig: PromptConfig? = nil,
        promptSelectedTaskIDs: [String]? = nil,
        defaultAISettings: DefaultAISettings? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.favouritesList = favouritesList
        self.favouriteEntries = favouriteEntries
        self.favouritePhrasesList = favouritePhrasesList
        self.favouritePhraseEntries = favouritePhraseEntries
        self.rememberedList = rememberedList
        self.searchHistory = searchHistory
        self.previewCharacter = previewCharacter
        self.lastSearchQuery = lastSearchQuery
        self.currentSearchQuery = currentSearchQuery
        self.searchMode = searchMode
        self.scriptFilter = scriptFilter
        self.homeTab = homeTab
        self.sidebarNavigationStyle = sidebarNavigationStyle
        self.route = route
        self.phraseLength = phraseLength
        self.promptConfig = promptConfig
        self.promptSelectedTaskIDs = promptSelectedTaskIDs
        self.defaultAISettings = defaultAISettings
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case favouritesList = "favourites_list"
        case favouriteEntries = "favourite_entries"
        case favouritePhrasesList = "favourite_phrases_list"
        case favouritePhraseEntries = "favourite_phrase_entries"
        case rememberedList = "remembered_list"
        case searchHistory = "search_history"
        case previewCharacter = "preview_character"
        case lastSearchQuery = "last_search_query"
        case currentSearchQuery = "current_search_query"
        case searchMode = "search_mode"
        case scriptFilter = "script_filter"
        case homeTab = "home_tab"
        case sidebarNavigationStyle = "sidebar_navigation_style"
        case route
        case phraseLength = "phrase_length"
        case promptConfig = "prompt_config"
        case promptSelectedTaskIDs = "prompt_selected_task_ids"
        case defaultAISettings = "default_ai_settings"
    }
}
