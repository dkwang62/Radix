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
        #expect(generator?.template.contains("Each entry must have exactly these keys: \"id\", \"zh\", \"pinyin\", and \"en\".") == true)
        #expect(generator?.template.contains("Prefer concise studyable entries, but do not enforce a maximum Chinese character count.") == true)
        #expect(generator?.template.contains("Every zh value must be no more than") == false)
        #expect(generator?.template.contains("\"pack_id\"") == false)
        #expect(PromptConfig.practiceTopicTaskIDs == ["task9"])
        #expect(!PromptConfig.defaultSelectedTaskIDs.contains("task9"))
    }

    @Test("Page sentence extractor is a saved-page AI task")
    func pageSentenceExtractorTaskAvailability() {
        let normalized = PromptConfig.streamlitDefault.normalized()
        let extractor = normalized.tasks.first { $0.id == "task10" }

        #expect(extractor?.title == "Extract Sentences")
        #expect(extractor?.template.contains("Conversation Practice import pack") == true)
        #expect(extractor?.template.contains("\"theme\": \"{collection_name}\"") == true)
        #expect(extractor?.template.contains("Set \"theme\" exactly to the Page value above") == true)
        #expect(extractor?.template.contains("\"id\": \"page_sentence_001\"") == true)
        #expect(extractor?.template.contains("Each entry must have exactly these keys: \"id\", \"zh\", \"pinyin\", and \"en\".") == true)
        #expect(extractor?.template.contains("Prefer concise studyable entries, but do not enforce a maximum Chinese character count.") == true)
        #expect(extractor?.template.contains("Every zh value must be no more than") == false)
        #expect(PromptConfig.collectionTaskIDs.contains("task10"))
        #expect(!PromptConfig.defaultSelectedTaskIDs.contains("task10"))
    }

    @Test("Legacy prompt configs receive new built-in page sentence extractor")
    func legacyPromptConfigAddsPageSentenceExtractor() {
        let legacyTasks = PromptConfig.streamlitDefault.tasks.filter { $0.id != "task10" }
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
            practiceTopicSentenceCount: "\(topic.targetSentenceCount)"
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
        #expect(prompt.contains("Create exactly 100 entries"))
        #expect(!prompt.contains("{practice_topic_title}"))
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
            practiceTopicSentenceCount: ""
        )

        let prompt = PromptConfig.streamlitDefault.renderPrompt(
            selectedTaskIDs: [task.id],
            context: context,
            subject: .collection(collection)
        )

        #expect(prompt.contains("Page: Coffee Shop Sign"))
        #expect(prompt.contains("\"theme\": \"Coffee Shop Sign\""))
        #expect(prompt.contains("Set \"theme\" exactly to the Page value above: \"Coffee Shop Sign\""))
        #expect(prompt.contains("Prefer concise studyable entries, but do not enforce a maximum Chinese character count."))
        #expect(!prompt.contains("Every zh value must be no more than"))
        #expect(prompt.contains("請 先 付 款 然 後 取 餐"))
        #expect(prompt.contains("請先付款然後取餐"))
        #expect(prompt.contains("\"entries\""))
        #expect(!prompt.contains("{collection_name}"))
        #expect(!prompt.contains("Image: Coffee Shop Sign"))
    }
}
