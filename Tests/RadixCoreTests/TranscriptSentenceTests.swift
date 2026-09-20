import Foundation
import Testing
@testable import RadixCore

@Suite("Transcript sentences")
struct TranscriptSentenceTests {
    let valid = """
    [{"id":"ai_page_sentence_001","chinese":"他是一个学生。","pinyin":"tā shì yí gè xué shēng","english":"He is a student.","phrase_hints":["学生"]}]
    """

    @Test func importsBilingualArrayAndPreservesPageLink() throws {
        let id = UUID()
        for response in [valid, "```json\n\(valid)\n```"] {
            let record = try TranscriptSentenceImportParser.parse(response, sourcePageID: id, sourceTitle: "Transcript")
            #expect(record.sourcePageID == id)
            #expect(record.sentences.count == 1)
            #expect(record.sentences.first?.pinyin == "tā shì yí gè xué shēng")
            #expect(record.sentences.first?.english == "He is a student.")
            #expect(record.sentences.first?.phraseHints == ["学生"])
            #expect(SentenceExampleRecord.fromAICleanedPage(record).count == 1)
        }
    }

    @Test func rejectsProviderErrorsAndIncompleteResults() {
        for response in ["Service unavailable", "他是一个学生。", "[]", "[{\"chinese\":\"学生\"}]",
                         valid.replacingOccurrences(of: "tā shì yí gè xué shēng", with: ""),
                         valid.replacingOccurrences(of: "He is a student.", with: "")] {
            #expect(throws: (any Error).self) {
                try TranscriptSentenceImportParser.parse(response, sourcePageID: UUID(), sourceTitle: "Transcript")
            }
        }
    }
    @Test func mismatchedOptionalHintsDoNotRejectUsersSentences() throws {
        let response = #"""
        [
          {
            "id": "ai_page_sentence_038",
            "chinese": "《經濟學人》講得很明白，台灣有做AI的技術、能耐與代口實力，就應該自己做自己弄。",
            "pinyin": "jīn jì xué rén jiǎng de hěn míng bái tái wān yǒu zuò AI de jì shù néng nài yǔ dài gōng shí lì jiù yīng gāi zì jǐ zuò zì jǐ nòng",
            "english": "The Economist made it plain: Taiwan has the technology, capability, and manufacturing strength in AI, so it should produce things domestically.",
            "phrase_hints": ["技術", "代工實力"]
          },
          {
            "id": "ai_page_sentence_061",
            "chinese": "上海辦公室空置率上升20%，租金下跌6%，外商因政策反覆與缺乏法律及智財權保障而外逃。",
            "pinyin": "shàng hǎi bàn gōng shì kōng zhì lǜ shàng shēng èr shí bái fēn diǎn zū jīn xià diē liù bái fēn diǎn wài shāng yīn zhèng cè fǎn fù yǔ quē fá fǎ lǜ yǔ zhì cái quán bǎo zhàng ér wài táo",
            "english": "Shanghai office vacancy rates rose 20% while rents fell 6%, with foreign firms fleeing inconsistent policies and lack of legal and IP protections.",
            "phrase_hints": ["空置率", "智慧財產權"]
          }
        ]
        """#
        let record = try parse(response)
        #expect(record.sentences.count == 2)
        #expect(record.sentences[0].id == "ai_page_sentence_038")
        #expect(record.sentences[0].chinese.contains("代口實力"))
        #expect(record.sentences[0].phraseHints == ["技術"])
        #expect(record.sentences[1].phraseHints == ["空置率"])
        #expect(record.repairNotes.first?.contains("2 phrase hint(s)") == true)
    }

    @Test func acceptsPresentationWrappersTrailingCommasAndMissingMetadata() throws {
        let object = #"{"chinese":"学生说：\"好，]\"。","pinyin":"xué shēng shuō hǎo","english":"The student says: \"Good,]\".",}"#
        for response in [object, "[\(object),]", "Here is the result:\n```json\n[\(object)]\n```\nDone.",
                         "{\"sentences\":[\(object)],}", "{\"entries\":[\(object)]}"] {
            let record = try parse(response)
            #expect(record.sentences.count == 1)
            #expect(record.sentences[0].id == "ai_page_sentence_001")
            #expect(record.sentences[0].chinese == "学生说：\"好，]\"。")
            #expect(record.sentences[0].phraseHints.isEmpty)
        }
    }

    @Test func supportsObjectListsAndExistingFieldAliases() throws {
        let object = #"{"sentence":"学生。","pin_yin":"xué shēng","translation":"Student."}"#
        let record = try parse(object + ",\n" + object + ",")
        #expect(record.sentences.count == 2)
        #expect(Set(record.sentences.map(\.id)).count == 2)
    }

    @Test func duplicateIDsAreRepairedWithoutLosingSentences() throws {
        let object = String(valid.dropFirst().dropLast())
        let record = try parse("[\(object),\(object)]")
        #expect(record.sentences.count == 2)
        #expect(record.sentences.map(\.id) == ["ai_page_sentence_001", "ai_page_sentence_002"])
    }

    @Test func truncatedOrPartiallyInvalidListsAreNeverPartiallyImported() {
        let object = String(valid.dropFirst().dropLast())
        for input in ["[" + object, "[" + object + ",", object + ", {\"chinese\":", 
                      "[" + object + ", {\"chinese\":\"坏\"}]",
                      "[" + object + ", null]", "{\"sentences\":[]}"] {
            #expect(throws: (any Error).self) { try parse(input) }
        }
    }

    private func parse(_ text: String) throws -> AICleanedPageRecord {
        try TranscriptSentenceImportParser.parse(text, sourcePageID: UUID(), sourceTitle: "Transcript")
    }

}
