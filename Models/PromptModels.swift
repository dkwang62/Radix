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
    var collectionPreamble: String
    var collectionEpilogue: String

    static let streamlitDefault = PromptConfig(
        version: 1,
        preamble: "",
        tasks: [
            PromptTask(
                id: "task1",
                title: "Task 1 – Character Analysis",
                template: """
You are a bilingual Chinese dictionary editor and teacher.

Explain a single Chinese character in depth for language learners. Focus on modern usage, and if the character is rare, show its more widely used modern equivalent while noting the original character.

⸻

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
                id: "task7",
                title: "Check OCR",
                template: """
Check OCR

You are checking a Radix saved page for likely OCR/capture mistakes.

Radix is giving you the saved page characters in reading order. Look for anomalies that suggest OCR captured the source incorrectly: unlikely character substitutions, broken phrases, repeated accidental characters, missing connective characters, implausible word boundaries, or characters that do not fit nearby dictionary evidence.

SAVED PAGE CHARACTERS:
{ocr_original}

RADIX-RECOGNIZED PAGE CHARACTERS:
{ocr_recognized}

CHARACTERS NOT RECOGNIZED BY RADIX:
{ocr_unrecognized}

DICTIONARY PHRASES DETECTED NEARBY:
{ocr_nearby_phrases}

Use the saved page characters as the main input. If a source image is attached, use it only as supporting evidence. Reconstruct the source faithfully. Correct likely OCR mistakes, but do not modernize, paraphrase, translate, or silently replace unfamiliar names, slang, technical terms, traditional forms, or regional usage merely because they are absent from a dictionary.

The corrected source text must remain in its original Chinese. All explanations, confidence reasons, uncertainty notes, and other commentary must be written in clear English.

Return exactly these sections:

[[CORRECTED TEXT]]
The complete corrected source text, preserving reading order and punctuation.

[[CHANGES]]
One proposed change per line:
original Chinese → corrected Chinese | high/medium/low | brief reason in English

[[UNCERTAIN]]
Explain uncertain passages in English while quoting the relevant Chinese.
Write "None" if there are none.

Never claim certainty when the image is unclear. Do not explain the corrections in Chinese. Do not include any text outside these three sections.

"""
            ),
            PromptTask(
                id: "task4",
                title: "Extract Phrases",
                template: """
Extract Phrases

Extract useful 2-character, 3-character, and 4-character Chinese phrases found within the characters provided that serve as standard dictionary headwords.

[CRITICAL RULES]
1. Reading Order: Scan and extract candidates in natural reading order sequence from the character pool.
2. Dictionary Attestation: Only include a phrase if it is an established entry in a reputable dictionary (e.g., CC-CEDICT, Pleco, MDBG, Wiktionary, or standard contemporary Chinese dictionaries).
3. No Arbitrary N-grams: Do NOT combine adjacent characters into a phrase unless they genuinely form a standalone dictionary word. Avoid partial grammar patterns, sentence fragments, or accidental OCR groupings.
4. No Exclusions: Do not include proper nouns, individual person names, specific dates, or titles unless they double as standard cultural vocabulary items.
5. Absolute Fidelity: Do not invent words or use characters not explicitly present in the provided text.
6. Output Format: You must output the results strictly in the following plain text format, one per line:
Phrase | Pinyin | Concise English meaning

[OUTPUT CONSTRAINT]
Do not include markdown tables, markdown column formatting, numbered lists, bullet points, headers, intro text, or concluding commentary. Output ONLY the raw lines matching the format above.

Before answering, silently verify that every non-empty line has exactly this structure:
Chinese phrase | pinyin | meaning

"""
            ),
            PromptTask(
                id: "task5",
                title: "Translate",
                template: """
Translate

Master Prompt: The Bilingual Editor's Analytical Report

Role: Act as an expert Bilingual Chinese Dictionary Editor, Translator, and Content Strategist. Your specialty is deconstructing high-impact media language, "clickbait" shorthand, and neologisms.

Task: Translate the provided Chinese text into a structured English report. Do not provide a literal word-for-word translation. Instead, decode the underlying logic, emotional subtext, and editorial techniques.

Instructions for Processing:

Identify Content Type: Briefly state the nature of the text (e.g., Tabloid Headlines, Viral Social Media Post, Technical Manual).

Linguistic Spotlight (Shorthand & Contractions):

Identify "Telegraphic Shorthand" (e.g., 2-character mashups like 恐害, 驚爆, 疑遭).

Create a table to deconstruct these: Contraction | Grammatical Expansion (the full phrase) | Nuance/Effect.

Structural Grouping: Group related ideas under descriptive headings (##).

Linguistic Mapping: For each key point, include the original Chinese characters in parentheses—e.g., Key Concept (中文版本)—to show how the source was interpreted.

Clarity & Nuance:

Translate idioms into natural English equivalents.

Use Bold for high-impact phrases or central themes.

Meta-Data & Noise: Separate hashtags, timestamps, and channel promotions into a dedicated section at the bottom.

Report Structure Requirements:

Header: Brief Content Overview.

Section 1: ## Linguistic Deconstruction (Shorthand Analysis).

Section 2: ## Thematic Analysis (Grouped by Subject Matter).

Section 3: ## Emotional Tone & Impact.

Section 4: --- (Horizontal Rule) Meta-Data & System Noise.

Source Material:

Image/Source: {collection_name}

Characters: {capture_chars}

OCR Text/Context:
{capture_text}

"""
            ),
            PromptTask(
                id: "task8",
                title: "Create Quiz",
                template: """
Create Quiz

You are a patient Chinese language teacher creating a standard language-learning practice quiz from one captured Radix page.

Use the supplied page as the only source material. Do not invent facts beyond the page text and the listed characters. Explanations must be in English.

Default quiz settings:
- Difficulty: 5/10 unless the learner asks for a different level.
- Number of questions: 10 unless the learner asks for a different length.
- Mode: Practice mode.

Practice mode rules:
1. Do not show the answer key at the start.
2. Ask one question at a time.
3. Wait for the learner's answer before revealing whether it is correct.
4. After each answer, explain briefly in English why the answer is correct or incorrect.
5. Mix familiar quiz formats: multiple choice, meaning recognition, pinyin/reading, phrase-in-context, best translation, and short explanation.
6. At difficulty 1–3, focus on recognition, basic meaning, and pinyin.
7. At difficulty 4–6, test usage, sentence meaning, and common confusions.
8. At difficulty 7–8, use plausible distractors, context, nuance, and phrase comparison.
9. At difficulty 9–10, test native-like usage, ambiguity, tone/register, shorthand, and subtle differences.

Start by saying:
"I’ll quiz you on this Radix page at difficulty 5/10. I’ll ask one question at a time and keep the answers hidden until you reply. If you want a different difficulty from 1 to 10, tell me now."

Then ask Question 1 only.

Page: {collection_name}
Referenced Chinese characters: {capture_chars}
OCR text/context:
{capture_text}

"""
            ),
            PromptTask(
                id: "task10",
                title: "Extract Sentences",
                template: """
Extract Sentences

Create a Radix Conversation Practice import pack from one saved page.

Page: {collection_name}
Saved page characters in reading order:
{capture_chars}

OCR text/context:
{capture_text}

Return JSON only. Do not wrap it in Markdown. Do not include explanations outside the JSON.

The JSON must match this exact lightweight top-level shape so Radix can import it directly:
{
  "theme": "{collection_name}",
  "entries": [
    {
      "id": "page_sentence_001",
      "zh": "Simplified Chinese sentence from the page.",
      "pinyin": "Tone-mark pinyin.",
      "en": "Natural English translation."
    }
  ]
}

Rules:
1. Set "theme" exactly to the Page value above: "{collection_name}". Do not summarize, translate, rename, shorten, or add punctuation to the theme.
2. Extract complete, useful Chinese sentences or short conversation-ready lines from the saved page.
3. Prefer concise studyable entries, but do not enforce a maximum Chinese character count.
4. Reword or split long source ideas when that produces clearer complete practice sentences.
5. Do not create fragments. Each zh value must be a complete, speakable sentence or conversation line.
6. Preserve the original Chinese meaning. Use Simplified Chinese in zh unless the source is clearly Traditional-only.
7. Skip OCR noise, fragments, duplicated lines, headings that are not useful for practice, and isolated vocabulary items.
8. Add accurate tone-mark pinyin for the full sentence.
9. Keep English translations natural, short, and learner-friendly.
10. Aim for 10 to 30 entries. If the page has fewer useful sentences, return only the useful ones.
11. IDs must be stable and lowercase, using page_sentence plus a zero-padded sequence number, for example "page_sentence_001".
12. Each entry must have exactly these keys: "id", "zh", "pinyin", and "en".
13. Do not include analysis, metadata, notes, markdown, comments, or explanation text. Radix derives those during import.

Before returning, silently validate that the JSON is valid, imports cleanly, and every entry contains only the required keys.

"""
            ),
            PromptTask(
                id: "task9",
                title: "Generate Practice Pack",
                template: """
Generate Conversation Practice Pack

Create structured Mandarin conversation practice content for Radix.

Topic ID: {practice_topic_id}
Topic: {practice_topic_title}
Summary: {practice_topic_summary}
Theme brief: {practice_topic_brief}
Required situations:
{practice_topic_situations}

Return JSON only. Do not wrap it in Markdown. Do not include explanations outside the JSON.

The JSON must match this exact lightweight top-level shape so Radix can import it directly:
{
  "theme": "{practice_topic_title}",
  "entries": [
    {
      "id": "{practice_topic_id}_001",
      "zh": "Simplified Chinese sentence.",
      "pinyin": "Tone-mark pinyin.",
      "en": "Natural English translation."
    }
  ]
}

Create exactly {practice_topic_sentence_count} entries in the "entries" array.

Each entry must have exactly these keys: "id", "zh", "pinyin", and "en".

Rules:
1. Use Simplified Chinese in zh.
2. Use tone marks in pinyin.
3. Keep English translations natural, short, and learner-friendly.
4. Start easy and gradually become slightly more complex.
5. Prefer concise studyable entries, but do not enforce a maximum Chinese character count.
6. Reword or split longer ideas when that makes the practice material clearer.
7. Do not create fragments. Each zh value must be a complete, speakable sentence or conversation line.
8. IDs must be stable and lowercase, using the topic ID plus a zero-padded sequence number, for example "{practice_topic_id}_001".
9. Cover the required situations across the full pack.
10. Include practical beginner conversation patterns: questions, answers, polite requests, offers, preferences, prices, portions, and short responses when relevant to the theme.
11. Do not include analysis, metadata, notes, markdown, comments, or explanation text. Radix derives those during import.

Before returning, silently validate that the JSON is valid, imports cleanly, and every entry contains only the required keys.

"""
            )
        ],
        epilogue: """
        Hanzi: {char}
        - English definition: {def_en}
        """,
        collectionPreamble: "",
        collectionEpilogue: """
        Image: {collection_name}
        Referenced Chinese characters: {capture_chars}
        OCR text/context:
        {capture_text}
        """
    )

    static let collectionTaskIDs: Set<String> = ["task4", "task5", "task7", "task8", "task10"]
    static let practiceTopicTaskIDs: Set<String> = ["task9"]

    static var defaultSelectedTaskIDs: [String] {
        streamlitDefault.tasks
            .filter { !collectionTaskIDs.contains($0.id) && !practiceTopicTaskIDs.contains($0.id) }
            .map(\.id)
    }

    init(
        version: Int,
        preamble: String,
        tasks: [PromptTask],
        epilogue: String,
        collectionPreamble: String = "",
        collectionEpilogue: String = ""
    ) {
        self.version = version
        self.preamble = preamble
        self.tasks = tasks
        self.epilogue = epilogue
        self.collectionPreamble = collectionPreamble
        self.collectionEpilogue = collectionEpilogue.isEmpty ? PromptConfig.defaultCollectionEpilogue : collectionEpilogue
    }

    private enum CodingKeys: String, CodingKey {
        case version, preamble, tasks, epilogue, collectionPreamble, collectionEpilogue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        preamble = try container.decode(String.self, forKey: .preamble)
        tasks = try container.decode([PromptTask].self, forKey: .tasks)
        epilogue = try container.decode(String.self, forKey: .epilogue)
        collectionPreamble = try container.decodeIfPresent(String.self, forKey: .collectionPreamble) ?? ""
        collectionEpilogue = try container.decodeIfPresent(String.self, forKey: .collectionEpilogue) ?? PromptConfig.defaultCollectionEpilogue
    }

    private static var defaultCollectionEpilogue: String {
        streamlitDefault.collectionEpilogue
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
    let collectionName: String
    let captureCharacters: String
    let captureText: String
    let originalOCRText: String
    let recognizedOCRCharacters: String
    let unrecognizedOCRCharacters: String
    let nearbyOCRPhrases: String
    let practiceTopicID: String
    let practiceTopicTitle: String
    let practiceTopicSummary: String
    let practiceTopicBrief: String
    let practiceTopicSituations: String
    let practiceTopicSentenceCount: String
}

extension PromptConfig {
    func normalized() -> PromptConfig {
        var seen = Set<String>()
        let cleaned = tasks.filter {
            guard $0.id != "task6" else { return false }
            guard !$0.id.isEmpty, !seen.contains($0.id) else { return false }
            seen.insert($0.id)
            return true
        }.map { task in
            guard (PromptConfig.collectionTaskIDs.contains(task.id) || PromptConfig.practiceTopicTaskIDs.contains(task.id)),
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
            } else {
                normalizedTitle = task.title
            }

            let normalizedTemplate: String
            if task.template.contains("{capture_chars}") || task.template.contains("{capture_text}") || task.template.contains("{collection_name}") ||
                task.template.contains("Task 4 – Extract Phrases from Image") ||
                task.template.contains("Task 4 – Extract Phrases from Page (image)") ||
                (task.id == "task4" && !task.template.contains("[CRITICAL RULES]")) ||
                task.template.contains("Task 5 – Universal Content Architect") ||
                (task.id == "task5" && !task.template.contains("Bilingual Chinese Dictionary Editor")) ||
                (task.id == "task7" && (
                    task.template.contains("ORIGINAL OCR:") ||
                    task.template.contains("attached source image and dictionary evidence") ||
                    !task.template.contains("SAVED PAGE CHARACTERS:")
                )) ||
                (task.id == "task9" && !task.template.contains("{practice_topic_title}")) {
                normalizedTemplate = defaultTask.template
            } else if task.template.contains("Task 4 – Isolate Phrases from Apple Vision") {
                normalizedTemplate = task.template.replacingOccurrences(
                    of: "Task 4 – Isolate Phrases from Apple Vision",
                    with: defaultTask.title
                )
            } else {
                normalizedTemplate = task.template
            }

            return PromptTask(id: task.id, title: normalizedTitle, template: normalizedTemplate)
        }
        if cleaned.isEmpty {
            return .streamlitDefault
        }
        let defaultsByID = Dictionary(uniqueKeysWithValues: PromptConfig.streamlitDefault.tasks.map { ($0.id, $0) })
        let missingDefaults = PromptConfig.streamlitDefault.tasks.filter { defaultTask in
            !seen.contains(defaultTask.id) &&
                (PromptConfig.collectionTaskIDs.contains(defaultTask.id) || PromptConfig.practiceTopicTaskIDs.contains(defaultTask.id)) &&
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
        case .character:
            full = cfg.preamble + body + cfg.epilogue
        case .collection:
            if selected == ["task5"] || selected == ["task7"] || selected == ["task8"] || selected == ["task10"] {
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
            .replacingOccurrences(of: "{practice_topic_sentence_count}", with: context.practiceTopicSentenceCount)
    }
}
