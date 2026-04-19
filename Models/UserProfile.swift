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
    let selectedCharacter: String?
    let searchMode: String?
    let scriptFilter: String?
    let promptConfig: PromptConfig?
    let promptSelectedTaskIDs: [String]?

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case favouritesList = "favourites_list"
        case favouriteEntries = "favourite_entries"
        case favouritePhrasesList = "favourite_phrases_list"
        case favouritePhraseEntries = "favourite_phrase_entries"
        case selectedCharacter = "selected_character"
        case searchMode = "search_mode"
        case scriptFilter = "script_filter"
        case promptConfig = "prompt_config"
        case promptSelectedTaskIDs = "prompt_selected_task_ids"
    }
}
