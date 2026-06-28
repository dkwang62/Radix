import Foundation
import Testing
@testable import RadixCore

@Suite("Conversation practice compatibility")
struct ConversationPracticeTests {
    @Test("Uploaded conversation pack decodes and validates")
    func uploadedConversationPackValidates() throws {
        let pack = try loadConversationPackFixture()
        let result = ConversationPracticeRules.validate(pack)

        #expect(result.isValid)
        #expect(result.errors.isEmpty)
        #expect(pack.entries.count == 100)
        #expect(pack.practiceSet.id == "radix_conversation_pack_100_common_sentences_zh_hans")
        #expect(pack.practiceItems.first?.id == "conv-001")
        #expect(pack.practiceItems.first?.setID == pack.packID)
        #expect(pack.practiceItems.first?.phraseKey == "你好。")
        #expect(pack.practiceItems.first?.rank == 1)
        #expect(pack.practiceItems.first?.difficulty == .easy)
        #expect(pack.practiceItems.last?.id == "conv-100")
        #expect(pack.practiceItems.last?.rank == 100)
    }

    @Test("Conversation practice validation rejects duplicate and incomplete rows")
    func validationRejectsBadRows() throws {
        let data = Data("""
        {
          "pack_id": "bad_pack",
          "version": "1.0",
          "title": "Bad Pack",
          "description": "Validation fixture",
          "language": "zh-Hans",
          "source_type": "conversation_pack",
          "created_for": "Radix Chinese",
          "entries": [
            {
              "id": "dup",
              "sequence": 1,
              "category": "Greetings",
              "level": "Beginner",
              "sentence": { "zh": "你好。", "pinyin": "Nǐ hǎo.", "en": "Hello." },
              "analysis": { "characters": ["你", "好"], "phrases": ["你好"] },
              "metadata": { "difficulty": 1, "frequency": 10, "tags": ["conversation"] },
              "notes": ""
            },
            {
              "id": "dup",
              "sequence": 1,
              "category": "",
              "level": "Beginner",
              "sentence": { "zh": "你好。", "pinyin": "", "en": "Hello again." },
              "analysis": { "characters": ["你"], "phrases": [] },
              "metadata": { "difficulty": 0, "frequency": 0, "tags": [""] },
              "notes": ""
            }
          ]
        }
        """.utf8)

        let pack = try JSONDecoder().decode(ConversationPracticePack.self, from: data)
        let result = ConversationPracticeRules.validate(pack)

        #expect(!result.isValid)
        #expect(result.errors.contains { $0.message.contains("Duplicate entry id") })
        #expect(result.errors.contains { $0.message.contains("Duplicate sequence") })
        #expect(result.errors.contains { $0.message.contains("Duplicate Chinese sentence") })
        #expect(result.errors.contains { $0.message.contains("Missing required field 'category'") })
        #expect(result.errors.contains { $0.message.contains("Missing required field 'sentence.pinyin'") })
        #expect(result.errors.contains { $0.message.contains("Difficulty must be at least 1") })
        #expect(result.errors.contains { $0.message.contains("Tags must not be empty") })
        #expect(result.warnings.contains { $0.message.contains("Frequency must be at least 1") })
    }

    private func loadConversationPackFixture() throws -> ConversationPracticePack {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fixtureURL = repoRoot.appendingPathComponent("conversation100.json")
        let data = try Data(contentsOf: fixtureURL)
        return try JSONDecoder().decode(ConversationPracticePack.self, from: data)
    }
}
