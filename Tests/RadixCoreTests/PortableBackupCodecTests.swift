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
        let aiCleanedPage = AICleanedPageRecord(
            sourcePageID: UUID(uuidString: "00000000-0000-0000-0000-000000000404")!,
            sourceTitle: "Original Page",
            cleanedTitle: "Cleaned Page",
            cleanedChineseText: "你好。",
            sentences: [
                AICleanedPageSentence(
                    id: "ai_page_sentence_001",
                    chinese: "你好。",
                    pinyin: "Nǐ hǎo.",
                    english: "Hello.",
                    phraseHints: ["你好"]
                )
            ],
            englishSummary: "Greeting.",
            repairNotes: ["None"],
            createdAt: exportedAt
        )
        let package = UnifiedPackage(
            schemaVersion: PortableBackupCodec.currentSchemaVersion,
            exportedAt: exportedAt,
            backupID: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"),
            phrases: [phrase],
            profile: UserProfile(
                schemaVersion: 1,
                favouritesList: ["学"],
                aiSentenceExtractionDetail: SentenceExtractionDetail.detailed.rawValue
            ),
            conversationPracticePacks: [practicePack],
            conversationPracticeProgress: practiceProgress,
            favoriteSentences: [favoriteSentence],
            pagePhraseExtractions: [pagePhraseExtraction],
            aiCleanedPages: [aiCleanedPage]
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
        #expect(decoded.profile.aiSentenceExtractionDetail == SentenceExtractionDetail.detailed.rawValue)
        #expect(decoded.conversationPracticePacks == [practicePack])
        #expect(decoded.conversationPracticeProgress == practiceProgress)
        #expect(decoded.favoriteSentences == [favoriteSentence])
        #expect(decoded.pagePhraseExtractions == [pagePhraseExtraction])
        #expect(decoded.aiCleanedPages == [aiCleanedPage])
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
        #expect(decoded.aiCleanedPages == nil)
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

    @Test("Advanced full dataset includes latest portable memory")
    func fullDatasetCarriesPortableBackupPayload() throws {
        let exportedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let phrase = PhraseItem(word: "学习", pinyin: "xué xí", meanings: "to study")
        let sentence = SentenceExampleRecord(
            chinese: "我喜欢学习中文。",
            pinyin: "Wǒ xǐhuān xuéxí Zhōngwén.",
            english: "I like studying Chinese.",
            sources: [
                SentenceExampleSourceReference(
                    sourceType: .conversationPractice,
                    sourceID: "study",
                    sourceTitle: "Study",
                    sourcePageID: nil,
                    practicePackID: nil,
                    practiceItemID: nil
                )
            ],
            targetPhrases: ["学习"]
        )
        let pageID = UUID(uuidString: "00000000-0000-0000-0000-000000000505")!
        let page = CharacterCollection(
            id: pageID,
            name: "Saved Page",
            characters: ["学", "习"],
            createdAt: exportedAt,
            sourceType: .manual,
            isFavorite: false
        )
        let portableBackup = UnifiedPackage(
            schemaVersion: PortableBackupCodec.currentSchemaVersion,
            exportedAt: exportedAt,
            backupID: UUID(uuidString: "BBBBBBBB-CCCC-DDDD-EEEE-FFFFFFFFFFFF"),
            dictionaryPatchOverlay: DictionaryOverlayPatchPackage(schemaVersion: 2, customEntries: [:], patches: [], deletions: []),
            phrases: [phrase],
            profile: UserProfile(schemaVersion: 1, favouritesList: ["学"]),
            collections: [page],
            sentenceExamples: [sentence],
            pagePhraseExtractions: [
                PagePhraseExtractionRecord(
                    sourcePageID: pageID,
                    sourceTitle: "Saved Page",
                    phraseWords: ["学习"],
                    extractedAt: exportedAt
                )
            ],
            apiKeys: APIKeyBackup(openAI: "", gemini: "gemini-key", claude: "", deepSeek: "", custom: "")
        )
        let package = FullDatasetExportPackage(
            schemaVersion: 2,
            exportedAt: exportedAt,
            dictionary: [
                "学": RawComponentEntry(
                    relatedCharacters: [],
                    meta: RawMeta(
                        variant: nil,
                        additionalVariants: nil,
                        pinyin: .single("xué"),
                        definition: "study",
                        decomposition: nil,
                        idc: nil,
                        radical: nil,
                        strokes: nil,
                        compounds: nil,
                        etymology: nil,
                        notes: nil
                    )
                )
            ],
            phrases: [phrase],
            portableBackup: portableBackup
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(package)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(FullDatasetExportPackage.self, from: data)

        #expect(decoded.schemaVersion == 2)
        #expect(decoded.dictionary.keys.contains("学"))
        #expect(decoded.phrases == [phrase])
        #expect(decoded.portableBackup.schemaVersion == PortableBackupCodec.currentSchemaVersion)
        #expect(decoded.portableBackup.collections == [page])
        #expect(decoded.portableBackup.sentenceExamples?.count == 1)
        #expect(decoded.portableBackup.sentenceExamples?.first?.chinese == sentence.chinese)
        #expect(decoded.portableBackup.sentenceExamples?.first?.targetPhrases == ["学习"])
        #expect(decoded.portableBackup.sentenceExamples?.first?.sources.first?.sourceType == .conversationPractice)
        #expect(decoded.portableBackup.pagePhraseExtractions?.first?.phraseWords == ["学习"])
        #expect(decoded.portableBackup.apiKeys?.gemini == "gemini-key")
    }
}
