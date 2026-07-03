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
