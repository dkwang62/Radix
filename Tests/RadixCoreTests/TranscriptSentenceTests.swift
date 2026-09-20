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
                         valid.replacingOccurrences(of: "He is a student.", with: ""),
                         valid.replacingOccurrences(of: "[\"学生\"]", with: "[\"老师\"]")] {
            #expect(throws: (any Error).self) {
                try TranscriptSentenceImportParser.parse(response, sourcePageID: UUID(), sourceTitle: "Transcript")
            }
        }
    }
}
