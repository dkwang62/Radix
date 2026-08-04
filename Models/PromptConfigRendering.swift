extension PromptConfig {
    func normalized() -> PromptConfig {
        var seen = Set<String>()
        let cleaned = tasks.filter {
            guard $0.id != "task6" else { return false }
            guard !$0.id.isEmpty, !seen.contains($0.id) else { return false }
            seen.insert($0.id)
            return true
        }.map { task in
            guard (PromptConfig.collectionTaskIDs.contains(task.id) ||
                   PromptConfig.practiceTopicTaskIDs.contains(task.id) ||
                   task.id == PromptConfig.sentenceImprovementTaskID),
                  let defaultTask = PromptConfig.streamlitDefault.tasks.first(where: { $0.id == task.id }) else {
                return task
            }

            let normalizedTitle: String
            if task.id == "task4",
               task.title == "Task 4 – Isolate Phrases from Apple Vision" ||
                task.title == "Task 4 – Extract Phrases from Image" ||
                task.title == "Task 4 – Extract Phrases from Page (image)" {
                normalizedTitle = defaultTask.title
            } else if task.id == "task5",
                      task.title == "Task 5 – Universal Content Architect" {
                normalizedTitle = defaultTask.title
            } else if task.id == "task10",
                      task.title == "Extract Sentences" ||
                        task.title == "Extract Page Sentences" ||
                        task.title == "Create Sentences" {
                normalizedTitle = defaultTask.title
            } else if task.id == "task11",
                      task.title == "Create Practice from Page" ||
                      task.title == "Create Theme Practice" {
                normalizedTitle = defaultTask.title
            } else if task.id == "task12",
                      task.title == "Create AI-Cleaned Page" ||
                        task.title == "Create AI Page" {
                normalizedTitle = defaultTask.title
            } else if task.id == PromptConfig.sentenceImprovementTaskID,
                      task.title == "Improve Sentence" ||
                        task.title == "Sentence Improvement" {
                normalizedTitle = defaultTask.title
            } else {
                normalizedTitle = task.title
            }

            let normalizedTemplate: String
            if task.template.contains("{capture_chars}") || task.template.contains("{capture_text}") || task.template.contains("{collection_name}") ||
                task.template.contains("Task 4 – Extract Phrases from Image") ||
                task.template.contains("Task 4 – Extract Phrases from Page (image)") ||
                (task.id == "task4" && !task.template.contains("[CRITICAL RULES]")) ||
                (task.id == "task4" && !task.template.contains("Dictionary-quality Meanings")) ||
                task.template.contains("Task 5 – Universal Content Architect") ||
                (task.id == "task5" && !task.template.contains("Concise Bilingual Page Translation")) ||
                (task.id == "task7" && (
                    task.template.contains("ORIGINAL OCR:") ||
                    task.template.contains("attached source image and dictionary evidence") ||
                    !task.template.contains("SAVED PAGE CHARACTERS:")
                )) ||
                (task.id == "task8" && !task.template.contains("English translations will not reveal the answer")) ||
                (task.id == "task9" && !task.template.contains("{practice_topic_title}")) ||
                (task.id == "task10" && !task.template.contains("{sentence_extraction_detail}")) ||
                (task.id == "task12" && (
                    !task.template.contains("cleaned_chinese_text") ||
                    !task.template.contains("\"pinyin\"") ||
                    !task.template.contains("distinct, fully formed, grammatically correct sentences") ||
                    !task.template.contains("same quality bar as Sentence Improvement") ||
                    !task.template.contains("Pass 2 - Improve every extracted candidate") ||
                    !task.template.contains("Do not output rough extracted text") ||
                    !task.template.contains("The three fields must match each other exactly")
                )) ||
                (task.id == PromptConfig.sentenceImprovementTaskID && (
                    !task.template.contains("Return JSON only") ||
                    !task.template.contains("\"sentence\"") ||
                    !task.template.contains("\"pinyin\"") ||
                    !task.template.contains("\"english\"") ||
                    !task.template.contains("The three fields must match each other exactly")
                )) {
                normalizedTemplate = defaultTask.template
            } else if task.template.contains("Task 4 – Isolate Phrases from Apple Vision") {
                normalizedTemplate = task.template.replacingOccurrences(
                    of: "Task 4 – Isolate Phrases from Apple Vision",
                    with: defaultTask.title
                )
            } else if task.id == "task9", task.template.contains("{practice_topic_sentence_count}") {
                normalizedTemplate = task.template.replacingOccurrences(
                    of: "{practice_topic_sentence_count}",
                    with: "{conversation_entry_count}"
                )
            } else if task.id == "task10", task.template.contains("Aim for 10 to 30 entries.") {
                normalizedTemplate = task.template.replacingOccurrences(
                    of: "Aim for 10 to 30 entries.",
                    with: "Aim for up to {conversation_entry_count} entries."
                )
            } else if task.id == "task11", task.template.contains("Create 100 entries in the \"entries\" array.") {
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
                    defaultTask.subjectType == .sentence) &&
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
            if selected == ["task5"] || selected == ["task7"] || selected == ["task8"] || selected == ["task10"] || selected == ["task11"] || selected == ["task12"] {
                full = cfg.collectionPreamble + body
            } else {
                full = cfg.collectionPreamble + body + cfg.collectionEpilogue
            }
        case .practiceTopic:
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
            .replacingOccurrences(of: "{practice_topic_sentence_count}", with: context.conversationEntryCount)
            .replacingOccurrences(of: "{conversation_entry_count}", with: context.conversationEntryCount)
            .replacingOccurrences(of: "{sentence_extraction_detail}", with: context.sentenceExtractionDetail)
    }
}
