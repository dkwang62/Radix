import Foundation

struct PromptTask: Codable, Hashable, Identifiable {
    let id: String
    var title: String
    var template: String
}

struct PromptConfig: Codable, Hashable {
    var version: Int
    var preamble: String
    var tasks: [PromptTask]
    var epilogue: String

    static let streamlitDefault = PromptConfig(
        version: 1,
        preamble: """
You are a bilingual Chinese dictionary editor and teacher.

For character tasks, explain a single Chinese character in depth for language learners. For OCR phrase tasks, isolate useful Chinese phrases from Apple Vision output and prepare them for dictionary entry.

⸻

""",
        tasks: [
            PromptTask(
                id: "task1",
                title: "Task 1 – Character Analysis",
                template: """
Task 1 – Character Analysis

For the Hanzi below, provide:
\t1.\tOriginal meaning – Decompose character into nameable components. Briefly note the ancient form or origin only if it helps understand modern usage.
\t2.\tCore semantic concept – summarize the main idea in modern context.
\t3.\tWhy it is used in compound characters – explain how it contributes meaning to words in everyday or contemporary Chinese.
\t4.\tThree example words – include pinyin and natural English meanings, using modern common usage.
\t5.\tOne modern usage sentence – show the character in real-life context; if the character is rare, use the modern equivalent and note it.

⸻

"""
            ),
            PromptTask(
                id: "task2",
                title: "Task 2 – Example Sentences and Images",
                template: """
Task 2 – Example Sentences and Images

Provide two example sentences that best illustrate modern, everyday usage of the character (or its modern equivalent if the original is rare). For each sentence, include:
a) Traditional Chinese
b) Simplified Chinese
c) Natural English translation
d) Target word/phrase (must include the character or its modern equivalent)
e) Read-aloud pinyin of the full sentence (with tone marks and natural word grouping)

Images:
\t•\tIf the character represents a concrete object, generate a realistic image showing its material, context, and typical use.
\t•\tIf the character represents an abstract concept, quality, or person, do not generate an image.

Note: Only generate images in Task 2 to avoid overlap with analysis or conceptual comparisons.

⸻

"""
            ),
            PromptTask(
                id: "task3",
                title: "Task 3 – Conceptual Contrast",
                template: """
Task 3 – Conceptual Contrast

Compare this character with 2–3 other characters of similar meaning or usage, including pinyin. Explain:
\t•\tHow Chinese divides this concept into different semantic or conceptual systems in modern language usage.
\t•\tHow the characters differ in real-life usage, highlighting subtle distinctions learners should know.
\t•\tDo not repeat example sentences from Task 2; only discuss relationships and usage distinctions.

⸻

"""
            ),
            PromptTask(
                id: "task4",
                title: "Task 4 – Isolate Phrases from Apple Vision",
                template: """
Task 4 – Isolate Phrases from Apple Vision

From the Apple Vision OCR text and detected character list below, extract useful 2-, 3-, and 4-character Chinese phrases that are found as dictionary headwords.

Rules:
\t•\tKeep the OCR text context in mind.
\t•\tReturn only useful phrase candidates that are attested in Chinese dictionaries.
\t•\tOnly include a phrase if it would normally appear as an entry in a reputable dictionary such as CC-CEDICT, Pleco, MDBG, Wiktionary, or a standard Chinese dictionary.
\t•\tPrioritize common, natural dictionary phrases.
\t•\tAvoid rare, awkward, or accidental character combinations.
\t•\tAvoid arbitrary n-grams, sentence fragments, partial grammar patterns, names, titles, dates, and OCR accidents unless they are also normal dictionary entries.
\t•\tDo not invent phrases that are not clearly supported by the OCR text or detected characters.
\t•\tInclude only 2-, 3-, and 4-character Chinese phrases.
\t•\tProvide pinyin with tone marks.
\t•\tProvide a concise English meaning.
\t•\tOutput only in this format:
Phrase | Pinyin | Concise English meaning

Apple Vision detected characters:
{capture_chars}

Apple Vision OCR text:
{capture_text}

Important:
\t•\tDo not explain your method.
\t•\tDo not include headings, numbering, bullets, markdown tables, or extra commentary.

⸻

"""
            )
        ],
        epilogue: """
        Hanzi: {char}
        - English definition: {def_en}
        """
    )

    static var defaultSelectedTaskIDs: [String] {
        streamlitDefault.tasks
            .filter { $0.id != "task4" }
            .map(\.id)
    }
}

struct PromptRenderContext {
    let char: String
    let definitionEN: String
    let decomposition: String
    let semantic: String
    let phonetic: String
    let phoneticPinyin: String
    let isSoundMatch: String
    let pronunciationFamily: String
    let semanticFamily: String
    let captureCharacters: String
    let captureText: String
}

extension PromptConfig {
    func normalized() -> PromptConfig {
        var seen = Set<String>()
        let cleaned = tasks.filter {
            guard !$0.id.isEmpty, !seen.contains($0.id) else { return false }
            seen.insert($0.id)
            return true
        }
        if cleaned.isEmpty {
            return .streamlitDefault
        }
        let defaultsByID = Dictionary(uniqueKeysWithValues: PromptConfig.streamlitDefault.tasks.map { ($0.id, $0) })
        let missingDefaults = PromptConfig.streamlitDefault.tasks.filter { defaultTask in
            !seen.contains(defaultTask.id) && defaultTask.id == "task4" && defaultsByID[defaultTask.id] != nil
        }
        return PromptConfig(
            version: version,
            preamble: preamble,
            tasks: cleaned + missingDefaults,
            epilogue: epilogue
        )
    }

    func renderPrompt(selectedTaskIDs: [String], context: PromptRenderContext) -> String {
        let cfg = normalized()
        let selected = Set(selectedTaskIDs)
        let body = cfg.tasks
            .filter { selected.contains($0.id) }
            .map(\.template)
            .joined()
        let full = cfg.preamble + body + cfg.epilogue
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
            .replacingOccurrences(of: "{capture_chars}", with: context.captureCharacters)
            .replacingOccurrences(of: "{capture_text}", with: context.captureText)
    }
}
