import Foundation
import Testing
@testable import RadixCore

@Suite("AI prompt compatibility")
struct PromptConfigTests {
    @Test("Legacy Check OCR templates normalize to page-character review")
    func legacyOCRTemplateNormalizes() {
        let legacy = PromptTask(
            id: "task7",
            title: "Check OCR",
            template: """
            Check OCR

            You are checking Chinese OCR against the attached source image and dictionary evidence from Radix.

            ORIGINAL OCR:
            {ocr_original}
            """
        )
        let config = PromptConfig(
            version: 1,
            preamble: "",
            tasks: [legacy],
            epilogue: "",
            collectionPreamble: "",
            collectionEpilogue: ""
        )

        let normalized = config.normalized()
        let template = normalized.tasks.first { $0.id == "task7" }?.template ?? ""

        #expect(template.contains("SAVED PAGE CHARACTERS:"))
        #expect(template.contains("saved page characters as the main input"))
        #expect(!template.contains("ORIGINAL OCR:"))
    }

    @Test("Conversation practice generator task is built in but not a default character task")
    func practiceGeneratorTaskAvailability() {
        let normalized = PromptConfig.streamlitDefault.normalized()
        let generator = normalized.tasks.first { $0.id == "task9" }

        #expect(generator?.title == "Generate Practice Pack")
        #expect(generator?.template.contains("{practice_topic_title}") == true)
        #expect(generator?.template.contains("\"theme\": \"{practice_topic_title}\"") == true)
        #expect(generator?.template.contains("Use any context you have from this chat") == true)
        #expect(generator?.template.contains("If you can browse, search, or use current knowledge") == true)
        #expect(generator?.template.contains("timely everyday scenarios and popular topics of the day") == true)
        #expect(generator?.template.contains("Create exactly {conversation_entry_count} entries") == true)
        #expect(generator?.template.contains("Each entry must have exactly these keys: \"id\", \"zh\", \"pinyin\", and \"en\".") == true)
        #expect(generator?.template.contains("Prefer concise studyable entries, but do not enforce a maximum Chinese character count.") == true)
        #expect(generator?.template.contains("Every zh value must be no more than") == false)
        #expect(generator?.template.contains("\"pack_id\"") == false)
        #expect(PromptConfig.practiceTopicTaskIDs == ["task9"])
        #expect(PromptConfig.conversationEntryCountTaskIDs.contains("task9"))
        #expect(!PromptConfig.defaultSelectedTaskIDs.contains("task9"))
    }

    @Test("Page sentence extractor is a saved-page AI task")
    func pageSentenceExtractorTaskAvailability() {
        let normalized = PromptConfig.streamlitDefault.normalized()
        let extractor = normalized.tasks.first { $0.id == "task10" }

        #expect(extractor?.title == "Extract Page Sentences")
        #expect(extractor?.template.contains("Conversation Practice import pack") == true)
        #expect(extractor?.template.contains("\"theme\": \"{collection_name}\"") == true)
        #expect(extractor?.template.contains("Set \"theme\" exactly to the Page value above") == true)
        #expect(extractor?.template.contains("\"id\": \"page_sentence_001\"") == true)
        #expect(extractor?.template.contains("Aim for up to {conversation_entry_count} entries") == true)
        #expect(extractor?.template.contains("Each entry must have exactly these keys: \"id\", \"zh\", \"pinyin\", and \"en\".") == true)
        #expect(extractor?.template.contains("Prefer concise studyable entries, but do not enforce a maximum Chinese character count.") == true)
        #expect(extractor?.template.contains("Every zh value must be no more than") == false)
        #expect(PromptConfig.collectionTaskIDs.contains("task10"))
        #expect(PromptConfig.conversationEntryCountTaskIDs.contains("task10"))
        #expect(!PromptConfig.defaultSelectedTaskIDs.contains("task10"))
    }

    @Test("Page practice generator is a saved-page AI task")
    func pagePracticeGeneratorTaskAvailability() {
        let normalized = PromptConfig.streamlitDefault.normalized()
        let generator = normalized.tasks.first { $0.id == "task11" }

        #expect(generator?.title == "Create Conversation")
        #expect(generator?.template.contains("source inspiration") == true)
        #expect(generator?.template.contains("Use the page as a springboard, not a cage") == true)
        #expect(generator?.template.contains("Use any context you have from this chat") == true)
        #expect(generator?.template.contains("popular topics of the day") == true)
        #expect(generator?.template.contains("\"id\": \"page_practice_001\"") == true)
        #expect(generator?.template.contains("Create exactly {conversation_entry_count} entries") == true)
        #expect(generator?.template.contains("Each entry must have exactly these keys: \"id\", \"zh\", \"pinyin\", and \"en\".") == true)
        #expect(generator?.template.contains("Prefer concise studyable entries, but do not enforce a maximum Chinese character count.") == true)
        #expect(generator?.template.contains("Every zh value must be no more than") == false)
        #expect(PromptConfig.collectionTaskIDs.contains("task11"))
        #expect(PromptConfig.conversationEntryCountTaskIDs.contains("task11"))
        #expect(!PromptConfig.defaultSelectedTaskIDs.contains("task11"))
    }

    @Test("Page quiz prompt stays in AI chat and defaults to simplified")
    func pageQuizPromptDefaultsToSimplifiedChatQuiz() {
        let normalized = PromptConfig.streamlitDefault.normalized()
        let quiz = normalized.tasks.first { $0.id == "task8" }

        #expect(quiz?.title == "Create Quiz")
        #expect(quiz?.template.contains("Simplified Chinese by default") == true)
        #expect(quiz?.template.contains("If the learner asks for Traditional Chinese") == true)
        #expect(quiz?.template.contains("using Simplified Chinese by default") == true)
        #expect(quiz?.template.contains("Then ask Question 1 only.") == true)
        #expect(PromptConfig.collectionTaskIDs.contains("task8"))
        #expect(!PromptConfig.defaultSelectedTaskIDs.contains("task8"))
    }

    @Test("Legacy page quiz prompts normalize to simplified chat quiz")
    func legacyPageQuizPromptNormalizes() {
        let legacy = PromptTask(
            id: "task8",
            title: "Create Quiz",
            template: """
            Create Quiz

            You are a patient Chinese language teacher creating a standard language-learning practice quiz from one captured Radix page.

            Default quiz settings:
            - Difficulty: 5/10 unless the learner asks for a different level.
            """
        )
        let config = PromptConfig(
            version: 1,
            preamble: "",
            tasks: [legacy],
            epilogue: "",
            collectionPreamble: "",
            collectionEpilogue: ""
        )

        let template = config.normalized().tasks.first { $0.id == "task8" }?.template ?? ""

        #expect(template.contains("Simplified Chinese by default"))
        #expect(template.contains("If the learner asks for Traditional Chinese"))
    }

    @Test("Conversation AI entry counts are shared and normalized")
    func conversationEntryCountConfiguration() {
        #expect(PromptConfig.defaultConversationEntryCount == 25)
        #expect(PromptConfig.conversationEntryCountOptions == [25, 50, 100])
        #expect(PromptConfig.normalizedConversationEntryCount(25) == 25)
        #expect(PromptConfig.normalizedConversationEntryCount(50) == 50)
        #expect(PromptConfig.normalizedConversationEntryCount(100) == 100)
        #expect(PromptConfig.normalizedConversationEntryCount(0) == 25)
        #expect(PromptConfig.normalizedConversationEntryCount(30) == 25)
    }

    @Test("Legacy prompt configs receive new built-in page practice tasks")
    func legacyPromptConfigAddsPagePracticeTasks() {
        let legacyTasks = PromptConfig.streamlitDefault.tasks.filter { $0.id != "task10" && $0.id != "task11" }
        let legacyConfig = PromptConfig(
            version: 1,
            preamble: "",
            tasks: legacyTasks,
            epilogue: "",
            collectionPreamble: "",
            collectionEpilogue: ""
        )

        let normalized = legacyConfig.normalized()

        #expect(normalized.tasks.contains { $0.id == "task10" })
        #expect(normalized.tasks.filter { $0.id == "task10" }.count == 1)
        #expect(normalized.tasks.contains { $0.id == "task11" })
        #expect(normalized.tasks.filter { $0.id == "task11" }.count == 1)
    }

    @Test("Legacy conversation generators normalize to shared quantity placeholder")
    func legacyConversationGeneratorCountsNormalize() {
        let legacyTasks = [
            PromptTask(
                id: "task9",
                title: "Generate Practice Pack",
                template: "Create exactly {practice_topic_sentence_count} entries in the \"entries\" array."
            ),
            PromptTask(
                id: "task10",
                title: "Extract Sentences",
                template: "Aim for 10 to 30 entries. If the page has fewer useful sentences, return only the useful ones."
            ),
            PromptTask(
                id: "task11",
                title: "Create Practice from Page",
                template: "Create 100 entries in the \"entries\" array."
            )
        ]
        let legacyConfig = PromptConfig(
            version: 1,
            preamble: "",
            tasks: legacyTasks,
            epilogue: "",
            collectionPreamble: "",
            collectionEpilogue: ""
        )

        let normalized = legacyConfig.normalized()

        #expect(normalized.tasks.first { $0.id == "task9" }?.template.contains("{conversation_entry_count}") == true)
        #expect(normalized.tasks.first { $0.id == "task10" }?.template.contains("Aim for up to {conversation_entry_count} entries.") == true)
        #expect(normalized.tasks.first { $0.id == "task11" }?.template.contains("Create exactly {conversation_entry_count} entries") == true)
        #expect(normalized.tasks.first { $0.id == "task10" }?.title == "Extract Page Sentences")
        #expect(normalized.tasks.first { $0.id == "task11" }?.title == "Create Conversation")
    }

    @Test("Conversation practice generator renders selected topic details")
    func practiceGeneratorRendersTopicContext() {
        let task = PromptConfig.streamlitDefault.tasks.first { $0.id == "task9" }!
        let topic = ConversationPracticeTopic.foodEating
        let context = PromptRenderContext(
            char: "",
            definitionEN: "",
            decomposition: "",
            semantic: "",
            phonetic: "",
            phoneticPinyin: "",
            isSoundMatch: "",
            pronunciationFamily: "",
            semanticFamily: "",
            collectionName: "",
            captureCharacters: "",
            captureText: "",
            originalOCRText: "",
            recognizedOCRCharacters: "",
            unrecognizedOCRCharacters: "",
            nearbyOCRPhrases: "",
            practiceTopicID: topic.id,
            practiceTopicTitle: topic.title,
            practiceTopicSummary: topic.summary,
            practiceTopicBrief: topic.generationBrief,
            practiceTopicSituations: topic.situations.map { "- \($0)" }.joined(separator: "\n"),
            conversationEntryCount: "\(PromptConfig.defaultConversationEntryCount)"
        )

        let prompt = PromptConfig.streamlitDefault.renderPrompt(
            selectedTaskIDs: [task.id],
            context: context,
            subject: .practiceTopic(topic)
        )

        #expect(prompt.contains("Topic: Food / Eating Conversation"))
        #expect(prompt.contains("ordering food in a restaurant"))
        #expect(prompt.contains("\"theme\": \"Food / Eating Conversation\""))
        #expect(prompt.contains("\"id\": \"food_eating_001\""))
        #expect(prompt.contains("\"zh\": \"Simplified Chinese sentence.\""))
        #expect(prompt.contains("Use any context you have from this chat about the learner's goals"))
        #expect(prompt.contains("If you can browse, search, or use current knowledge"))
        #expect(prompt.contains("popular topics of the day"))
        #expect(prompt.contains("vary the concrete people, places, problems, and conversation contexts"))
        #expect(prompt.contains("Prefer concise studyable entries, but do not enforce a maximum Chinese character count."))
        #expect(!prompt.contains("Every zh value must be no more than"))
        #expect(!prompt.contains("\"pack_id\""))
        #expect(!prompt.contains("\"metadata\""))
        #expect(prompt.contains("Create exactly 25 entries"))
        #expect(!prompt.contains("{practice_topic_title}"))
        #expect(!prompt.contains("{conversation_entry_count}"))
    }

    @Test("Conversation practice generator renders selected quantity")
    func practiceGeneratorRendersSelectedQuantity() {
        let task = PromptConfig.streamlitDefault.tasks.first { $0.id == "task9" }!
        let topic = ConversationPracticeTopic.foodEating
        let context = PromptRenderContext(
            char: "",
            definitionEN: "",
            decomposition: "",
            semantic: "",
            phonetic: "",
            phoneticPinyin: "",
            isSoundMatch: "",
            pronunciationFamily: "",
            semanticFamily: "",
            collectionName: "",
            captureCharacters: "",
            captureText: "",
            originalOCRText: "",
            recognizedOCRCharacters: "",
            unrecognizedOCRCharacters: "",
            nearbyOCRPhrases: "",
            practiceTopicID: topic.id,
            practiceTopicTitle: topic.title,
            practiceTopicSummary: topic.summary,
            practiceTopicBrief: topic.generationBrief,
            practiceTopicSituations: topic.situations.map { "- \($0)" }.joined(separator: "\n"),
            conversationEntryCount: "100"
        )

        let prompt = PromptConfig.streamlitDefault.renderPrompt(
            selectedTaskIDs: [task.id],
            context: context,
            subject: .practiceTopic(topic)
        )

        #expect(prompt.contains("Create exactly 100 entries"))
    }

    @Test("Page sentence extractor renders saved page context as import JSON")
    func pageSentenceExtractorRendersSavedPageContext() {
        let task = PromptConfig.streamlitDefault.tasks.first { $0.id == "task10" }!
        let collection = CharacterCollection(
            id: UUID(),
            name: "Coffee Shop Sign",
            characters: "請先付款然後取餐".map(String.init),
            createdAt: Date(timeIntervalSince1970: 0),
            sourceType: .manual,
            isFavorite: false
        )
        let context = PromptRenderContext(
            char: "",
            definitionEN: "",
            decomposition: "",
            semantic: "",
            phonetic: "",
            phoneticPinyin: "",
            isSoundMatch: "",
            pronunciationFamily: "",
            semanticFamily: "",
            collectionName: collection.name,
            captureCharacters: collection.characters.joined(separator: " "),
            captureText: collection.characters.joined(),
            originalOCRText: "",
            recognizedOCRCharacters: "",
            unrecognizedOCRCharacters: "",
            nearbyOCRPhrases: "",
            practiceTopicID: "",
            practiceTopicTitle: "",
            practiceTopicSummary: "",
            practiceTopicBrief: "",
            practiceTopicSituations: "",
            conversationEntryCount: "\(PromptConfig.defaultConversationEntryCount)"
        )

        let prompt = PromptConfig.streamlitDefault.renderPrompt(
            selectedTaskIDs: [task.id],
            context: context,
            subject: .collection(collection)
        )

        #expect(prompt.contains("Page: Coffee Shop Sign"))
        #expect(prompt.contains("\"theme\": \"Coffee Shop Sign\""))
        #expect(prompt.contains("Set \"theme\" exactly to the Page value above: \"Coffee Shop Sign\""))
        #expect(prompt.contains("Aim for up to 25 entries"))
        #expect(prompt.contains("Prefer concise studyable entries, but do not enforce a maximum Chinese character count."))
        #expect(!prompt.contains("Every zh value must be no more than"))
        #expect(prompt.contains("請 先 付 款 然 後 取 餐"))
        #expect(prompt.contains("請先付款然後取餐"))
        #expect(prompt.contains("\"entries\""))
        #expect(!prompt.contains("{collection_name}"))
        #expect(!prompt.contains("{conversation_entry_count}"))
        #expect(!prompt.contains("Image: Coffee Shop Sign"))
    }

    @Test("Page practice generator renders saved page context as import JSON")
    func pagePracticeGeneratorRendersSavedPageContext() {
        let task = PromptConfig.streamlitDefault.tasks.first { $0.id == "task11" }!
        let collection = CharacterCollection(
            id: UUID(),
            name: "China US News",
            characters: "中美关系影响科技公司".map(String.init),
            createdAt: Date(timeIntervalSince1970: 0),
            sourceType: .manual,
            isFavorite: false
        )
        let context = PromptRenderContext(
            char: "",
            definitionEN: "",
            decomposition: "",
            semantic: "",
            phonetic: "",
            phoneticPinyin: "",
            isSoundMatch: "",
            pronunciationFamily: "",
            semanticFamily: "",
            collectionName: collection.name,
            captureCharacters: collection.characters.joined(separator: " "),
            captureText: collection.characters.joined(),
            originalOCRText: "",
            recognizedOCRCharacters: "",
            unrecognizedOCRCharacters: "",
            nearbyOCRPhrases: "",
            practiceTopicID: "",
            practiceTopicTitle: "",
            practiceTopicSummary: "",
            practiceTopicBrief: "",
            practiceTopicSituations: "",
            conversationEntryCount: "\(PromptConfig.defaultConversationEntryCount)"
        )

        let prompt = PromptConfig.streamlitDefault.renderPrompt(
            selectedTaskIDs: [task.id],
            context: context,
            subject: .collection(collection)
        )

        #expect(prompt.contains("Page: China US News"))
        #expect(prompt.contains("First infer the broad conversational theme of the page"))
        #expect(prompt.contains("Use the page as a springboard, not a cage"))
        #expect(prompt.contains("Use any context you have from this chat"))
        #expect(prompt.contains("popular topics of the day"))
        #expect(prompt.contains("\"id\": \"page_practice_001\""))
        #expect(prompt.contains("Create exactly 25 entries"))
        #expect(prompt.contains("中 美 关 系 影 响 科 技 公 司"))
        #expect(prompt.contains("中美关系影响科技公司"))
        #expect(prompt.contains("\"entries\""))
        #expect(!prompt.contains("{collection_name}"))
        #expect(!prompt.contains("{conversation_entry_count}"))
        #expect(!prompt.contains("Image: China US News"))
    }
}
