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

struct UserProfile: Codable {
    let schemaVersion: Int
    let favouritesList: [String]
    let favouriteEntries: [FavouriteProfileEntry]?
    let favouritePhrasesList: [String]?
    let favouritePhraseEntries: [FavouritePhraseProfileEntry]?
    let rememberedList: [String]?
    let searchHistory: [String]?
    let selectedCharacter: String?
    let lastSearchQuery: String?
    let currentSearchQuery: String?
    let searchMode: String?
    let scriptFilter: String?
    let homeTab: String?
    let route: String?
    let phraseLength: Int?
    let promptConfig: PromptConfig?
    let promptSelectedTaskIDs: [String]?

    init(
        schemaVersion: Int,
        favouritesList: [String],
        favouriteEntries: [FavouriteProfileEntry]? = nil,
        favouritePhrasesList: [String]? = nil,
        favouritePhraseEntries: [FavouritePhraseProfileEntry]? = nil,
        rememberedList: [String]? = nil,
        searchHistory: [String]? = nil,
        selectedCharacter: String? = nil,
        lastSearchQuery: String? = nil,
        currentSearchQuery: String? = nil,
        searchMode: String? = nil,
        scriptFilter: String? = nil,
        homeTab: String? = nil,
        route: String? = nil,
        phraseLength: Int? = nil,
        promptConfig: PromptConfig? = nil,
        promptSelectedTaskIDs: [String]? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.favouritesList = favouritesList
        self.favouriteEntries = favouriteEntries
        self.favouritePhrasesList = favouritePhrasesList
        self.favouritePhraseEntries = favouritePhraseEntries
        self.rememberedList = rememberedList
        self.searchHistory = searchHistory
        self.selectedCharacter = selectedCharacter
        self.lastSearchQuery = lastSearchQuery
        self.currentSearchQuery = currentSearchQuery
        self.searchMode = searchMode
        self.scriptFilter = scriptFilter
        self.homeTab = homeTab
        self.route = route
        self.phraseLength = phraseLength
        self.promptConfig = promptConfig
        self.promptSelectedTaskIDs = promptSelectedTaskIDs
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case favouritesList = "favourites_list"
        case favouriteEntries = "favourite_entries"
        case favouritePhrasesList = "favourite_phrases_list"
        case favouritePhraseEntries = "favourite_phrase_entries"
        case rememberedList = "remembered_list"
        case searchHistory = "search_history"
        case selectedCharacter = "selected_character"
        case lastSearchQuery = "last_search_query"
        case currentSearchQuery = "current_search_query"
        case searchMode = "search_mode"
        case scriptFilter = "script_filter"
        case homeTab = "home_tab"
        case route
        case phraseLength = "phrase_length"
        case promptConfig = "prompt_config"
        case promptSelectedTaskIDs = "prompt_selected_task_ids"
    }
}
