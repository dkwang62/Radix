import XCTest
import Combine

final class RadixStoreTests: XCTestCase {
    var store: RadixStore!
    
    @MainActor
    override func setUp() async throws {
        store = RadixStore()
        await store.initializeForTesting()
    }
    
    @MainActor
    func testUnifiedExportImport() async throws {
        // 1. Set some specific state
        store.dataEditCharacter = "木"
        store.dataEditDefinition = "Wood Test"
        store.dataEditIsFavourite = true
        try store.saveDataEdit()
        
        // 2. Export
        let data = try store.exportDataEditData()
        
        // 3. Clear state (simulate fresh app)
        store.setFavorite(character: "木", isFavorite: false)
        store.dataEditDefinition = "Empty"
        
        // 4. Import
        try store.importDataEditData(data)
        
        // 5. Verify
        XCTAssertTrue(store.isFavorite("木"))
        
        // Load the character again to check dictionary data
        store.loadDataEditEntry(for: "木")
        XCTAssertEqual(store.dataEditDefinition, "Wood Test")
    }
    
    @MainActor
    func testPhraseIntegration() async throws {
        let testChar = "大"
        store.loadDataEditEntry(for: testChar)
        
        let initialCount = store.dataEditPhrases.count
        let uniqueWord = "大\(UUID().uuidString.prefix(4))"
        
        // Add a new phrase
        let newPhrase = PhraseItem(word: uniqueWord, pinyin: "da test", meanings: "test phrase")
        store.dataEditPhrases.append(newPhrase)
        
        XCTAssertEqual(store.dataEditPhrases.count, initialCount + 1)
        
        try store.saveDataEdit()
        
        // Refresh and check
        store.loadDataEditEntry(for: testChar)
        
        XCTAssertEqual(store.dataEditPhrases.count, initialCount + 1, "Count should be incremented after save/load")
        XCTAssertTrue(store.dataEditPhrases.contains(where: { $0.word == uniqueWord }), "The phrase grid should contain the new unique word: \(uniqueWord)")
        
        // Cleanup
        store.removeDataEditPhrase(word: uniqueWord)
        store.loadDataEditEntry(for: testChar)
        XCTAssertEqual(store.dataEditPhrases.count, initialCount, "Count should be back to initial after delete")
    }

    @MainActor
    func testPhraseOnlySaveWithoutSelectedCharacterPersistsToAddDatabase() async throws {
        let uniqueWord = "惊鸿\(UUID().uuidString.prefix(4))"
        store.dataEditCharacter = ""
        store.dataEditPhrases = [PhraseItem(word: uniqueWord, pinyin: "jing hong", meanings: "test phrase")]

        try store.saveDataEdit()

        let exported = try store.exportDataEditData()
        let package = try JSONDecoder().decode(UnifiedPackage.self, from: exported)

        XCTAssertTrue(
            package.phrases.contains(where: { $0.word == uniqueWord && $0.pinyin == "jing hong" && $0.meanings == "test phrase" }),
            "Phrase-only saves should persist even when no dictionary character is selected."
        )

        store.removeDataEditPhrase(word: uniqueWord)
    }

    @MainActor
    func testFavouriteEntriesImportPreservesDatesAndSortsNewestFirst() throws {
        let olderDate = Date(timeIntervalSince1970: 1_700_000_000)
        let newerDate = Date(timeIntervalSince1970: 1_800_000_000)
        let profile = UserProfile(
            schemaVersion: 2,
            favouritesList: ["木", "林"],
            favouriteEntries: [
                FavouriteProfileEntry(character: "木", addedAt: olderDate),
                FavouriteProfileEntry(character: "林", addedAt: newerDate)
            ],
            selectedCharacter: nil,
            searchMode: nil,
            scriptFilter: nil,
            promptConfig: nil,
            promptSelectedTaskIDs: nil
        )

        let data = try JSONEncoder().encode(profile)
        try store.importProfileData(data)

        XCTAssertEqual(store.favoriteItems.map(\.character), ["林", "木"])
        XCTAssertEqual(store.favoriteAddedDate(for: "木")?.timeIntervalSince1970, olderDate.timeIntervalSince1970)
        XCTAssertEqual(store.favoriteAddedDate(for: "林")?.timeIntervalSince1970, newerDate.timeIntervalSince1970)
    }
}
