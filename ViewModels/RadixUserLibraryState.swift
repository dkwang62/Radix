import Foundation

/// Persisted user-library data shared by favorites, backups, and data editing.
/// This deliberately excludes device-only presentation and speech preferences.
struct RadixUserLibraryState {
    var favoriteCharacters: Set<String> = []
    var favoriteCharacterDates: [String: Date] = [:]
    var favoritePhrases: Set<String> = []
    var favoritePhraseDates: [String: Date] = [:]
    var overlayAddedDates: [String: Date] = [:]
}
