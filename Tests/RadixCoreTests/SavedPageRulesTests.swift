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
        #expect(SavedPageRules.ownership(for: .aiCleanedPage) == .pageOwned)
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

    @Test("AI-cleaned page records are page-owned artifacts")
    func aiCleanedPageRecordDescriptor() {
        let pageID = UUID(uuidString: "00000000-0000-0000-0000-000000000303")!
        let record = AICleanedPageRecord(
            sourcePageID: pageID,
            sourceTitle: " Original News ",
            cleanedTitle: " China US Relations ",
            cleanedChineseText: " 中美关系正在变化。 ",
            sentences: [
                AICleanedPageSentence(
                    id: " s1 ",
                    chinese: " 中美关系正在变化。 ",
                    english: " China-US relations are changing. ",
                    phraseHints: [" 中美关系 ", "", "变化"]
                )
            ],
            englishSummary: " ",
            repairNotes: [" expanded headline shorthand ", ""],
            createdAt: Date(timeIntervalSince1970: 300)
        )
        let descriptor = record.artifactDescriptor

        #expect(record.id == pageID)
        #expect(record.sourceTitle == "Original News")
        #expect(record.cleanedTitle == "China US Relations")
        #expect(record.cleanedChineseText == "中美关系正在变化。")
        #expect(record.sentences.first?.id == "s1")
        #expect(record.sentences.first?.chinese == "中美关系正在变化。")
        #expect(record.sentences.first?.english == "China-US relations are changing.")
        #expect(record.sentences.first?.phraseHints == ["中美关系", "变化"])
        #expect(record.englishSummary == nil)
        #expect(record.repairNotes == ["expanded headline shorthand"])
        #expect(descriptor.id == "00000000-0000-0000-0000-000000000303:aiCleanedPage:00000000-0000-0000-0000-000000000303")
        #expect(descriptor.ownership == .pageOwned)
        #expect(SavedPageRules.isDeletedWithPage(descriptor))
    }

    @Test("AI-cleaned page import parser accepts fenced JSON")
    func aiCleanedPageImportParserAcceptsFencedJSON() throws {
        let pageID = UUID(uuidString: "00000000-0000-0000-0000-000000000404")!
        let response = """
        Here is the cleaned page:

        ```json
        {
          "cleaned_title": "Cleaned News",
          "cleaned_chinese_text": "中美关系正在变化。",
          "sentences": [
            {
              "id": "ai_page_sentence_001",
              "chinese": "中美关系正在变化。",
              "pinyin": "Zhōng-Měi guānxì zhèngzài biànhuà.",
              "english": "China-US relations are changing.",
              "phrase_hints": ["中美关系", "变化"]
            }
          ],
          "english_summary": "A short summary.",
          "repair_notes": ["Expanded a headline fragment."]
        }
        ```
        """
        let record = try AICleanedPageImportParser.parse(
            response,
            sourcePageID: pageID,
            sourceTitle: "Original Page",
            createdAt: Date(timeIntervalSince1970: 400)
        )

        #expect(record.sourcePageID == pageID)
        #expect(record.sourceTitle == "Original Page")
        #expect(record.cleanedTitle == "Cleaned News")
        #expect(record.cleanedChineseText == "中美关系正在变化。")
        #expect(record.sentences.count == 1)
        #expect(record.sentences.first?.pinyin == "Zhōng-Měi guānxì zhèngzài biànhuà.")
        #expect(record.sentences.first?.phraseHints == ["中美关系", "变化"])
        #expect(record.englishSummary == "A short summary.")
        #expect(record.repairNotes == ["Expanded a headline fragment."])
        #expect(record.createdAt == Date(timeIntervalSince1970: 400))
    }

    @Test("AI-cleaned page import parser salvages Gemini key variants")
    func aiCleanedPageImportParserSalvagesGeminiKeyVariants() throws {
        let pageID = UUID(uuidString: "00000000-0000-0000-0000-000000000405")!
        let response = """
        {
          "page": {
            "title": "Gemini News",
            "cleanedText": "中美关系正在变化。双方正在保持沟通。",
            "sentence_list": [
              {
                "zh": "中美关系正在变化。",
                "pinyin": "Zhōng-Měi guānxì zhèngzài biànhuà.",
                "en": "China-US relations are changing.",
                "phrases": "中美关系，变化"
              },
              {
                "sentence": "双方正在保持沟通。",
                "translation": "Both sides are maintaining communication.",
                "keyPhrases": ["保持沟通"]
              }
            ],
            "summary": "A summary.",
            "notes": "Gemini used alternate keys."
          }
        }
        """

        let record = try AICleanedPageImportParser.parse(
            response,
            sourcePageID: pageID,
            sourceTitle: "Original Page",
            createdAt: Date(timeIntervalSince1970: 405)
        )

        #expect(record.cleanedTitle == "Gemini News")
        #expect(record.cleanedChineseText == "中美关系正在变化。双方正在保持沟通。")
        #expect(record.sentences.map(\.id) == ["ai_page_sentence_001", "ai_page_sentence_002"])
        #expect(record.sentences.first?.chinese == "中美关系正在变化。")
        #expect(record.sentences.first?.english == "China-US relations are changing.")
        #expect(record.sentences.first?.phraseHints == ["中美关系", "变化"])
        #expect(record.sentences.last?.chinese == "双方正在保持沟通。")
        #expect(record.sentences.last?.english == "Both sides are maintaining communication.")
        #expect(record.sentences.last?.phraseHints == ["保持沟通"])
        #expect(record.englishSummary == "A summary.")
        #expect(record.repairNotes == ["Gemini used alternate keys."])
    }

    @Test("AI-cleaned page import parser derives sentences from cleaned prose")
    func aiCleanedPageImportParserDerivesSentencesFromCleanedProse() throws {
        let pageID = UUID(uuidString: "00000000-0000-0000-0000-000000000406")!
        let response = """
        {
          "cleaned_title": "Prose Only",
          "cleaned_chinese_text": "中美关系正在变化。双方正在保持沟通。"
        }
        """

        let record = try AICleanedPageImportParser.parse(
            response,
            sourcePageID: pageID,
            sourceTitle: "Original Page",
            createdAt: Date(timeIntervalSince1970: 406)
        )

        #expect(record.cleanedTitle == "Prose Only")
        #expect(record.sentences.map(\.id) == ["ai_page_sentence_001", "ai_page_sentence_002"])
        #expect(record.sentences.map(\.chinese) == ["中美关系正在变化", "双方正在保持沟通"])
    }

    @Test("AI-cleaned page import parser accepts top-level sentence arrays")
    func aiCleanedPageImportParserAcceptsTopLevelSentenceArrays() throws {
        let pageID = UUID(uuidString: "00000000-0000-0000-0000-000000000407")!
        let response = """
        [
          {
            "zh": "中美关系正在变化。",
            "en": "China-US relations are changing.",
            "phrases": ["中美关系"]
          }
        ]
        """

        let record = try AICleanedPageImportParser.parse(
            response,
            sourcePageID: pageID,
            sourceTitle: "Original Page",
            createdAt: Date(timeIntervalSince1970: 407)
        )

        #expect(record.cleanedTitle == "Original Page")
        #expect(record.cleanedChineseText == "中美关系正在变化。")
        #expect(record.sentences.first?.id == "ai_page_sentence_001")
        #expect(record.sentences.first?.english == "China-US relations are changing.")
        #expect(record.sentences.first?.phraseHints == ["中美关系"])
    }

    @Test("AI-cleaned page import parser extracts prose-wrapped top-level arrays")
    func aiCleanedPageImportParserExtractsProseWrappedTopLevelArrays() throws {
        let pageID = UUID(uuidString: "00000000-0000-0000-0000-000000000408")!
        let response = """
        You are correct. Here is the complete sentence list:

        [
          {
            "zh": "中美关系正在变化。",
            "pinyin": "Zhōng-Měi guānxì zhèngzài biànhuà.",
            "en": "China-US relations are changing."
          },
          {
            "zh": "双方正在保持沟通。",
            "en": "Both sides are maintaining communication."
          }
        ]
        """

        let record = try AICleanedPageImportParser.parse(
            response,
            sourcePageID: pageID,
            sourceTitle: "Original Page",
            createdAt: Date(timeIntervalSince1970: 408)
        )

        #expect(record.sentences.count == 2)
        #expect(record.sentences.first?.chinese == "中美关系正在变化。")
        #expect(record.sentences.first?.pinyin == "Zhōng-Měi guānxì zhèngzài biànhuà.")
        #expect(record.sentences.last?.english == "Both sides are maintaining communication.")
    }

    @Test("AI-cleaned page import parser salvages non-JSON Chinese response text")
    func aiCleanedPageImportParserSalvagesNonJSONChineseResponseText() throws {
        let pageID = UUID(uuidString: "00000000-0000-0000-0000-000000000409")!
        let response = """
        Gemini could not produce JSON, but the cleaned sentences are:

        1. 中美关系正在变化。
        2. 双方正在保持沟通。

        Please import what is usable.
        """

        let record = try AICleanedPageImportParser.parse(
            response,
            sourcePageID: pageID,
            sourceTitle: "Original Page",
            createdAt: Date(timeIntervalSince1970: 409)
        )

        #expect(record.cleanedTitle == "Original Page")
        #expect(record.sentences.map(\.chinese) == [
            "中美关系正在变化",
            "双方正在保持沟通"
        ])
        #expect(record.repairNotes == [
            "Imported Chinese sentence fragments from a non-JSON AI response."
        ])
    }

    @Test("Page phrase extraction records preserve page links and deduplicate words")
    func pagePhraseExtractionRecordDeduplicatesWords() {
        let pageID = UUID(uuidString: "00000000-0000-0000-0000-000000000202")!
        let record = PagePhraseExtractionRecord(
            sourcePageID: pageID,
            sourceTitle: "China News",
            phraseWords: [" 中美 ", "关系", "中美", ""],
            extractedAt: Date(timeIntervalSince1970: 100)
        )
        let merged = record.merging(
            words: ["科技", "关系"],
            title: "China News Updated",
            extractedAt: Date(timeIntervalSince1970: 200)
        )

        #expect(record.id == pageID)
        #expect(record.phraseWords == ["中美", "关系"])
        #expect(merged.sourceTitle == "China News Updated")
        #expect(merged.phraseWords == ["中美", "关系", "科技"])
        #expect(merged.extractedAt == Date(timeIntervalSince1970: 200))
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
