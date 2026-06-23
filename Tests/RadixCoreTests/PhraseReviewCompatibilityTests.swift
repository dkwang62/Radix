import Foundation
import Testing
@testable import RadixCore

@Suite("Phrase review compatibility")
struct PhraseReviewCompatibilityTests {
    @Test("Stored status values remain stable while labels stay clear")
    func stablePersistenceValues() throws {
        #expect(PhraseReviewStatus.checked.rawValue == "checked")
        #expect(PhraseReviewStatus.checked.title == "Accepted")
        #expect(PhraseReviewStatus.removed.rawValue == "removed")
        #expect(PhraseReviewStatus.removed.title == "Rejected")

        let phrase = PhraseItem(
            word: "关键时刻",
            pinyin: "guān jiàn shí kè",
            meanings: "critical moment",
            reviewStatus: .checked
        )
        let data = try JSONEncoder().encode(phrase)
        let decoded = try JSONDecoder().decode(PhraseItem.self, from: data)
        #expect(decoded.reviewStatus == .checked)
    }

    @Test("Classification cycle retains its established order")
    func classificationCycle() {
        #expect(PhraseReviewStatusTool.nextStatus(after: nil) == .removed)
        #expect(PhraseReviewStatusTool.nextStatus(after: .removed) == .checked)
        #expect(PhraseReviewStatusTool.nextStatus(after: .checked) == .hidden)
        #expect(PhraseReviewStatusTool.nextStatus(after: .hidden) == nil)
    }
}
