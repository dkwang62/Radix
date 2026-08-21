import Testing
@testable import RadixCore

@Suite("Browse page grid visibility")
struct BrowsePageGridVisibilityTests {
    private let characterKeys = ["你", "好", "你", "好", "啊", "学", "习", "啊"]
    private let spans = [
        0: BrowsePageGridPhraseSpan(start: 0, end: 2, phraseKey: "你好"),
        2: BrowsePageGridPhraseSpan(start: 2, end: 4, phraseKey: "你好"),
        5: BrowsePageGridPhraseSpan(start: 5, end: 7, phraseKey: "学习")
    ]

    @Test("All mode preserves every phrase occurrence and loose character")
    func allModePreservesReadingStream() {
        let visibleItems = BrowsePageGridVisibilityRules.visibleItems(
            characterKeys: characterKeys,
            phraseSpans: spans,
            filter: .all
        )

        #expect(visibleItems == [
            .phrase(offset: 0),
            .phrase(offset: 2),
            .character(offset: 4),
            .phrase(offset: 5),
            .character(offset: 7)
        ])
    }

    @Test("Unique mode keeps first phrase and first non-phrase character occurrence")
    func uniqueModeCondensesDuplicatePhrasesAndCharacters() {
        let visibleItems = BrowsePageGridVisibilityRules.visibleItems(
            characterKeys: characterKeys,
            phraseSpans: spans,
            filter: .unique
        )

        #expect(visibleItems == [
            .phrase(offset: 0),
            .character(offset: 4),
            .phrase(offset: 5)
        ])
    }
}
