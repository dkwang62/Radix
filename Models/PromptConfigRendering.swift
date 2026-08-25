extension PromptConfig {
    func normalized() -> PromptConfig {
        var seen = Set<String>()
        let cleaned = tasks.filter {
            guard $0.id != BuiltInPromptTaskID.retiredLegacyTask.rawValue else { return false }
            guard !$0.id.isEmpty, !seen.contains($0.id) else { return false }
            seen.insert($0.id)
            return true
        }.map { task in
            let builtInID = BuiltInPromptTaskID(rawValue: task.id)
            guard builtInID?.repairsLegacyTemplate == true,
                  let defaultTask = PromptConfig.streamlitDefault.tasks.first(where: { $0.id == task.id }) else {
                return task
            }

            let normalizedTitle: String
            if builtInID == .extractPhrases,
               task.title == "Task 4 – Isolate Phrases from Apple Vision" ||
                task.title == "Task 4 – Extract Phrases from Image" ||
                task.title == "Task 4 – Extract Phrases from Page (image)" {
                normalizedTitle = defaultTask.title
            } else if builtInID == .explainPage,
                      task.title == "Task 5 – Universal Content Architect" ||
                        task.title == "Translate" ||
                        task.title == "Translate Page" {
                normalizedTitle = defaultTask.title
            } else if builtInID == .sentencePractice,
                      task.title == "Extract Sentences" ||
                        task.title == "Extract Page Sentences" ||
                        task.title == "Create Sentences" {
                normalizedTitle = defaultTask.title
            } else if builtInID == .createConversation,
                      task.title == "Create Practice from Page" ||
                      task.title == "Create Theme Practice" {
                normalizedTitle = defaultTask.title
            } else if builtInID == .extractSentences,
                      task.title == "Create AI-Cleaned Page" ||
                        task.title == "Create AI Page" {
                normalizedTitle = defaultTask.title
            } else if builtInID == .improveSentence,
                      task.title == "Improve Sentence" ||
                        task.title == "Sentence Improvement" {
                normalizedTitle = defaultTask.title
            } else if builtInID == .structurePhraseInput,
                      task.title == "Format Vocabulary" {
                normalizedTitle = defaultTask.title
            } else {
                normalizedTitle = task.title
            }

            let normalizedTemplate: String
            if task.template.contains("{capture_chars}") || task.template.contains("{capture_text}") || task.template.contains("{collection_name}") ||
                task.template.contains("Task 4 – Extract Phrases from Image") ||
                task.template.contains("Task 4 – Extract Phrases from Page (image)") ||
                (builtInID == .extractPhrases && !task.template.contains("[CRITICAL RULES]")) ||
                (builtInID == .extractPhrases && !task.template.contains("Dictionary-quality Meanings")) ||
                task.template.contains("Task 5 – Universal Content Architect") ||
                (builtInID == .explainPage && !task.template.contains("Bilingual Page Translation & Character Analysis")) ||
                (builtInID == .checkOCR && (
                    task.template.contains("ORIGINAL OCR:") ||
                    task.template.contains("attached source image and dictionary evidence") ||
                    !task.template.contains("SAVED PAGE CHARACTERS:")
                )) ||
                (builtInID == .createQuiz && !task.template.contains("English translations will not reveal the answer")) ||
                (builtInID == .generatePracticePack && !task.template.contains("{practice_topic_title}")) ||
                (builtInID == .sentencePractice && !task.template.contains("{sentence_extraction_detail}")) ||
                (builtInID == .extractSentences && (
                    !task.template.contains("cleaned_chinese_text") ||
                    !task.template.contains("\"pinyin\"") ||
                    !task.template.contains("distinct, fully formed, grammatically correct sentences") ||
                    !task.template.contains("same quality bar as Sentence Improvement") ||
                    !task.template.contains("Pass 2 - Improve every extracted candidate") ||
                    !task.template.contains("Do not output rough extracted text") ||
                    !task.template.contains("The three fields must match each other exactly")
                )) ||
                (builtInID == .improveSentence && (
                    !task.template.contains("Return JSON only") ||
                    !task.template.contains("\"sentence\"") ||
                    !task.template.contains("\"pinyin\"") ||
                    !task.template.contains("\"english\"") ||
                    !task.template.contains("The three fields must match each other exactly")
                )) ||
                (builtInID == .structurePhraseInput && (
                    !task.template.contains("{free_text_input}") ||
                    !task.template.contains("Chinese Phrase | Pinyin | Concise English meaning")
                )) {
                normalizedTemplate = defaultTask.template
            } else if task.template.contains("Task 4 – Isolate Phrases from Apple Vision") {
                normalizedTemplate = task.template.replacingOccurrences(
                    of: "Task 4 – Isolate Phrases from Apple Vision",
                    with: defaultTask.title
                )
            } else if builtInID == .generatePracticePack, task.template.contains("{practice_topic_sentence_count}") {
                normalizedTemplate = task.template.replacingOccurrences(
                    of: "{practice_topic_sentence_count}",
                    with: "{conversation_entry_count}"
                )
            } else if builtInID == .sentencePractice, task.template.contains("Aim for 10 to 30 entries.") {
                normalizedTemplate = task.template.replacingOccurrences(
                    of: "Aim for 10 to 30 entries.",
                    with: "Aim for up to {conversation_entry_count} entries."
                )
            } else if builtInID == .createConversation, task.template.contains("Create 100 entries in the \"entries\" array.") {
                normalizedTemplate = task.template.replacingOccurrences(
                    of: "Create 100 entries in the \"entries\" array.",
                    with: "Create exactly {conversation_entry_count} entries in the \"entries\" array."
                )
            } else {
                normalizedTemplate = task.template
            }

            return PromptTask(
                id: task.id,
                title: normalizedTitle,
                template: normalizedTemplate,
                subjectType: PromptConfig.defaultSubjectType(forTaskID: task.id)
            )
        }
        if cleaned.isEmpty {
            return .streamlitDefault
        }
        let defaultsByID = Dictionary(uniqueKeysWithValues: PromptConfig.streamlitDefault.tasks.map { ($0.id, $0) })
        let missingDefaults = PromptConfig.streamlitDefault.tasks.filter { defaultTask in
            !seen.contains(defaultTask.id) &&
                (defaultTask.subjectType == .page ||
                    defaultTask.subjectType == .practiceTopic ||
                    defaultTask.subjectType == .sentence ||
                    defaultTask.subjectType == .freeText) &&
                defaultsByID[defaultTask.id] != nil
        }
        return PromptConfig(
            version: version,
            preamble: preamble,
            tasks: cleaned + missingDefaults,
            epilogue: epilogue,
            collectionPreamble: pageTerminology(collectionPreamble),
            collectionEpilogue: pageTerminology(collectionEpilogue)
        )
    }

    private func pageTerminology(_ text: String) -> String {
        text
            .replacingOccurrences(of: "Collections", with: "Images")
            .replacingOccurrences(of: "Collection", with: "Image")
            .replacingOccurrences(of: "collections", with: "images")
            .replacingOccurrences(of: "collection", with: "image")
    }

    func renderPrompt(selectedTaskIDs: [String], context: PromptRenderContext, subject: ActiveSubject) -> String {
        let cfg = normalized()
        let selected = Set(selectedTaskIDs)
        let body = cfg.tasks
            .filter { selected.contains($0.id) }
            .map(\.template)
            .joined()
        let full: String
        switch subject {
        case .character, .sentence:
            full = cfg.preamble + body + cfg.epilogue
        case .collection:
            if selected.count == 1,
               let selectedID = selected.first.flatMap(BuiltInPromptTaskID.init(rawValue:)),
               selectedID.usesStandalonePagePrompt {
                full = cfg.collectionPreamble + body
            } else {
                full = cfg.collectionPreamble + body + cfg.collectionEpilogue
            }
        case .practiceTopic:
            full = body
        case .freeText:
            full = body
        }
        return full
            .replacingOccurrences(of: "{char}", with: context.char)
            .replacingOccurrences(of: "{def_en}", with: context.definitionEN)
            .replacingOccurrences(of: "{decomposition}", with: context.decomposition)
            .replacingOccurrences(of: "{semantic}", with: context.semantic)
            .replacingOccurrences(of: "{phonetic}", with: context.phonetic)
            .replacingOccurrences(of: "{phonetic_pinyin}", with: context.phoneticPinyin)
            .replacingOccurrences(of: "{is_sound_match}", with: context.isSoundMatch)
            .replacingOccurrences(of: "{pronunciation_family}", with: context.pronunciationFamily)
            .replacingOccurrences(of: "{semantic_family}", with: context.semanticFamily)
            .replacingOccurrences(of: "{collection_name}", with: context.collectionName)
            .replacingOccurrences(of: "{capture_chars}", with: context.captureCharacters)
            .replacingOccurrences(of: "{capture_text}", with: context.captureText)
            .replacingOccurrences(of: "{ocr_original}", with: context.originalOCRText)
            .replacingOccurrences(of: "{ocr_recognized}", with: context.recognizedOCRCharacters)
            .replacingOccurrences(of: "{ocr_unrecognized}", with: context.unrecognizedOCRCharacters)
            .replacingOccurrences(of: "{ocr_nearby_phrases}", with: context.nearbyOCRPhrases)
            .replacingOccurrences(of: "{practice_topic_id}", with: context.practiceTopicID)
            .replacingOccurrences(of: "{practice_topic_title}", with: context.practiceTopicTitle)
            .replacingOccurrences(of: "{practice_topic_summary}", with: context.practiceTopicSummary)
            .replacingOccurrences(of: "{practice_topic_brief}", with: context.practiceTopicBrief)
            .replacingOccurrences(of: "{practice_topic_situations}", with: context.practiceTopicSituations)
            .replacingOccurrences(of: "{sentence_zh}", with: context.sentenceChinese)
            .replacingOccurrences(of: "{sentence_chinese}", with: context.sentenceChinese)
            .replacingOccurrences(of: "{sentence_pinyin}", with: context.sentencePinyin)
            .replacingOccurrences(of: "{sentence_en}", with: context.sentenceEnglish)
            .replacingOccurrences(of: "{sentence_english}", with: context.sentenceEnglish)
            .replacingOccurrences(of: "{sentence_phrases}", with: context.sentencePhrases)
            .replacingOccurrences(of: "{sentence_characters}", with: context.sentenceCharacters)
            .replacingOccurrences(of: "{free_text_input}", with: context.freeTextInput)
            .replacingOccurrences(of: "{practice_topic_sentence_count}", with: context.conversationEntryCount)
            .replacingOccurrences(of: "{conversation_entry_count}", with: context.conversationEntryCount)
            .replacingOccurrences(of: "{sentence_extraction_detail}", with: context.sentenceExtractionDetail)
    }
}
