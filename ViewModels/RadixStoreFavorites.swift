import Foundation

/*
 RADIX STORE — FAVORITES PERSISTENCE
 =====================================
 Handles loading, persisting, and applying favorite characters and phrases
 from UserDefaults. All @Published properties remain declared in RadixStore.swift.
*/

extension RadixStore {

    // MARK: - Load

    func loadFavorites() {
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

    // MARK: - Persist

    func persistFavorites() {
        let sortedFavorites = Array(favorites).sorted()
        let entries = sortedFavorites.map { FavouriteProfileEntry(character: $0, addedAt: favoriteAddedDates[$0]) }
        UserDefaults.standard.set(sortedFavorites, forKey: favoritesKey)
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: favoriteEntriesKey)
        }
    }

    func persistFavoritePhrases() {
        UserDefaults.standard.set(Array(favoritePhrases), forKey: favoritePhrasesKey)
        persistFavoritePhraseDates()
    }

    func persistFavoritePhraseDates() {
        let encoded = favoritePhraseDates.mapValues { $0.timeIntervalSince1970 }
        UserDefaults.standard.set(encoded, forKey: favoritePhraseDatesKey)
    }

    // MARK: - Imperative set (used by DataEdit and keyboard shortcut handler)

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
        Task { persistFavorites() }
    }

    // MARK: - Apply (called on load and import)

    func applyFavoriteCharacters(_ characters: [String]) {
        favorites = Set(characters.filter { componentRepo.hasCharacter($0) })
        favoriteAddedDates = [:]
    }

    func applyFavoriteEntries(_ entries: [FavouriteProfileEntry]) {
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

    func applyFavoritePhraseWords(_ words: [String]) {
        favoritePhrases = Set(words)
        favoritePhraseDates = [:]
    }

    func applyFavoritePhraseEntries(_ entries: [FavouritePhraseProfileEntry]) {
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
}
