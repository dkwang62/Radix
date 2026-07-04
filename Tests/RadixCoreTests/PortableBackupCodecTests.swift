import Foundation
import Testing
@testable import RadixCore

@Suite("Portable backup compatibility")
struct PortableBackupCodecTests {
    private let codec = PortableBackupCodec()

    @Test("Schema 5 round-trips dates and user data")
    func roundTripCurrentSchema() throws {
        let exportedAt = Date(timeIntervalSince1970: 1_750_000_000)
        let phrase = PhraseItem(
            word: "学习",
            pinyin: "xué xí",
            meanings: "to study",
            addedAt: exportedAt,
            reviewStatus: .checked,
            lastReviewedAt: exportedAt
        )
        let practiceData = """
        {
          "theme": "Test Topic",
          "entries": [
            {
              "id": "test_topic_001",
              "zh": "你好。",
              "pinyin": "Nǐ hǎo.",
              "en": "Hello."
            }
          ]
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let practicePack = try decoder.decode(ConversationPracticePack.self, from: practiceData)
        let practiceProgress = ConversationPracticeProgressSnapshot(records: [
            ConversationPracticeItemProgress(
                packID: practicePack.packID,
                itemID: "test_topic_001",
                attempts: 2,
                completedAttempts: 1,
                lastOutcome: .good,
                lastPracticedAt: exportedAt,
                completedAt: exportedAt
            )
        ])
        let favoriteSentence = FavoriteSentenceRecord(
            id: "sentence:你好。",
            simplified: "你好。",
            pinyin: "Nǐ hǎo.",
            english: "Hello.",
            sourceSetID: practicePack.packID,
            sourceItemID: "test_topic_001",
            phraseHints: ["你好。"],
            characterHints: ["你", "好"],
            favoritedAt: exportedAt
        )
        let pagePhraseExtraction = PagePhraseExtractionRecord(
            sourcePageID: UUID(uuidString: "00000000-0000-0000-0000-000000000303")!,
            sourceTitle: "China News",
            phraseWords: ["学习"],
            extractedAt: exportedAt
        )
        let package = UnifiedPackage(
            schemaVersion: PortableBackupCodec.currentSchemaVersion,
            exportedAt: exportedAt,
            backupID: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"),
            phrases: [phrase],
            profile: UserProfile(schemaVersion: 1, favouritesList: ["学"]),
            conversationPracticePacks: [practicePack],
            conversationPracticeProgress: practiceProgress,
            favoriteSentences: [favoriteSentence],
            pagePhraseExtractions: [pagePhraseExtraction]
        )

        let data = try codec.encode(package)
        guard case .unified(let decoded) = try codec.decode(data) else {
            Issue.record("Expected a unified backup")
            return
        }

        #expect(decoded.schemaVersion == 5)
        #expect(decoded.exportedAt == exportedAt)
        #expect(decoded.phrases == [phrase])
        #expect(decoded.profile.favouritesList == ["学"])
        #expect(decoded.conversationPracticePacks == [practicePack])
        #expect(decoded.conversationPracticeProgress == practiceProgress)
        #expect(decoded.favoriteSentences == [favoriteSentence])
        #expect(decoded.pagePhraseExtractions == [pagePhraseExtraction])
    }

    @Test("Legacy Apple reference dates still decode")
    func decodesLegacyDateFormat() throws {
        let package = UnifiedPackage(
            schemaVersion: 4,
            exportedAt: Date(timeIntervalSinceReferenceDate: 123_456),
            phrases: [],
            profile: UserProfile(schemaVersion: 1, favouritesList: [])
        )
        let encoder = JSONEncoder()
        let legacyData = try encoder.encode(package)

        guard case .unified(let decoded) = try codec.decode(legacyData) else {
            Issue.record("Expected a unified legacy backup")
            return
        }
        #expect(decoded.schemaVersion == 4)
        #expect(decoded.exportedAt == package.exportedAt)
        #expect(decoded.conversationPracticePacks == nil)
        #expect(decoded.conversationPracticeProgress == nil)
        #expect(decoded.favoriteSentences == nil)
    }

    @Test("Empty and future backups fail safely")
    func rejectsInvalidVersions() throws {
        #expect(throws: PortableBackupCodecError.self) {
            try codec.decode(Data())
        }

        let future = UnifiedPackage(
            schemaVersion: PortableBackupCodec.currentSchemaVersion + 1,
            phrases: [],
            profile: UserProfile(schemaVersion: 1, favouritesList: [])
        )
        #expect(throws: PortableBackupCodecError.self) {
            try codec.decode(try codec.encode(future))
        }
    }

    @Test("Legacy dictionary-only backups remain accepted")
    func decodesLegacyDictionary() throws {
        let metadata = RawMeta(
            variant: nil,
            additionalVariants: nil,
            pinyin: .single("xué"),
            definition: "study",
            decomposition: nil,
            idc: nil,
            radical: "子",
            strokes: .int(8),
            compounds: nil,
            etymology: nil,
            notes: nil
        )
        let legacy = ["学": RawComponentEntry(relatedCharacters: [], meta: metadata)]
        let data = try JSONEncoder().encode(legacy)

        guard case .legacyDictionary(let decoded) = try codec.decode(data) else {
            Issue.record("Expected a legacy dictionary backup")
            return
        }
        #expect(decoded == legacy)
    }
}
