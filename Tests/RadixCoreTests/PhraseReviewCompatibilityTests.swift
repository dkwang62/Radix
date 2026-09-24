import Foundation
import Testing
@testable import RadixCore

@Suite("Phrase review compatibility")
struct PhraseReviewCompatibilityTests {
    @Test("Phrase persistence can canonicalize Traditional words without losing learning data")
    func phraseCanonicalizationPreservesLearningData() {
        let phrase = PhraseItem(
            word: "關鍵時刻",
            pinyin: "guān jiàn shí kè",
            meanings: "critical moment",
            notes: "Keep this note",
            addedAt: Date(timeIntervalSince1970: 10),
            reviewStatus: .checked,
            lastReviewedAt: Date(timeIntervalSince1970: 20)
        )

        let converted = phrase.simplifiedChinese {
            $0.applyingTransform(StringTransform("Hant-Hans"), reverse: false) ?? $0
        }

        #expect(converted.word == "关键时刻")
        #expect(converted.pinyin == phrase.pinyin)
        #expect(converted.meanings == phrase.meanings)
        #expect(converted.notes == phrase.notes)
        #expect(converted.reviewStatus == phrase.reviewStatus)
        #expect(converted.lastReviewedAt == phrase.lastReviewedAt)
    }

    @Test("Traditional and Simplified phrase duplicates merge into one retained learning record")
    func phraseDuplicateMigrationPreservesNotesAndReviewState() {
        let phrases = [
            PhraseItem(
                word: "關鍵時刻", pinyin: "guān jiàn shí kè", meanings: "critical moment",
                notes: "Older note", addedAt: Date(timeIntervalSince1970: 10), reviewStatus: .hidden,
                lastReviewedAt: Date(timeIntervalSince1970: 20)
            ),
            PhraseItem(
                word: "关键时刻", pinyin: "guān jiàn shí kè", meanings: "turning point",
                notes: "Newer note", addedAt: Date(timeIntervalSince1970: 30), reviewStatus: .checked,
                lastReviewedAt: Date(timeIntervalSince1970: 40)
            )
        ]

        let migrated = PhraseStorageRules.canonicalized(phrases) {
            $0.applyingTransform(StringTransform("Hant-Hans"), reverse: false) ?? $0
        }

        #expect(migrated.count == 1)
        #expect(migrated[0].word == "关键时刻")
        #expect(migrated[0].notes == "Newer note\n\nOlder note")
        #expect(migrated[0].reviewStatus == .checked)
        #expect(migrated[0].lastReviewedAt == Date(timeIntervalSince1970: 40))
        #expect(migrated[0].addedAt == Date(timeIntervalSince1970: 10))
    }

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
        #expect(PhraseReviewStatusTool.nextStatus(after: nil) == .checked)
        #expect(PhraseReviewStatusTool.nextStatus(after: .checked) == .hidden)
        #expect(PhraseReviewStatusTool.nextStatus(after: .hidden) == .removed)
        #expect(PhraseReviewStatusTool.nextStatus(after: .removed) == nil)
    }

    @Test("Phrase note overlays merge without duplicating notes")
    func phraseNoteOverlayMerge() {
        #expect(PhraseNoteOverlayRules.tableName == "phrase_note_overlays")
        #expect(PhraseNoteOverlayRules.mergeNotes("", "Book note") == "Book note")
        #expect(PhraseNoteOverlayRules.mergeNotes("Dictionary note", "") == "Dictionary note")
        #expect(PhraseNoteOverlayRules.mergeNotes("Dictionary note", "Book note") == "Dictionary note\n\nBook note")
        #expect(PhraseNoteOverlayRules.mergeNotes("Dictionary note\n\nBook note", "Book note") == "Dictionary note\n\nBook note")
    }

    @Test("AI review page includes only unreviewed non-base multi-character phrases")
    func aiReviewPageWords() {
        let phrases = [
            PhraseItem(word: "水", pinyin: "shuǐ", meanings: "water"),
            PhraseItem(word: "爆仓", pinyin: "bào cāng", meanings: "forced liquidation"),
            PhraseItem(word: "关键时刻", pinyin: "guān jiàn shí kè", meanings: "critical moment", reviewStatus: .checked),
            PhraseItem(word: "美股", pinyin: "měi gǔ", meanings: "US stocks"),
            PhraseItem(word: "自动清洁", pinyin: "zì dòng qīng jié", meanings: "automatic cleaning"),
            PhraseItem(word: "人民", pinyin: "rén mín", meanings: "people")
        ]

        let words = AddedPhraseReviewRules.aiReviewWords(
            from: phrases,
            isBasePhrase: { $0 == "人民" }
        )

        #expect(words == ["爆仓", "美股", "自动清洁"])
        #expect(AddedPhraseReviewRules.aiReviewPageName == "AI Review")
        #expect(AddedPhraseReviewRules.aiReviewPageText(from: phrases, isBasePhrase: { $0 == "人民" }) == "爆仓\n美股\n自动清洁")
    }

    @Test("Added phrase review ordering and page labels follow pinyin")
    func pinyinReviewOrderAndRangeLabels() {
        let phrases = [
            PhraseItem(word: "美股", pinyin: "měi gǔ", meanings: "US stocks"),
            PhraseItem(word: "爆仓", pinyin: "bào cāng", meanings: "forced liquidation"),
            PhraseItem(word: "采访车", pinyin: "cǎi fǎng chē", meanings: "interview vehicle"),
            PhraseItem(word: "自动清洁", pinyin: "zì dòng qīng jié", meanings: "automatic cleaning")
        ]

        let sorted = AddedPhraseReviewRules.sortedByPinyin(phrases)

        #expect(sorted.map(\.word) == ["爆仓", "采访车", "美股", "自动清洁"])
        #expect(AddedPhraseReviewRules.pinyinRangeLabel(for: Array(sorted.prefix(2))) == "b-c")
        #expect(AddedPhraseReviewRules.pinyinRangeLabel(for: [sorted[2]]) == "m")
    }

    @Test("AI review page text is absent when no eligible phrases remain")
    func emptyAIReviewPageText() {
        let phrases = [
            PhraseItem(word: "水", pinyin: "shuǐ", meanings: "water"),
            PhraseItem(word: "关键时刻", pinyin: "guān jiàn shí kè", meanings: "critical moment", reviewStatus: .checked),
            PhraseItem(word: "人民", pinyin: "rén mín", meanings: "people")
        ]

        #expect(AddedPhraseReviewRules.aiReviewPageText(from: phrases, isBasePhrase: { $0 == "人民" }) == nil)
    }
}
