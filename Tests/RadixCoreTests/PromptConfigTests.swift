import Foundation
import Testing
@testable import RadixCore

@Test("Latest AI result preserves its reader context")
func latestAIResultRoundTrip() throws {
    let result = LatestAIResult(
        taskTitle: "Explain Sentence",
        subject: "今天天气很好。",
        body: "This sentence describes today's pleasant weather."
    )

    let decoded = try JSONDecoder().decode(
        LatestAIResult.self,
        from: JSONEncoder().encode(result)
    )

    #expect(decoded == result)
}

@Suite("AI prompt compatibility")
struct PromptConfigTests {
    @Test("OpenAI-compatible endpoint normalization accepts common FreeLLMAPI forms")
    func openAICompatibleEndpointNormalization() {
        #expect(OpenAICompatibleEndpoint(baseURLString: "localhost:3001").chatCompletionsURL?.absoluteString == "https://localhost:3001/v1/chat/completions")
        #expect(OpenAICompatibleEndpoint(baseURLString: "http://localhost:3001/v1").chatCompletionsURL?.absoluteString == "http://localhost:3001/v1/chat/completions")
        #expect(OpenAICompatibleEndpoint(baseURLString: "https://api.example.test/v1/chat/completions").chatCompletionsURL?.absoluteString == "https://api.example.test/v1/chat/completions")
    }

    @Test("Prompt test completion requires the active request and unchanged selection")
    func promptTestCompletionUsesRequestOwnership() {
        let requestID = UUID()
        let selection = PromptTestSelectionIdentity(
            taskID: "task-a",
            sourceID: "page-a",
            prompt: "Prompt A"
        )
        let request = PromptTestRequestContext(
            id: requestID,
            selection: selection,
            taskTitle: "Task A",
            sourceTitle: "Page A"
        )

        #expect(PromptTestCompletionPolicy.accepts(
            request,
            activeRequestID: requestID,
            currentSelection: selection
        ))
        #expect(!PromptTestCompletionPolicy.accepts(
            request,
            activeRequestID: UUID(),
            currentSelection: selection
        ))
        #expect(!PromptTestCompletionPolicy.accepts(
            request,
            activeRequestID: requestID,
            currentSelection: PromptTestSelectionIdentity(
                taskID: "task-b",
                sourceID: "page-a",
                prompt: "Prompt B"
            )
        ))
        #expect(!PromptTestCompletionPolicy.accepts(
            request,
            activeRequestID: requestID,
            currentSelection: PromptTestSelectionIdentity(
                taskID: "task-a",
                sourceID: "page-b",
                prompt: "Prompt A"
            )
        ))
    }

    @Test("Built-in task registry preserves persisted IDs and capabilities")
    func builtInTaskRegistryPreservesContract() {
        #expect(BuiltInPromptTaskID.allCases.map(\.rawValue) == [
            "task1", "task2", "task3", "task4", "task5",
            "task6", "task7", "task8", "task9", "task10",
            "task11", "task12", "task13", "task14", "task15"
        ])
        #expect(BuiltInPromptTaskID.activeCases.contains(.retiredLegacyTask) == false)
        #expect(BuiltInPromptTaskID.extractPhrases.subjectType == .page)
        #expect(BuiltInPromptTaskID.improveSentence.subjectType == .sentence)
        #expect(BuiltInPromptTaskID.structurePhraseInput.subjectType == .freeText)
        #expect(BuiltInPromptTaskID.improveSentence.supportsResultImport)
        #expect(BuiltInPromptTaskID.createQuiz.supportsResultImport == false)
        #expect(PromptConfig.collectionTaskIDs == BuiltInPromptTaskID.rawValues { $0.subjectType == .page })
        #expect(PromptConfig.conversationEntryCountTaskIDs == BuiltInPromptTaskID.rawValues(where: \.usesConversationEntryCount))
        #expect(PromptConfig.defaultSubjectType(forTaskID: "custom-task") == .characterPhrase)
    }

    @Test("AI image OCR parser accepts marked and fenced text")
    func aiImageOCRParserAcceptsCommonResponses() {
        let marked = """
        [[OCR TEXT]]
        短笺裙裙试跑道黑想意新楼矮蓝眼路零慢赚颜

        [[NOTES]]
        ignored
        """
        let fenced = """
        ```text
        一二七九了几人人人九九十又万三十个么
        ```
        """

        #expect(AIImageOCRTextParser.parse(marked) == "短笺裙裙试跑道黑想意新楼矮蓝眼路零慢赚颜")
        #expect(AIImageOCRTextParser.parse(fenced) == "一二七九了几人人人九九十又万三十个么")
    }

    @Test("Custom prompt tasks preserve configurable subject type")
    func customPromptSubjectTypeCompatibility() throws {
        let legacyJSON = """
        {
          "id": "custom1",
          "title": "Custom",
          "template": "Explain {char}"
        }
        """.data(using: .utf8)!
        let legacyTask = try JSONDecoder().decode(PromptTask.self, from: legacyJSON)
        #expect(legacyTask.subjectType == .characterPhrase)

        let sentenceTask = PromptTask(
            id: "custom_sentence",
            title: "Sentence Note",
            template: "Sentence: {sentence_zh}\\nEnglish: {sentence_en}\\nPhrases: {sentence_phrases}",
            subjectType: .sentence
        )
        let config = PromptConfig(
            version: 1,
            preamble: "",
            tasks: [sentenceTask],
            epilogue: "",
            collectionPreamble: "",
            collectionEpilogue: ""
        )
        let record = SentenceExampleRecord(
            chinese: "我想练习中文。",
            pinyin: "Wǒ xiǎng liànxí Zhōngwén.",
            english: "I want to practice Chinese.",
            targetCharacters: ["我", "想", "练", "习", "中", "文"],
            targetPhrases: ["练习", "中文"]
        )
        let item = ConversationPracticeItem(sentenceExample: record, rank: 0)

        let prompt = config.renderPrompt(
            selectedTaskIDs: [sentenceTask.id],
            context: PromptRenderContext(
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
                practiceTopicID: "",
                practiceTopicTitle: "",
                practiceTopicSummary: "",
                practiceTopicBrief: "",
                practiceTopicSituations: "",
                sentenceChinese: item.simplified,
                sentencePinyin: item.pinyin,
                sentenceEnglish: item.english,
                sentencePhrases: item.phraseHints.joined(separator: ", "),
                sentenceCharacters: item.characterHints.joined(separator: " "),
                conversationEntryCount: "25",
                sentenceExtractionDetail: ""
            ),
            subject: .sentence(item)
        )

        #expect(prompt.contains("Sentence: 我想练习中文。"))
        #expect(prompt.contains("English: I want to practice Chinese."))
        #expect(prompt.contains("Phrases: 练习, 中文"))
    }

    @Test("Sentence AI template is built in but not a default character task")
    func sentenceTemplateAvailability() {
        let normalized = PromptConfig.streamlitDefault.normalized()
        let task = normalized.tasks.first { $0.id == PromptConfig.defaultSentenceTaskID }

        #expect(task?.title == "Sentence")
        #expect(task?.subjectType == .sentence)
        #expect(task?.template.contains("{sentence_zh}") == true)
        #expect(task?.template.contains("{sentence_en}") == true)
        #expect(!PromptConfig.defaultSelectedTaskIDs.contains(PromptConfig.defaultSentenceTaskID))
    }

    @Test("Sentence improvement template is a sentence task")
    func sentenceImprovementTemplateAvailability() {
        let normalized = PromptConfig.streamlitDefault.normalized()
        let task = normalized.tasks.first { $0.id == PromptConfig.sentenceImprovementTaskID }

        #expect(task?.title == "Sentence Improvement")
        #expect(task?.subjectType == .sentence)
        #expect(task?.template.contains("messy input string") == true)
        #expect(task?.template.contains("Return JSON only") == true)
        #expect(task?.template.contains("\"sentence\"") == true)
        #expect(task?.template.contains("\"pinyin\"") == true)
        #expect(task?.template.contains("\"english\"") == true)
        #expect(task?.template.contains("The three fields must match each other exactly") == true)
        #expect(!PromptConfig.defaultSelectedTaskIDs.contains(PromptConfig.sentenceImprovementTaskID))
    }

    @Test("Format vocabulary template is a free text phrase import task")
    func vocabularyFormatterTemplateAvailability() {
        let normalized = PromptConfig.streamlitDefault.normalized()
        let task = normalized.tasks.first { $0.id == PromptConfig.vocabularyFormatterTaskID }

        #expect(task?.title == "Structure Phrase for Input")
        #expect(task?.subjectType == .freeText)
        #expect(task?.template.contains("{free_text_input}") == true)
        #expect(task?.template.contains("Chinese Phrase | Pinyin | Concise English meaning") == true)
        #expect(!PromptConfig.defaultSelectedTaskIDs.contains(PromptConfig.vocabularyFormatterTaskID))
    }

    @Test("Format vocabulary prompt renders pasted source text")
    func vocabularyFormatterRendersFreeTextInput() {
        let task = PromptTask(
            id: PromptConfig.vocabularyFormatterTaskID,
            title: "Structure Phrase for Input",
            template: "Format:\n{free_text_input}",
            subjectType: .freeText
        )
        let config = PromptConfig(
            version: 1,
            preamble: "ignored",
            tasks: [task],
            epilogue: "ignored",
            collectionPreamble: "ignored",
            collectionEpilogue: "ignored"
        )
        let prompt = config.renderPrompt(
            selectedTaskIDs: [PromptConfig.vocabularyFormatterTaskID],
            context: PromptRenderContext(
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
                practiceTopicID: "",
                practiceTopicTitle: "",
                practiceTopicSummary: "",
                practiceTopicBrief: "",
                practiceTopicSituations: "",
                conversationEntryCount: "25",
                sentenceExtractionDetail: "",
                freeTextInput: "咖啡 coffee\n学习 study"
            ),
            subject: .freeText("咖啡 coffee\n学习 study")
        )

        #expect(prompt.contains("Vocabulary list / source text:\n咖啡 coffee\n学习 study"))
        #expect(!prompt.contains("{free_text_input}"))
    }

    @Test("Explain page template includes translation and character analysis")
    func explainPageTemplateIncludesTranslationAndCharacterAnalysis() {
        let normalized = PromptConfig.streamlitDefault.normalized()
        let task = normalized.tasks.first { $0.id == "task5" }

        #expect(task?.title == "Explain Page")
        #expect(task?.subjectType == .page)
        #expect(task?.template.contains("Bilingual Page Translation & Character Analysis") == true)
        #expect(task?.template.contains("## Translation") == true)
        #expect(task?.template.contains("## Meaning & Character Analysis") == true)
        #expect(task?.template.contains("## Learner Notes") == true)
        #expect(task?.template.contains("## Tone & Context") == true)
        #expect(task?.template.contains("Analyze the provided text and character set") == true)
        #expect(task?.template.contains("Linguistic Deconstruction") == false)
        #expect(task?.template.contains("Thematic Analysis") == false)
    }

    @Test("Legacy heavy translate templates normalize to concise report")
    func legacyHeavyTranslateTemplateNormalizes() {
        let legacy = PromptTask(
            id: "task5",
            title: "Task 5 – Universal Content Architect",
            template: """
            Translate

            Master Prompt: The Bilingual Editor's Analytical Report

            Section 1: ## Linguistic Deconstruction (Shorthand Analysis).
            Section 2: ## Thematic Analysis (Grouped by Subject Matter).
            """,
            subjectType: .page
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
        let task = normalized.tasks.first { $0.id == "task5" }

        #expect(task?.title == "Explain Page")
        #expect(task?.template.contains("Bilingual Page Translation & Character Analysis") == true)
        #expect(task?.template.contains("Linguistic Deconstruction") == false)
        #expect(task?.template.contains("Thematic Analysis") == false)
    }

    @Test("Prompt template revision prompt preserves placeholders")
    func promptTemplateRevisionPromptPreservesPlaceholders() {
        let prompt = PromptTemplateRevision.revisionPrompt(
            taskTitle: "Explain Page",
            subjectType: .page,
            currentTemplate: "Translate {collection_name}\\n{capture_text}\\n{capture_chars}",
            changeRequest: "Make it shorter."
        )

        #expect(prompt.contains("Revise this Radix AI prompt template."))
        #expect(prompt.contains("Make it shorter."))
        #expect(prompt.contains("{collection_name}"))
        #expect(prompt.contains("{capture_text}"))
        #expect(prompt.contains("{capture_chars}"))
        #expect(prompt.contains("Preserve Radix placeholders exactly"))
        #expect(prompt.contains("Return only the revised prompt template."))
    }

    @Test("Prompt template revision extracts fenced template")
    func promptTemplateRevisionExtractsFencedTemplate() {
        let response = """
        Here is the revised template:

        ```text
        Translate

        Use {capture_text}.
        ```
        """

        let revised = PromptTemplateRevision.revisedTemplate(from: response)

        #expect(revised == "Translate\n\nUse {capture_text}.")
    }

    @Test("Prompt template revision extracts labeled template")
    func promptTemplateRevisionExtractsLabeledTemplate() {
        let response = """
        Revised template:
        Sentence

        Explain {sentence_zh}.
        """

        let revised = PromptTemplateRevision.revisedTemplate(from: response)

        #expect(revised == "Sentence\n\nExplain {sentence_zh}.")
    }

    @Test("Legacy sentence improvement templates normalize to synced JSON payload")
    func legacySentenceImprovementTemplateNormalizesToSyncedPayload() {
        let legacy = PromptTask(
            id: PromptConfig.sentenceImprovementTaskID,
            title: "Sentence Improvement",
            template: """
            Sentence Improvement

            Rewrite this messy input string.
            Return only the improved sentence. Do not include pinyin or English.
            """,
            subjectType: .sentence
        )
        let config = PromptConfig(
            version: 1,
            preamble: "",
            tasks: [legacy],
            epilogue: "",
            collectionPreamble: "",
            collectionEpilogue: ""
        )

        let task = config.normalized().tasks.first { $0.id == PromptConfig.sentenceImprovementTaskID }

        #expect(task?.template.contains("Return JSON only") == true)
        #expect(task?.template.contains("\"sentence\"") == true)
        #expect(task?.template.contains("\"pinyin\"") == true)
        #expect(task?.template.contains("\"english\"") == true)
        #expect(task?.template.contains("The three fields must match each other exactly") == true)
    }

    @Test("Legacy prompt configs receive the built-in sentence template")
    func legacyPromptConfigAddsSentenceTemplate() {
        let legacyTasks = PromptConfig.streamlitDefault.tasks.filter {
            $0.id != PromptConfig.defaultSentenceTaskID &&
                $0.id != PromptConfig.sentenceImprovementTaskID &&
                $0.id != PromptConfig.vocabularyFormatterTaskID
        }
        let legacyConfig = PromptConfig(
            version: 1,
            preamble: "",
            tasks: legacyTasks,
            epilogue: "",
            collectionPreamble: "",
            collectionEpilogue: ""
        )

        let normalized = legacyConfig.normalized()
        let sentenceTask = normalized.tasks.first { $0.id == PromptConfig.defaultSentenceTaskID }

        #expect(sentenceTask?.title == "Sentence")
        #expect(sentenceTask?.subjectType == .sentence)

        let improvementTask = normalized.tasks.first { $0.id == PromptConfig.sentenceImprovementTaskID }
        #expect(improvementTask?.title == "Sentence Improvement")
        #expect(improvementTask?.subjectType == .sentence)

        let vocabularyTask = normalized.tasks.first { $0.id == PromptConfig.vocabularyFormatterTaskID }
        #expect(vocabularyTask?.title == "Structure Phrase for Input")
        #expect(vocabularyTask?.subjectType == .freeText)
    }

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

    @Test("Extract phrases template rejects noisy groupings and labels names")
    func extractPhrasesTemplateRequiresDictionaryQualityBoundaries() {
        let task = PromptConfig.streamlitDefault.tasks.first { $0.id == "task4" }
        let template = task?.template ?? ""

        #expect(template.contains("Boundary Quality"))
        #expect(template.contains("never output \"进青瓦屋\""))
        #expect(template.contains("Proper Names"))
        #expect(template.contains("Dictionary-quality Meanings"))
        #expect(template.contains("Fewer high-quality phrases are better than many noisy groupings."))
    }

    @Test("Legacy extract phrases templates normalize to stricter quality rules")
    func legacyExtractPhrasesTemplateNormalizesToQualityRules() {
        let legacy = PromptTask(
            id: "task4",
            title: "Extract Phrases",
            template: """
            Extract Phrases

            [CRITICAL RULES]
            Phrase | Pinyin | Concise English meaning
            """,
            subjectType: .page
        )
        let config = PromptConfig(
            version: 1,
            preamble: "",
            tasks: [legacy],
            epilogue: "",
            collectionPreamble: "",
            collectionEpilogue: ""
        )

        let template = config.normalized().tasks.first { $0.id == "task4" }?.template ?? ""

        #expect(template.contains("Boundary Quality"))
        #expect(template.contains("Dictionary-quality Meanings"))
        #expect(template.contains("never output \"进青瓦屋\""))
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

    @Test("Sentence practice generator is a saved-page AI task")
    func pageSentenceExtractorTaskAvailability() {
        let normalized = PromptConfig.streamlitDefault.normalized()
        let extractor = normalized.tasks.first { $0.id == "task10" }

        #expect(extractor?.title == "Sentence Practice")
        #expect(extractor?.template.contains("Conversation Practice import pack") == true)
        #expect(extractor?.template.contains("{sentence_extraction_detail}") == true)
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

    @Test("Extract sentences generator is a saved-page AI task")
    func aiCleanedPageTaskAvailability() {
        let normalized = PromptConfig.streamlitDefault.normalized()
        let generator = normalized.tasks.first { $0.id == "task12" }

        #expect(generator?.title == "Extract Sentences")
        #expect(generator?.template.contains("Original OCR/source context") == true)
        #expect(generator?.template.contains("cleaned_chinese_text") == true)
        #expect(generator?.template.contains("\"id\": \"ai_page_sentence_001\"") == true)
        #expect(generator?.template.contains("\"pinyin\"") == true)
        #expect(generator?.template.contains("\"phrase_hints\"") == true)
        #expect(generator?.template.contains("Expand telegraphic media shorthand") == true)
        #expect(generator?.template.contains("abbreviations, compressed journalistic compounds") == true)
        #expect(generator?.template.contains("Replace concise headline-style compounds with normal phrases or clauses") == true)
        #expect(generator?.template.contains("do not keep telegraphic headline style") == true)
        #expect(generator?.template.contains("Do not invent unrelated facts") == true)
        #expect(generator?.template.contains("process the entire meaningful source page") == true)
        #expect(generator?.template.contains("Do not summarize, sample, choose representative sentences") == true)
        #expect(generator?.template.contains("filtering out noise and nonsensical fragments") == true)
        #expect(generator?.template.contains("distinct, fully formed, grammatically correct sentences") == true)
        #expect(generator?.template.contains("Pass 2 - Improve every extracted candidate") == true)
        #expect(generator?.template.contains("Do not output rough extracted text") == true)
        #expect(generator?.template.contains("silently run the Sentence Improvement task") == true)
        #expect(generator?.template.contains("same quality bar as Sentence Improvement") == true)
        #expect(generator?.template.contains("Generate pinyin from the final improved \"chinese\" sentence") == true)
        #expect(generator?.template.contains("Generate english as the natural English meaning") == true)
        #expect(generator?.template.contains("The three fields must match each other exactly") == true)
        #expect(generator?.template.contains("unrepairable fragments") == true)
        #expect(generator?.template.contains("sentences array must be a list") == true)
        #expect(generator?.template.contains("every sentence is distinct and fully formed") == true)
        #expect(generator?.template.contains("covers the entire cleaned_chinese_text rather than a representative subset") == true)
        #expect(generator?.template.contains("Return JSON only") == true)
        #expect(PromptConfig.collectionTaskIDs.contains("task12"))
        #expect(!PromptConfig.conversationEntryCountTaskIDs.contains("task12"))
        #expect(!PromptConfig.defaultSelectedTaskIDs.contains("task12"))
    }

    @Test("Page quiz prompt stays in AI chat with cross-model quiz protocol")
    func pageQuizPromptUsesCrossModelQuizProtocol() {
        let normalized = PromptConfig.streamlitDefault.normalized()
        let quiz = normalized.tasks.first { $0.id == "task8" }

        #expect(quiz?.title == "Create Quiz")
        #expect(quiz?.template.contains("bilingual Chinese dictionary editor, teacher, and quizmaster") == true)
        #expect(quiz?.template.contains("The human user is the learner.") == true)
        #expect(quiz?.template.contains("Simplified Chinese unless the learner asks for Traditional") == true)
        #expect(quiz?.template.contains("Difficulty: HSK 4 unless the learner asks for another HSK level") == true)
        #expect(quiz?.template.contains("Answer choices: Chinese only, no English, no pinyin, no definitions, no hints") == true)
        #expect(quiz?.template.contains("English translations will not reveal the answer") == true)
        #expect(quiz?.template.contains("Required question format") == true)
        #expect(quiz?.template.contains("Question X - [Question Type] (HSK N)") == true)
        #expect(quiz?.template.contains("请回答 A、B、C 或 D。") == true)
        #expect(quiz?.template.contains("After displaying Question 1, stop immediately") == true)
        #expect(quiz?.template.contains("Do not answer your own question") == true)
        #expect(quiz?.template.contains("Do not reveal the correct answer, pinyin, analysis, explanation, or Question 2 until the learner replies") == true)
        #expect(quiz?.template.contains("Never include English, pinyin, definitions, or hints inside answer choices") == true)
        #expect(quiz?.template.contains("Before every question, silently verify") == true)
        #expect(PromptConfig.collectionTaskIDs.contains("task8"))
        #expect(!PromptConfig.defaultSelectedTaskIDs.contains("task8"))
    }

    @Test("Legacy page quiz prompts normalize to HSK theme quiz")
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

        #expect(template.contains("English translations will not reveal the answer"))
        #expect(template.contains("Question X - [Question Type] (HSK N)"))
        #expect(template.contains("Answer choices: Chinese only"))
        #expect(template.contains("The human user is the learner"))
    }

    @Test("Recent HSK page quiz prompts normalize to cross-model chat quiz")
    func recentHSKPageQuizPromptNormalizesCrossModelProtocol() {
        let recent = PromptTask(
            id: "task8",
            title: "Create Quiz",
            template: """
            Create Quiz

            You are a patient, bilingual Chinese language teacher creating a language-learning practice quiz.

            Core Rules:
            1. Source Material: Draw from the vocabulary and themes present in the user's learning context, including antonyms, synonyms, and idioms related to the material. Do not feel limited to the specific characters on any single page; use your knowledge to provide varied, challenging, and HSK-appropriate content.
            2. Bilingual Requirement: Provide all questions and answer options in Chinese with an English translation. Include bilingual explanations after assessing the learner's answer.
            3. Pinyin Usage: Do not include pinyin in the multiple-choice options. Always include pinyin in the English assessment/explanation section, for example: word (pinyin).
            4. Strict Constraint: The character(s) representing any of the answer choices must not appear in the question text. If a concept is hard to describe without using the target character, use the English word equivalent embedded in the Chinese question.

            Variety of Assessment Styles:
            - Contextual Fill-in-the-Blank: Test grammatical usage in a sentence.

            Start Sequence:
            1. State: "I will quiz you using HSK [Level 1-6] standards."
            2. Ask Question 1 only.
            """
        )
        let config = PromptConfig(
            version: 1,
            preamble: "",
            tasks: [recent],
            epilogue: "",
            collectionPreamble: "",
            collectionEpilogue: ""
        )

        let template = config.normalized().tasks.first { $0.id == "task8" }?.template ?? ""

        #expect(template.contains("The human user is the learner"))
        #expect(template.contains("English translations will not reveal the answer"))
        #expect(template.contains("Do not answer your own question"))
        #expect(template.contains("After displaying Question 1, stop immediately"))
        #expect(template.contains("Answer choices: Chinese only"))
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
        let legacyTasks = PromptConfig.streamlitDefault.tasks.filter { $0.id != "task10" && $0.id != "task11" && $0.id != "task12" }
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
        #expect(normalized.tasks.contains { $0.id == "task12" })
        #expect(normalized.tasks.filter { $0.id == "task12" }.count == 1)
    }

    @Test("Legacy extract sentence templates normalize to noise-filtering rules")
    func legacyExtractSentencesTemplateNormalizesToNoiseFilteringRules() {
        let legacy = PromptTask(
            id: "task12",
            title: "Extract Sentences",
            template: """
            Extract Sentences

            Return JSON only.
            cleaned_chinese_text
            "pinyin"
            """,
            subjectType: .page
        )
        let config = PromptConfig(
            version: 1,
            preamble: "",
            tasks: [legacy],
            epilogue: "",
            collectionPreamble: "",
            collectionEpilogue: ""
        )

        let template = config.normalized().tasks.first { $0.id == "task12" }?.template ?? ""

        #expect(template.contains("filtering out noise and nonsensical fragments"))
        #expect(template.contains("distinct, fully formed, grammatically correct sentences"))
        #expect(template.contains("Pass 2 - Improve every extracted candidate"))
        #expect(template.contains("Do not output rough extracted text"))
        #expect(template.contains("same quality bar as Sentence Improvement"))
        #expect(template.contains("The three fields must match each other exactly"))
        #expect(template.contains("every sentence is distinct and fully formed"))
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
        #expect(normalized.tasks.first { $0.id == "task10" }?.title == "Sentence Practice")
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
            conversationEntryCount: "\(PromptConfig.defaultConversationEntryCount)",
            sentenceExtractionDetail: SentenceExtractionDetail.brief.promptInstruction
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
            conversationEntryCount: "100",
            sentenceExtractionDetail: SentenceExtractionDetail.brief.promptInstruction
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
            conversationEntryCount: "\(PromptConfig.defaultConversationEntryCount)",
            sentenceExtractionDetail: SentenceExtractionDetail.detailed.promptInstruction
        )

        let prompt = PromptConfig.streamlitDefault.renderPrompt(
            selectedTaskIDs: [task.id],
            context: context,
            subject: .collection(collection)
        )

        #expect(prompt.contains("Page: Coffee Shop Sign"))
        #expect(prompt.contains("\"theme\": \"Coffee Shop Sign\""))
        #expect(prompt.contains("Set \"theme\" exactly to the Page value above: \"Coffee Shop Sign\""))
        #expect(prompt.contains("Detail level:"))
        #expect(prompt.contains("Detailed mode: create richer study-ready sentence records."))
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
            conversationEntryCount: "\(PromptConfig.defaultConversationEntryCount)",
            sentenceExtractionDetail: SentenceExtractionDetail.brief.promptInstruction
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
