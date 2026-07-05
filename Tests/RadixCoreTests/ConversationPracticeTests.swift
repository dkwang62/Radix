import Foundation
import Testing
@testable import RadixCore

@Suite("Conversation practice compatibility")
struct ConversationPracticeTests {
    @Test("Practice progress records completion and last practiced state")
    func practiceProgressRecordsCompletion() throws {
        let library = try loadConversationPackFixture().practiceLibrary
        let first = try #require(library.items.first)
        let second = try #require(library.items.dropFirst().first)
        let earlyDate = Date(timeIntervalSince1970: 1_750_000_000)
        let laterDate = Date(timeIntervalSince1970: 1_750_100_000)
        var snapshot = ConversationPracticeProgressSnapshot()

        snapshot.record(
            packID: library.set.id,
            itemID: first.id,
            outcome: .again,
            practicedAt: earlyDate
        )
        snapshot.record(
            packID: library.set.id,
            itemID: second.id,
            outcome: .correct,
            practicedAt: laterDate
        )

        let summary = snapshot.summary(for: library)
        #expect(summary.totalItems == library.items.count)
        #expect(summary.completedItems == 1)
        #expect(summary.lastPracticedAt == laterDate)
        #expect(snapshot.record(for: library.set.id, itemID: first.id)?.isCompleted == false)
        #expect(snapshot.record(for: library.set.id, itemID: second.id)?.isCompleted == true)
    }

    @Test("Practice progress merge keeps the newest item record")
    func practiceProgressMergeUsesNewestRecord() throws {
        let library = try loadConversationPackFixture().practiceLibrary
        let first = try #require(library.items.first)
        let earlyDate = Date(timeIntervalSince1970: 1_750_000_000)
        let laterDate = Date(timeIntervalSince1970: 1_750_100_000)
        let local = ConversationPracticeProgressSnapshot(records: [
            ConversationPracticeItemProgress(
                packID: library.set.id,
                itemID: first.id,
                attempts: 1,
                completedAttempts: 0,
                lastOutcome: .again,
                lastPracticedAt: earlyDate,
                completedAt: nil
            )
        ])
        let imported = ConversationPracticeProgressSnapshot(records: [
            ConversationPracticeItemProgress(
                packID: library.set.id,
                itemID: first.id,
                attempts: 2,
                completedAttempts: 1,
                lastOutcome: .easy,
                lastPracticedAt: laterDate,
                completedAt: laterDate
            )
        ])

        let merged = local.merging(imported)
        let record = try #require(merged.record(for: library.set.id, itemID: first.id))
        #expect(record.attempts == 2)
        #expect(record.lastOutcome == .easy)
        #expect(record.completedAt == laterDate)
    }

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
        #expect(pack.practiceItems.first?.phraseKey == "你好")
        #expect(pack.practiceItems.first?.simplified == "你好。")
        #expect(pack.practiceItems.first?.rank == 1)
        #expect(pack.practiceItems.first?.difficulty == .easy)
        #expect(pack.practiceItems.last?.id == "conv-100")
        #expect(pack.practiceItems.last?.rank == 100)
    }

    @Test("Conversation practice pack maps to phrase seeds and memberships")
    func packMapsToPhraseBackedLibrary() throws {
        let pack = try loadConversationPackFixture()
        let library = pack.practiceLibrary

        #expect(library.set.id == pack.packID)
        #expect(library.items.count == 100)
        #expect(library.phraseSeeds.count == 100)
        #expect(library.memberships.count == 100)
        #expect(library.phraseSeeds.first?.id == "你好")
        #expect(library.phraseSeeds.first?.simplified == "你好。")
        #expect(library.phraseSeeds.first?.pinyin == "Nǐ hǎo.")
        #expect(library.phraseSeeds.first?.english == "Hello.")
        #expect(library.phraseSeeds.first?.sourceItemID == "conv-001")
        #expect(library.memberships.first?.id == "\(pack.packID)#conv-001")
        #expect(library.memberships.first?.phraseKey == "你好")
        #expect(library.memberships.first?.rank == 1)
        #expect(library.phraseKeys.first == "你好")
        #expect(library.phraseKeys.last == "祝你一切顺利")
    }

    @Test("Sentence examples deduplicate normalized Chinese sentences")
    func sentenceExamplesDeduplicateNormalizedChinese() {
        let first = SentenceExampleRecord(
            chinese: "在这个关键时刻，我们需要冷静思考。",
            pinyin: "Zài zhège guānjiàn shíkè, wǒmen xūyào lěngjìng sīkǎo.",
            english: "At this crucial moment, we need to think calmly.",
            detectedPhrases: ["关键时刻"]
        )
        let duplicate = SentenceExampleRecord(
            chinese: "在这个关键时刻 我们需要冷静思考",
            pinyin: nil,
            english: nil,
            detectedPhrases: ["冷静思考"],
            isFavorited: true
        )

        let records = SentenceExampleRecord.upserting([duplicate], into: [first])

        #expect(records.count == 1)
        #expect(records.first?.pinyin == first.pinyin)
        #expect(records.first?.isFavorited == true)
        #expect(records.first?.detectedPhrases == ["关键时刻", "冷静思考"])
    }

    @Test("Conversation practice items map into canonical sentence examples")
    func practiceItemsMapToSentenceExamples() throws {
        let pack = try loadConversationPackFixture()
        let item = try #require(pack.practiceItems.first)
        let record = SentenceExampleRecord.fromPracticeItem(item, pack: pack)

        #expect(record.chinese == item.simplified)
        #expect(record.pinyin == item.pinyin)
        #expect(record.english == item.english)
        #expect(record.detectedCharacters.contains("你"))
        #expect(record.detectedPhrases.contains(item.phraseKey))
        #expect(record.sources.first?.practicePackID == pack.packID)
        #expect(record.sources.first?.practiceItemID == item.id)
    }

    @Test("Practice packs store ordered canonical sentence references")
    func practicePacksStoreOrderedCanonicalSentenceReferences() throws {
        let pack = try loadConversationPackFixture()
        let examples = pack.practiceItems.map {
            SentenceExampleRecord.fromPracticeItem($0, pack: pack)
        }

        let referencedPack = pack.withCanonicalSentenceReferences(from: examples)
        let firstReference = try #require(referencedPack.sentenceReferences.first)
        let firstItem = try #require(pack.practiceItems.first)
        let firstRecord = try #require(examples.first)

        #expect(referencedPack.sentenceReferences.count == pack.practiceItems.count)
        #expect(firstReference.practiceItemID == firstItem.id)
        #expect(firstReference.rank == firstItem.rank)
        #expect(firstReference.sentenceExampleID == firstRecord.id)
        #expect(firstReference.sentenceKey == firstRecord.normalizedChineseKey)
    }

    @Test("Legacy practice packs decode without sentence references")
    func legacyPracticePacksDecodeWithoutSentenceReferences() throws {
        let data = """
        {
          "pack_id": "legacy_pack",
          "version": "1.0",
          "title": "Legacy Pack",
          "description": "No sentence references yet",
          "language": "zh-Hans",
          "entries": [
            {
              "id": "legacy-001",
              "zh": "我们一起学习。",
              "pinyin": "Wǒmen yìqǐ xuéxí.",
              "en": "We study together."
            }
          ]
        }
        """.data(using: .utf8)!

        let pack = try JSONDecoder().decode(ConversationPracticePack.self, from: data)

        #expect(pack.sentenceReferences.isEmpty)
        #expect(pack.practiceItems.count == 1)
    }

    @Test("Legacy favorite sentence records hydrate canonical sentence examples")
    func favoriteSentenceRecordsHydrateSentenceExamples() {
        let favoritedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let favorite = FavoriteSentenceRecord(
            id: "sentence:学习中文很有意思",
            simplified: "学习中文很有意思。",
            pinyin: "Xuéxí Zhōngwén hěn yǒu yìsi.",
            english: "Learning Chinese is interesting.",
            sourceSetID: "starter",
            sourceItemID: "starter-001",
            phraseHints: ["学习中文"],
            characterHints: ["学", "习"],
            favoritedAt: favoritedAt
        )

        let record = SentenceExampleRecord.fromFavoriteSentence(favorite)

        #expect(record.chinese == favorite.simplified)
        #expect(record.isFavorited)
        #expect(record.createdAt == favoritedAt)
        #expect(record.containsCharacter("学"))
        #expect(record.containsPhrase("学习中文"))
        #expect(record.hasSourceType(.favoriteSentence))
        #expect(record.sources.first?.practiceItemID == "starter-001")
    }

    @Test("Canonical favorite examples build the Favorite Sentences library")
    func canonicalFavoriteExamplesBuildFavoriteLibrary() throws {
        let record = SentenceExampleRecord(
            chinese: "我想练习口语。",
            pinyin: "Wǒ xiǎng liànxí kǒuyǔ.",
            english: "I want to practice speaking.",
            detectedCharacters: ["我", "想"],
            detectedPhrases: ["练习口语"],
            isFavorited: true
        )

        let library = try #require(ConversationPracticeLibrary.favoriteSentencesLibrary(from: [record]))
        let item = try #require(library.items.first)

        #expect(library.set.id == ConversationPracticeTopic.favoriteSentencesID)
        #expect(library.set.itemCount == 1)
        #expect(item.simplified == record.chinese)
        #expect(item.pinyin == record.pinyin)
        #expect(item.english == record.english)
        #expect(item.phraseHints == ["练习口语"])
    }

    @Test("Sentence examples adapt to practice items for shared previews")
    func sentenceExamplesAdaptToPracticeItemsForSharedPreviews() {
        let record = SentenceExampleRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000818")!,
            chinese: "我想练习口语。",
            pinyin: "Wǒ xiǎng liànxí kǒuyǔ.",
            english: "I want to practice speaking.",
            targetCharacters: ["我", "想"],
            targetPhrases: ["练习口语"],
            difficulty: .medium,
            notes: "Useful spoken example",
            tags: ["speaking"]
        )

        let item = ConversationPracticeItem(sentenceExample: record, rank: 7)

        #expect(item.id == record.id.uuidString)
        #expect(item.setID == "sentence_examples")
        #expect(item.rank == 7)
        #expect(item.simplified == record.chinese)
        #expect(item.pinyin == record.pinyin)
        #expect(item.english == record.english)
        #expect(item.characterHints == ["我", "想"])
        #expect(item.phraseHints == ["练习口语"])
        #expect(item.difficulty == .medium)
        #expect(item.notes == "Useful spoken example")
    }

    @Test("Sentence examples expose page and source lookup helpers")
    func sentenceExamplesExposePageAndSourceLookupHelpers() {
        let pageID = UUID(uuidString: "00000000-0000-0000-0000-000000000515")!
        let source = SentenceExampleSourceReference(
            sourceType: .sentencePractice,
            sourceID: "page-515",
            sourceTitle: "News Page",
            sourcePageID: pageID,
            practicePackID: "pack-515",
            practiceItemID: "item-001"
        )
        let record = SentenceExampleRecord(
            chinese: "国际关系正在变化。",
            sources: [source],
            detectedPhrases: ["国际关系"]
        )

        #expect(record.isLinked(toPageID: pageID))
        #expect(record.hasSourceType(.sentencePractice))
        #expect(record.containsPhrase("国际关系"))
        #expect(record.containsCharacter("际"))
    }

    @Test("Radix Capture JSON blocks parse into sentence examples")
    func radixCaptureJSONBlocksParseIntoSentenceExamples() throws {
        let createdAt = Date(timeIntervalSince1970: 1_720_000_000)
        let pageID = UUID(uuidString: "00000000-0000-0000-0000-000000000616")!
        let response = """
        Here are the examples.

        [Radix Capture JSON]
        ```json
        {
          "source": {
            "source_type": "sentence_practice",
            "source_id": "page-616",
            "source_title": "China US News",
            "source_page_id": "\(pageID.uuidString)"
          },
          "sentences": [
            {
              "zh": "国际关系正在变化。",
              "pinyin": "Guójì guānxì zhèngzài biànhuà.",
              "en": "International relations are changing.",
              "phrases": ["国际关系"],
              "characters": ["国", "际"],
              "hsk_level": 5,
              "difficulty": "medium",
              "tags": ["news"]
            }
          ]
        }
        ```
        [/Radix Capture JSON]
        """

        let records = RadixCaptureJSONParser.sentenceExamples(from: response, createdAt: createdAt)
        let record = try #require(records.first)

        #expect(records.count == 1)
        #expect(record.chinese == "国际关系正在变化。")
        #expect(record.pinyin == "Guójì guānxì zhèngzài biànhuà.")
        #expect(record.english == "International relations are changing.")
        #expect(record.createdAt == createdAt)
        #expect(record.hskLevel == 5)
        #expect(record.difficulty == .medium)
        #expect(record.containsPhrase("国际关系"))
        #expect(record.isLinked(toPageID: pageID))
        #expect(record.sources.first?.sourceTitle == "China US News")
    }

    @Test("Radix Capture JSON supports sentence_examples and exact dedupe")
    func radixCaptureJSONSupportsSentenceExamplesAndDedupe() {
        let response = """
        [Radix Capture JSON]
        {
          "sentence_examples": [
            {
              "chinese": "我们需要保持冷静。",
              "english": "We need to stay calm.",
              "is_favorited": true
            },
            {
              "zh": "我们需要保持冷静",
              "pinyin": "Wǒmen xūyào bǎochí lěngjìng.",
              "en": "We need to stay calm."
            }
          ]
        }
        [/Radix Capture JSON]
        """

        let records = RadixCaptureJSONParser.sentenceExamples(from: response)

        #expect(records.count == 1)
        #expect(records.first?.isFavorited == true)
        #expect(records.first?.english == "We need to stay calm.")
        #expect(records.first?.pinyin == "Wǒmen xūyào bǎochí lěngjìng.")
    }

    @Test("Radix Capture JSON accepts top-level sentence arrays")
    func radixCaptureJSONAcceptsTopLevelSentenceArrays() throws {
        let response = """
        [Radix Capture JSON]
        [
          {
            "zh": "请再说一遍。",
            "pinyin": "Qǐng zài shuō yí biàn.",
            "en": "Please say it again."
          }
        ]
        [/Radix Capture JSON]
        """

        let record = try #require(RadixCaptureJSONParser.sentenceExamples(from: response).first)

        #expect(record.chinese == "请再说一遍。")
        #expect(record.detectedCharacters.contains("请"))
        #expect(record.sources.isEmpty)
    }

    @Test("OCR text captures sentence examples from corrected Chinese")
    func ocrTextCapturesSentenceExamplesFromCorrectedChinese() {
        let pageID = UUID(uuidString: "00000000-0000-0000-0000-000000000717")!
        let createdAt = Date(timeIntervalSince1970: 1_730_000_000)
        let records = SentenceExampleRecord.fromOCRText(
            """
            今天的会议很重要。请大家准时到达！
            A
            今天的会议很重要。
            """,
            sourcePageID: pageID,
            sourceTitle: "Meeting Notice",
            createdAt: createdAt
        )

        #expect(records.map(\.chinese) == ["今天的会议很重要", "请大家准时到达"])
        #expect(records.first?.createdAt == createdAt)
        #expect(records.first?.hasSourceType(.ocrSource) == true)
        #expect(records.first?.isLinked(toPageID: pageID) == true)
        #expect(records.first?.sources.first?.sourceTitle == "Meeting Notice")
        #expect(records.first?.tags == ["ocr"])
    }

    @Test("Conversation practice topics keep starter ordering and food generation brief")
    func defaultTopicsIncludeFoodExpansionTopic() {
        let topics = ConversationPracticeTopic.defaults

        #expect(topics.map(\.id).prefix(4) == [
            "general_greetings",
            "food_eating",
            "china_taiwan_travel",
            "shanghai_relocation_study"
        ])
        #expect(topics.map(\.id).suffix(10) == [
            "everyday_conversation",
            "food_shopping",
            "travel_transportation",
            "home_personal_life",
            "work_school",
            "health_emergencies",
            "city_life_services",
            "social_culture",
            "technology_modern_life",
            "opinions_deeper_talk"
        ])
        #expect(topics.first?.bundledResourceName == "conversation100")
        #expect(topics.first?.hasBundledContent == true)

        let food = ConversationPracticeTopic.topic(for: "food_eating")
        #expect(food.hasBundledContent == true)
        #expect(food.bundledResourceName == "Food Dining")
        #expect(food.targetSentenceCount == 100)
        #expect(food.generationBrief.contains("Restaurant"))
        #expect(food.situations.contains("ordering food in a restaurant"))
        #expect(food.situations.contains("offering food and responding politely"))

        let travel = ConversationPracticeTopic.topic(for: "china_taiwan_travel")
        #expect(travel.hasBundledContent == true)
        #expect(travel.bundledResourceName == "Trip to 4 cities")
        #expect(travel.targetSentenceCount == 100)
        #expect(travel.situations.contains("taking taxis, metro, trains, and airport transport"))

        let shanghai = ConversationPracticeTopic.topic(for: "shanghai_relocation_study")
        #expect(shanghai.hasBundledContent == true)
        #expect(shanghai.bundledResourceName == "Stay in Shanghai")
        #expect(shanghai.targetSentenceCount == 100)
        #expect(shanghai.situations.contains("finding housing and handling rent or utilities"))

        let everyday = ConversationPracticeTopic.topic(for: "everyday_conversation")
        #expect(everyday.hasBundledContent == false)
        #expect(everyday.title == "Everyday Conversation")
        #expect(everyday.targetSentenceCount == 100)
        #expect(everyday.generationBrief.contains("small talk"))

        let deeperTalk = ConversationPracticeTopic.topic(for: "opinions_deeper_talk")
        #expect(deeperTalk.hasBundledContent == false)
        #expect(deeperTalk.situations.contains("talking about emotions, goals, plans, and values"))
    }

    @Test("Food dining conversation pack decodes and validates")
    func foodDiningPackValidates() throws {
        let pack = try loadConversationPackFixture(named: "Food Dining")
        let result = ConversationPracticeRules.validate(pack)

        #expect(result.isValid)
        #expect(result.errors.isEmpty)
        #expect(pack.entries.count == 100)
        #expect(pack.packID == "food_restaurant")
        #expect(pack.practiceItems.first?.id == "food_restaurant_001")
        #expect(pack.practiceItems.first?.phraseKey == "你好，两位")
        #expect(pack.practiceItems.last?.id == "food_restaurant_100")
        #expect(pack.practiceItems.last?.rank == 100)
    }

    @Test("Trip to four cities conversation pack decodes and validates")
    func tripToFourCitiesPackValidates() throws {
        let pack = try loadConversationPackFixture(named: "Trip to 4 cities")
        let result = ConversationPracticeRules.validate(pack)

        #expect(result.isValid)
        #expect(result.errors.isEmpty)
        #expect(pack.entries.count == 100)
        #expect(pack.packID == "china_taiwan_travel")
        #expect(pack.practiceItems.first?.id == "travel_transport_001")
        #expect(pack.practiceItems.first?.phraseKey == "请带我去这个地址")
        #expect(pack.practiceItems.last?.id == "travel_transport_100")
        #expect(pack.practiceItems.last?.rank == 100)
    }

    @Test("Stay in Shanghai simplified conversation pack decodes and validates")
    func stayInShanghaiPackValidates() throws {
        let pack = try loadConversationPackFixture(named: "Stay in Shanghai")
        let result = ConversationPracticeRules.validate(pack)

        #expect(result.isValid)
        #expect(result.errors.isEmpty)
        #expect(pack.entries.count == 100)
        #expect(pack.packID == "shanghai_relocation_study")
        #expect(pack.sourceType == "conversation_pack")
        #expect(pack.createdFor == "Radix Conversation Practice")
        #expect(pack.practiceItems.first?.id == "edu_001")
        #expect(pack.practiceItems.first?.phraseKey == "我想咨询一下中文课程")
        #expect(pack.practiceItems.first?.rank == 1)
        #expect(pack.practiceItems.first?.difficulty == .easy)
        #expect(pack.practiceItems.first?.tags == ["education"])
        #expect(pack.practiceItems.last?.id == "admin_100")
        #expect(pack.practiceItems.last?.rank == 100)
    }

    @Test("Theme-only flat conversation practice JSON imports into a pack")
    func themeOnlyFlatPracticeJSONImports() throws {
        let data = Data("""
        {
          "theme": "Hobbies, Interests & Personal Time",
          "entries": [
            {
              "id": "hob_001",
              "zh": "你平时有什么爱好？",
              "pinyin": "Nǐ píngshí yǒu shénme àihào?",
              "en": "What hobbies do you have in your spare time?"
            },
            {
              "id": "hob_002",
              "zh": "我喜欢听音乐。",
              "pinyin": "Wǒ xǐhuan tīng yīnyuè.",
              "en": "I like listening to music."
            }
          ]
        }
        """.utf8)

        let pack = try JSONDecoder().decode(ConversationPracticePack.self, from: data)
        let result = ConversationPracticeRules.validate(pack)

        #expect(result.isValid)
        #expect(result.errors.isEmpty)
        #expect(pack.packID == "hobbies_interests_personal_time")
        #expect(pack.title == "Hobbies, Interests & Personal Time")
        #expect(pack.sourceType == "user_imported_practice")
        #expect(pack.entries.count == 2)
        #expect(pack.practiceItems.first?.rank == 1)
        #expect(pack.practiceItems.first?.category == "hobbies_interests_personal_time")
        #expect(pack.practiceItems.first?.phraseKey == "你平时有什么爱好")
        #expect(pack.practiceItems.first?.tags == ["hobbies_interests_personal_time"])
    }

    @Test("Conversation practice packs preserve saved-page source links")
    func practicePackPreservesSavedPageSourceLink() throws {
        let sourceID = UUID(uuidString: "00000000-0000-0000-0000-000000000202")!
        let data = Data("""
        {
          "theme": "China US News",
          "source_link": {
            "kind": "saved_page",
            "source_id": "\(sourceID.uuidString)",
            "source_title": "China US News",
            "source_created_at": "2026-07-04T00:00:00Z"
          },
          "entries": [
            {
              "id": "news_001",
              "zh": "这条新闻很重要。",
              "pinyin": "Zhè tiáo xīnwén hěn zhòngyào.",
              "en": "This news item is important."
            }
          ]
        }
        """.utf8)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let pack = try decoder.decode(ConversationPracticePack.self, from: data)
        let relinked = pack.withSourceLink(.savedPage(
            id: sourceID,
            title: "China US News",
            createdAt: Date(timeIntervalSince1970: 1_783_209_600)
        ))
        let roundTrip = try decoder.decode(ConversationPracticePack.self, from: try encoder.encode(relinked))

        #expect(pack.sourceLink?.kind == .savedPage)
        #expect(pack.sourceLink?.sourcePageID == sourceID)
        #expect(pack.sourceLink?.sourceTitle == "China US News")
        #expect(roundTrip.sourceLink?.sourcePageID == sourceID)
        #expect(roundTrip.sourceLink?.sourceTitle == "China US News")
        #expect(roundTrip.practiceItems.first?.phraseKey == "这条新闻很重要")
    }

    @Test("Pasted conversation practice JSON can be extracted from AI fences")
    func pastedPracticeJSONCandidatesHandleAIFences() throws {
        let pasted = """
        Here is the JSON:

        ```json
        {
          "theme": "Page Sentences",
          "entries": [
            {
              "id": "page_sentence_001",
              "zh": "请先付款。",
              "pinyin": "Qǐng xiān fùkuǎn.",
              "en": "Please pay first."
            }
          ]
        }
        ```
        """

        let candidates = ConversationPracticeRules.importJSONCandidates(from: pasted)
        let pack = try JSONDecoder().decode(
            ConversationPracticePack.self,
            from: Data(candidates.last?.utf8 ?? pasted.utf8)
        )

        #expect(candidates.count == 2)
        #expect(pack.title == "Page Sentences")
        #expect(pack.entries.count == 1)
        #expect(ConversationPracticeRules.validate(pack).isValid)
    }

    @Test("Unknown conversation practice topic falls back to default starter topic")
    func unknownTopicFallsBackToGeneralGreetings() {
        #expect(ConversationPracticeTopic.topic(for: "missing").id == "general_greetings")
    }

    @Test("Conversation practice quiz choices are stable and include the answer")
    func quizChoicesAreStableAndIncludeAnswer() throws {
        let pack = try loadConversationPackFixture()
        let library = pack.practiceLibrary
        let item = try #require(library.items.first)

        let choices = ConversationPracticeQuizRules.choices(for: item, in: library.items)
        let repeatedChoices = ConversationPracticeQuizRules.choices(for: item, in: library.items)

        #expect(choices.count == 4)
        #expect(choices.map(\.id) == repeatedChoices.map(\.id))
        #expect(choices.contains { $0.id == item.id })
        #expect(Set(choices.map(\.id)).count == choices.count)
    }

    @Test("Conversation practice character quiz uses component-sharing character choices")
    func characterQuizUsesComponentSharingChoices() throws {
        let pack = try loadConversationPackFixture()
        let item = try #require(pack.practiceLibrary.items.first)
        let candidates = [
            ConversationPracticeQuizRules.CharacterChoiceCandidate(character: "请", components: ["讠", "青"], rank: 10),
            ConversationPracticeQuizRules.CharacterChoiceCandidate(character: "情", components: ["忄", "青"], rank: 11),
            ConversationPracticeQuizRules.CharacterChoiceCandidate(character: "清", components: ["氵", "青"], rank: 12),
            ConversationPracticeQuizRules.CharacterChoiceCandidate(character: "晴", components: ["日", "青"], rank: 13),
            ConversationPracticeQuizRules.CharacterChoiceCandidate(character: "好", components: ["女", "子"], rank: 1)
        ]

        let choices = ConversationPracticeQuizRules.characterChoices(for: "请", from: candidates)
        let repeatedChoices = ConversationPracticeQuizRules.characterChoices(for: "请", from: candidates)
        let answerComponents = Set(candidates[0].components)
        let distractorComponents = Dictionary(uniqueKeysWithValues: candidates.map { ($0.character, Set($0.components)) })

        #expect(ConversationPracticeQuizRules.questionCharacter(for: item) == "好")
        #expect(choices.count == 4)
        #expect(choices == repeatedChoices)
        #expect(choices.contains("请"))
        #expect(!choices.contains("好"))
        #expect(choices.filter { $0 != "请" }.allSatisfy { character in
            guard let components = distractorComponents[character] else { return false }
            return !components.isDisjoint(with: answerComponents)
        })
    }

    @Test("Conversation practice character quiz blanks the sentence and prefers confusable characters")
    func characterQuizBlanksSentenceAndPrefersConfusableCharacters() throws {
        let pack = try JSONDecoder().decode(ConversationPracticePack.self, from: Data("""
        {
          "pack_id": "quiz_target_fixture",
          "version": "1.0",
          "title": "Quiz Target Fixture",
          "description": "Fixture",
          "language": "zh-Hans",
          "source_type": "conversation_pack",
          "created_for": "Radix Chinese",
          "entries": [
            {
              "id": "target-001",
              "sequence": 1,
              "category": "travel",
              "level": "easy",
              "sentence": {
                "zh": "你打算去哪里度假？",
                "pinyin": "Nǐ dǎsuàn qù nǎlǐ dùjià?",
                "en": "Where do you plan to go on vacation?"
              },
              "analysis": {
                "characters": ["你", "打", "算", "去", "哪", "里", "度", "假"],
                "phrases": ["打算", "去", "哪里", "度假"]
              },
              "metadata": { "difficulty": 1, "frequency": 1, "tags": ["travel"] },
              "notes": ""
            }
          ]
        }
        """.utf8))

        let item = try #require(pack.practiceLibrary.items.first)
        let candidates = [
            ConversationPracticeQuizRules.CharacterChoiceCandidate(character: "你", components: ["亻", "尔"]),
            ConversationPracticeQuizRules.CharacterChoiceCandidate(character: "打", components: ["扌", "丁"]),
            ConversationPracticeQuizRules.CharacterChoiceCandidate(character: "把", components: ["扌", "巴"]),
            ConversationPracticeQuizRules.CharacterChoiceCandidate(character: "找", components: ["扌", "戈"]),
            ConversationPracticeQuizRules.CharacterChoiceCandidate(character: "算", components: ["竹", "目", "廾"]),
            ConversationPracticeQuizRules.CharacterChoiceCandidate(character: "管", components: ["竹", "官"]),
            ConversationPracticeQuizRules.CharacterChoiceCandidate(character: "答", components: ["竹", "合"]),
            ConversationPracticeQuizRules.CharacterChoiceCandidate(character: "等", components: ["竹", "寺"]),
            ConversationPracticeQuizRules.CharacterChoiceCandidate(character: "鼻", components: ["自", "田", "廾"]),
            ConversationPracticeQuizRules.CharacterChoiceCandidate(character: "去", components: ["土", "厶"])
        ]
        let question = ConversationPracticeQuizRules.characterQuestion(for: item, candidates: candidates)

        #expect(question.character == "算")
        #expect(question.blankedSentence == "你打＿去哪里度假？")
        #expect(!question.blankedSentence.contains(question.character))
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
        try loadConversationPackFixture(named: "conversation100")
    }

    private func loadConversationPackFixture(named resourceName: String) throws -> ConversationPracticePack {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fixtureURL = repoRoot.appendingPathComponent("\(resourceName).json")
        let data = try Data(contentsOf: fixtureURL)
        return try JSONDecoder().decode(ConversationPracticePack.self, from: data)
    }
}
