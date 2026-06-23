import Foundation

/*
 RADIX STORE — FAVORITES
 ========================
 Handles favorite interactions plus loading, persisting, and applying favorite
 characters and phrases. Persisted values are owned by RadixUserLibraryState.
*/

extension RadixStore {

    // MARK: - Interactions

    func toggleFavorite(character: String) {
        if favorites.contains(character) {
            favorites.remove(character)
            favoriteAddedDates.removeValue(forKey: character)
        } else {
            favorites.insert(character)
            favoriteAddedDates[character] = Date()
            pushRootBreadcrumb(character)
        }
        Task { persistFavorites() }
    }

    func togglePhraseFavorite(_ word: String) {
        if favoritePhrases.contains(word) {
            favoritePhrases.remove(word)
            favoritePhraseDates.removeValue(forKey: word)
        } else {
            favoritePhrases.insert(word)
            favoritePhraseDates[word] = Date()
            if let phrase = phraseRepo.fetchPhrase(for: word) {
                pushPhraseBreadcrumb(phrase)
            }
        }
        persistFavoritePhrases()
    }

    func isFavorite(_ character: String) -> Bool { favorites.contains(character) }
    func isPhraseFavorite(_ word: String) -> Bool { favoritePhrases.contains(word) }
    func favoriteAddedDate(for character: String) -> Date? { favoriteAddedDates[character] }

    var favoriteItems: [ComponentItem] {
        FavoriteOrdering.sortedByAddedDate(
            favorites.compactMap { componentRepo.byCharacter[$0] },
            dateForValue: { favoriteAddedDates[$0.character] },
            fallbackSort: { $0.character < $1.character }
        )
    }

    var favoritePhrasesItems: [PhraseItem] {
        FavoriteOrdering.sortedByAddedDate(
            phraseRepo.fetchPhrases(matching: favoritePhrases),
            dateForValue: { favoritePhraseDates[$0.word] },
            fallbackSort: { $0.word < $1.word }
        )
    }

    // MARK: - Load

    func loadFavorites() {
        if let data = preferences.data(forKey: favoriteEntriesKey),
           let entries = try? JSONDecoder().decode([FavouriteProfileEntry].self, from: data) {
            applyFavoriteEntries(entries)
        } else if let saved = preferences.array(forKey: favoritesKey) as? [String] {
            applyFavoriteCharacters(saved)
        }

        if let savedPhrases = preferences.array(forKey: favoritePhrasesKey) as? [String] {
            favoritePhrases = Set(savedPhrases)
        }

        if let rawPhraseDates = preferences.dictionary(forKey: favoritePhraseDatesKey) as? [String: Double] {
            favoritePhraseDates = rawPhraseDates.mapValues { Date(timeIntervalSince1970: $0) }
        }

        if let rawOverlayDates = preferences.dictionary(forKey: overlayAddedDatesKey) as? [String: Double] {
            overlayAddedDates = rawOverlayDates.mapValues { Date(timeIntervalSince1970: $0) }
        }
    }

    // MARK: - Persist

    func persistFavorites() {
        let sortedFavorites = Array(favorites).sorted()
        let entries = sortedFavorites.map { FavouriteProfileEntry(character: $0, addedAt: favoriteAddedDates[$0]) }
        preferences.set(sortedFavorites, forKey: favoritesKey)
        if let data = try? JSONEncoder().encode(entries) {
            preferences.set(data, forKey: favoriteEntriesKey)
        }
    }

    func persistFavoritePhrases() {
        preferences.set(Array(favoritePhrases), forKey: favoritePhrasesKey)
        persistFavoritePhraseDates()
    }

    func persistFavoritePhraseDates() {
        let encoded = favoritePhraseDates.mapValues { $0.timeIntervalSince1970 }
        preferences.set(encoded, forKey: favoritePhraseDatesKey)
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
