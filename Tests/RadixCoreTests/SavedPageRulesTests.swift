import Foundation
import Testing
@testable import RadixCore

@Suite("Saved-page portability rules")
struct SavedPageRulesTests {
    @Test("Most recent page uses viewed date with created-date fallback")
    func mostRecentPage() {
        let olderViewed = page(created: 30, viewed: 20)
        let newerCreated = page(created: 40, viewed: nil)
        let newestViewed = page(created: 10, viewed: 50)

        #expect(SavedPageRules.mostRecentID(in: [olderViewed, newerCreated, newestViewed]) == newestViewed.id)
    }

    @Test("Corrected names preserve the prefix and advance a numeric suffix")
    func correctedNames() {
        let original = "调配能量产品精油喷雾等"
        let first = SavedPageRules.correctedName(originalName: original, existingNames: [])
        let second = SavedPageRules.correctedName(originalName: original, existingNames: [first])

        #expect(first.count <= SavedPageRules.maximumNameLength)
        #expect(first.hasSuffix("1"))
        #expect(second.hasSuffix("2"))
        #expect(first.dropLast() == second.dropLast())
    }

    private func page(created: TimeInterval, viewed: TimeInterval?) -> CharacterCollection {
        CharacterCollection(
            id: UUID(),
            name: "Page",
            characters: ["中"],
            createdAt: Date(timeIntervalSince1970: created),
            lastViewedAt: viewed.map(Date.init(timeIntervalSince1970:)),
            sourceType: .ocr,
            isFavorite: false
        )
    }
}
