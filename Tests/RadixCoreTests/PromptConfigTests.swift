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
        #expect(PromptConfig.practiceTopicTaskIDs == ["task9"])
        #expect(!PromptConfig.defaultSelectedTaskIDs.contains("task9"))
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
        #expect(prompt.contains("\"pack_id\": \"food_eating\""))
        #expect(prompt.contains("Create exactly 100 entries"))
        #expect(!prompt.contains("{practice_topic_title}"))
    }
}
