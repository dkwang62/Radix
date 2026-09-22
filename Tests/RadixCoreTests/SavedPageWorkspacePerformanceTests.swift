import Foundation
import Testing
@testable import RadixCore

@Suite("Saved-page workspace performance")
@MainActor
struct SavedPageWorkspacePerformanceTests {
    @Test("Switching Browse and Study for the selected page does not rewrite pages")
    func selectedPageWorkspaceSwitchIsPersistenceFree() {
        let preferences = CountingNavigationPreferenceStore()
        let store = RadixStore(preferences: preferences)
        let pageID = UUID()
        store.allCollections = [CharacterCollection(
            id: pageID,
            name: "Page",
            characters: ["学", "习"],
            createdAt: Date(timeIntervalSince1970: 100),
            sourceType: .manual,
            isFavorite: false
        )]

        store.selectBrowseCollection(id: pageID)
        let initialWriteCount = preferences.setCount(forKey: RadixPreferenceKey.collections)
        let initialViewedAt = store.collection(id: pageID)?.lastViewedAt

        store.goToPagesWorkspace(id: pageID)
        #expect(store.route == .favourites)
        #expect(preferences.setCount(forKey: RadixPreferenceKey.collections) == initialWriteCount)
        #expect(store.collection(id: pageID)?.lastViewedAt == initialViewedAt)

        store.goToBrowseCollection(id: pageID)
        #expect(store.route == .search)
        #expect(store.homeTab == .filter)
        #expect(preferences.setCount(forKey: RadixPreferenceKey.collections) == initialWriteCount)
        #expect(store.collection(id: pageID)?.lastViewedAt == initialViewedAt)
    }

    @Test("Selecting a different page still updates and persists its viewed date")
    func differentPageSelectionStillPersists() {
        let preferences = CountingNavigationPreferenceStore()
        let store = RadixStore(preferences: preferences)
        let firstID = UUID()
        let secondID = UUID()
        store.allCollections = [
            CharacterCollection(
                id: firstID,
                name: "First",
                characters: ["一"],
                createdAt: Date(timeIntervalSince1970: 100),
                sourceType: .manual,
                isFavorite: false
            ),
            CharacterCollection(
                id: secondID,
                name: "Second",
                characters: ["二"],
                createdAt: Date(timeIntervalSince1970: 200),
                sourceType: .manual,
                isFavorite: false
            )
        ]

        store.selectBrowseCollection(id: firstID)
        let initialWriteCount = preferences.setCount(forKey: RadixPreferenceKey.collections)
        store.selectBrowseCollection(id: secondID)

        #expect(store.selectedBrowseCollectionID == secondID)
        #expect(store.collection(id: secondID)?.lastViewedAt != nil)
        #expect(preferences.setCount(forKey: RadixPreferenceKey.collections) == initialWriteCount + 1)
    }
}

private final class CountingNavigationPreferenceStore: RadixPreferenceStore, @unchecked Sendable {
    private var values: [String: Any] = [:]
    private var setCounts: [String: Int] = [:]

    func data(forKey key: String) -> Data? { values[key] as? Data }
    func string(forKey key: String) -> String? { values[key] as? String }
    func bool(forKey key: String) -> Bool { values[key] as? Bool ?? false }
    func integer(forKey key: String) -> Int { values[key] as? Int ?? 0 }
    func double(forKey key: String) -> Double { values[key] as? Double ?? 0 }
    func array(forKey key: String) -> [Any]? { values[key] as? [Any] }
    func dictionary(forKey key: String) -> [String: Any]? { values[key] as? [String: Any] }
    func object(forKey key: String) -> Any? { values[key] }

    func set(_ value: Any?, forKey key: String) {
        values[key] = value
        setCounts[key, default: 0] += 1
    }

    func removeObject(forKey key: String) {
        values.removeValue(forKey: key)
    }

    func setCount(forKey key: String) -> Int {
        setCounts[key, default: 0]
    }
}
