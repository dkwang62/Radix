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
        let url = phraseRepo.currentAddDBURL
        return try Data(contentsOf: url)
    }
}
