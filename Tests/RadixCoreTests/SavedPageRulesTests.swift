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

    @Test("Page artifact types declare deletion ownership")
    func pageArtifactOwnership() {
        #expect(SavedPageRules.ownership(for: .correctedOCRPage) == .pageOwned)
        #expect(SavedPageRules.ownership(for: .translation) == .pageOwned)
        #expect(SavedPageRules.ownership(for: .quiz) == .pageOwned)
        #expect(SavedPageRules.ownership(for: .extractedSentencePractice) == .pageOwned)
        #expect(SavedPageRules.ownership(for: .pageConversationPractice) == .pageOwned)
        #expect(SavedPageRules.ownership(for: .pageLocalNotes) == .pageOwned)
        #expect(SavedPageRules.ownership(for: .pageAIResult) == .pageOwned)

        #expect(SavedPageRules.ownership(for: .addedPhrase) == .linked)
        #expect(SavedPageRules.ownership(for: .favoriteCharacter) == .linked)
        #expect(SavedPageRules.ownership(for: .favoritePhrase) == .linked)
        #expect(SavedPageRules.ownership(for: .favoriteSentence) == .linked)
        #expect(SavedPageRules.ownership(for: .globalNote) == .linked)
        #expect(SavedPageRules.ownership(for: .reusablePracticeProgress) == .linked)
    }

    @Test("Artifact descriptor uses stable source/type/item identity")
    func pageArtifactDescriptorIdentity() {
        let pageID = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
        let descriptor = PageArtifactDescriptor(
            sourcePageID: pageID,
            artifactType: .pageConversationPractice,
            artifactID: "china-us-discussion",
            displayTitle: "China US Discussion",
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let linked = PageArtifactDescriptor(
            sourcePageID: pageID,
            artifactType: .favoriteSentence,
            artifactID: "sentence-1",
            displayTitle: "Favorite sentence"
        )

        #expect(descriptor.id == "00000000-0000-0000-0000-000000000101:pageConversationPractice:china-us-discussion")
        #expect(descriptor.ownership == .pageOwned)
        #expect(SavedPageRules.isDeletedWithPage(descriptor))
        #expect(linked.ownership == .linked)
        #expect(!SavedPageRules.isDeletedWithPage(linked))
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
