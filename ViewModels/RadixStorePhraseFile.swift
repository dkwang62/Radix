import Foundation

/*
 RADIX STORE — PHRASE FILE MANAGEMENT
 ======================================
 Handles overriding and exporting the custom phrases add-DB file.
 Thin coordination layer between phraseRepo and the UI status string.
*/

extension RadixStore {

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
        try phraseRepo.exportAddDatabaseData()
    }

    @discardableResult
    func importAddPhrasesDatabase(from sourceURL: URL, mode: RestoreMode) throws -> Int {
        let importedCount = try phraseRepo.importAddDatabase(from: sourceURL, mode: mode)
        refreshAddedPhrases()
        syncDataEditPhraseCaches()
        dataEditPhrases = addedPhrases
        refreshAddedPhraseReviewPhrases()
        phraseCache.removeAll()
        browsePagePhraseTileCache.removeAll()
        browsePagePhraseCandidateCache.removeAll()
        invalidateConversationPracticeHintCache()
        favoriteSentenceRevision += 1
        return importedCount
    }
}
