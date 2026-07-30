import Foundation

enum PromptTaskSubjectType: String, Codable, CaseIterable, Identifiable {
    case characterPhrase
    case sentence
    case page
    case practiceTopic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .characterPhrase: return "Character / Phrase"
        case .sentence: return "Sentence"
        case .page: return "Page"
        case .practiceTopic: return "Practice Theme"
        }
    }

    var systemImage: String {
        switch self {
        case .characterPhrase: return "character"
        case .sentence: return "quote.bubble"
        case .page: return "photo.on.rectangle"
        case .practiceTopic: return "bubble.left.and.bubble.right"
        }
    }
}

struct PromptTask: Codable, Hashable, Identifiable {
    let id: String
    var title: String
    var template: String
    var subjectType: PromptTaskSubjectType = .characterPhrase

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case template
        case subjectType
    }

    init(
        id: String,
        title: String,
        template: String,
        subjectType: PromptTaskSubjectType = .characterPhrase
    ) {
        self.id = id
        self.title = title
        self.template = template
        self.subjectType = subjectType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        template = try container.decode(String.self, forKey: .template)
        subjectType = try container.decodeIfPresent(PromptTaskSubjectType.self, forKey: .subjectType) ??
            PromptConfig.defaultSubjectType(forTaskID: id)
    }
}

enum SentenceExtractionDetail: String, CaseIterable, Identifiable {
    case brief
    case detailed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .brief: return "Brief"
        case .detailed: return "Detailed"
        }
    }

    var promptInstruction: String {
        switch self {
        case .brief:
            return """
Brief mode: extract clean, concise sentence records. Keep each English translation short and natural. Include accurate tone-mark pinyin, but do not add notes, analysis, or extra metadata beyond the required JSON keys.
"""
        case .detailed:
            return """
Detailed mode: create richer study-ready sentence records. Keep each Chinese sentence complete and useful, include accurate tone-mark pinyin, provide a natural English meaning, and choose sentences that will display well with Chinese/English toggles, pinyin reveal, read-aloud, and phrase inspection in Radix. Prefer entries whose useful phrases can be inspected later, but do not add extra JSON keys.
"""
        }
    }

    static func normalized(_ rawValue: String?) -> SentenceExtractionDetail {
        guard let rawValue,
              let detail = SentenceExtractionDetail(rawValue: rawValue)
        else { return .brief }
        return detail
    }
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

""",
                subjectType: .page
            ),
            PromptTask(
                id: "task4",
                title: "Extract Phrases",
                template: """
Extract Phrases

Extract useful 2-character, 3-character, and 4-character Chinese phrases found within the provided page text that serve as clean dictionary headwords.

[CRITICAL RULES]
1. Reading Order: Scan and extract candidates in natural reading order sequence from the character pool.
2. Dictionary Attestation: Only include a phrase if it is an established entry in a reputable dictionary (e.g., CC-CEDICT, Pleco, MDBG, Wiktionary, or standard contemporary Chinese dictionaries).
3. No Arbitrary N-grams: Do NOT combine adjacent characters into a phrase unless they genuinely form a standalone dictionary word or proper name. Avoid partial grammar patterns, sentence fragments, accidental OCR groupings, and spans that include an unrelated leading/trailing character.
4. Boundary Quality: Prefer the shortest complete dictionary headword or name. If a candidate contains an extra verb, preposition, particle, classifier, punctuation fragment, or OCR-adjacent character, trim it or skip it. For example, from "进青瓦屋" extract "青瓦屋" only if it is a meaningful place/object name; never output "进青瓦屋".
5. Proper Names: Include person names, place names, organization names, works, brands, and culturally important titles only when the text clearly uses them as names. The English meaning must identify the name type, e.g. "Qingwa House, a place/building name", "Li Bai, a Tang dynasty poet", or "Shanghai, a city in China".
6. Dictionary-quality Meanings: Write concise dictionary-style meanings, not vague summaries. Prefer "electric vehicle industry" over "about electric vehicles"; prefer "a place name" or "a person's name" when the phrase is a proper noun.
7. Absolute Fidelity: Do not invent words or use characters not explicitly present in the provided text.
8. Output Format: You must output the results strictly in the following plain text format, one per line:
Phrase | Pinyin | Concise English meaning

[OUTPUT CONSTRAINT]
Do not include markdown tables, markdown column formatting, numbered lists, bullet points, headers, intro text, or concluding commentary. Output ONLY the raw lines matching the format above.

Before answering, silently verify that every non-empty line has exactly this structure:
Chinese phrase | pinyin | meaning

Silently discard any candidate whose boundaries or meaning are uncertain. Fewer high-quality phrases are better than many noisy groupings.

""",
                subjectType: .page
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

""",
                subjectType: .page
            ),
            PromptTask(
                id: "task8",
                title: "Create Quiz",
                template: """
Create Quiz

You are a bilingual Chinese dictionary editor, teacher, and quizmaster.

You are the quizmaster.
The human user is the learner.
Your job is to ask one quiz question at a time and wait for the learner's answer.

Use the supplied Radix page as the subject. Create questions primarily from the page and OCR context, but you may naturally extend the material with synonyms, antonyms, idioms, collocations, related vocabulary, common expressions, and HSK-appropriate words.

Default settings:
- Script: Simplified Chinese unless the learner asks for Traditional.
- Difficulty: HSK 4 unless the learner asks for another HSK level.
- Flow: one question at a time.
- Pinyin: never show pinyin before the learner answers.
- Answer choices: Chinese only, no English, no pinyin, no definitions, no hints.

Important:
The English translation under the question must help the learner understand the situation, but it must not reveal, define, translate, or strongly imply the correct answer. If a direct translation would reveal the answer, use "---" or "[missing word]" in English.

Question variety:
Rotate between fill-in-the-blank, synonym, antonym, character meaning, radical/structure, measure words, grammar, sentence correction, collocations, word order, contextual usage, and appropriate word selection. Avoid using the same question type more than twice in a row.

Required question format:

Question X - [Question Type] (HSK N)

中文:
...

English:
...

请选择最合适的答案:

A. ...
B. ...
C. ...
D. ...

请回答 A、B、C 或 D。

Start sequence:
First state:
"I will quiz you using HSK [Level] standards. Questions will be in Simplified Chinese by default. Answer choices will be Chinese only. English translations will not reveal the answer. Pinyin will only appear after you answer. Let me know if you want Traditional Chinese or a different HSK level."

Then ask Question 1 using the required format.

After displaying Question 1, stop immediately. Do not answer your own question. Do not reveal the correct answer, pinyin, analysis, explanation, or Question 2 until the learner replies.

After the learner answers:
1. Say whether the answer is correct.
2. Reveal the correct answer.
3. Give pinyin.
4. Explain why it is correct.
5. Briefly explain why the other choices are wrong.
6. Give the complete sentence if applicable.
7. Give a natural English translation.
8. Then ask the next question.

Core Rules:
- Never include English, pinyin, definitions, or hints inside answer choices.
- Never reveal the answer before the learner responds.
- Never ask more than one question at a time.
- Never restart the quiz unless the learner explicitly requests a new quiz.
- Maintain quiz state internally, continue numbering sequentially, remember recently tested vocabulary, and avoid repeating recent questions.
- Before every question, silently verify that it follows the required format, uses Chinese-only answer choices, contains no pinyin before the learner answers, and does not leak the answer through English.

Page: {collection_name}
Referenced Chinese characters: {capture_chars}
OCR text/context:
{capture_text}

""",
                subjectType: .page
            ),
            PromptTask(
                id: "task10",
                title: "Sentence Practice",
                template: """
Sentence Practice

Create a Radix Conversation Practice import pack from one saved page.

Page: {collection_name}
Saved page characters in reading order:
{capture_chars}

OCR text/context:
{capture_text}

Detail level:
{sentence_extraction_detail}

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
10. Aim for up to {conversation_entry_count} entries. If the page has fewer useful sentences, return only the useful ones.
11. IDs must be stable and lowercase, using page_sentence plus a zero-padded sequence number, for example "page_sentence_001".
12. Each entry must have exactly these keys: "id", "zh", "pinyin", and "en".
13. Do not include analysis, metadata, notes, markdown, comments, or explanation text. Radix derives those during import.
14. Follow the selected Detail level above. Both Brief and Detailed modes must return the same JSON shape so Radix imports them into the same sentence database and displays them through the same sentence UI.

Before returning, silently validate that the JSON is valid, imports cleanly, and every entry contains only the required keys.

""",
                subjectType: .page
            ),
            PromptTask(
                id: "task11",
                title: "Create Conversation",
                template: """
Create Conversation

Create a personalized, current, and varied Mandarin conversation practice pack for Radix using one saved page as the source inspiration.

Page: {collection_name}
Saved page characters in reading order:
{capture_chars}

OCR text/context:
{capture_text}

First infer the broad conversational theme of the page. Use the page as a springboard, not a cage: do not merely extract or translate the page. Generate new useful conversation lines around the page's theme, related real-life situations, and natural follow-up topics.

Use any context you have from this chat about the learner's goals, location, interests, upcoming plans, work, study, travel, hobbies, current needs, or preferred style.
If you can browse, search, or use current knowledge, include timely everyday scenarios and popular topics of the day that naturally connect to the page's theme.
If you do not have user context or current-event access, invent varied realistic circumstances that would be useful for a Mandarin learner.
The result should feel tailored to this learner and this moment, while still being practical language-learning material.

Return JSON only. Do not wrap it in Markdown. Do not include explanations outside the JSON.

The JSON must match this exact lightweight top-level shape so Radix can import it directly:
{
  "theme": "Readable theme inspired by {collection_name}",
  "entries": [
    {
      "id": "page_practice_001",
      "zh": "Simplified Chinese conversation line.",
      "pinyin": "Tone-mark pinyin.",
      "en": "Natural English translation."
    }
  ]
}

Create exactly {conversation_entry_count} entries in the "entries" array.

Each entry must have exactly these keys: "id", "zh", "pinyin", and "en".

Rules:
1. Set "theme" to a short readable title for the inferred page theme. It may be based on the page name, but it does not need to match it exactly.
2. Use Simplified Chinese in zh.
3. Use tone marks in pinyin.
4. Keep English translations natural, short, and learner-friendly.
5. Start easy and gradually become slightly more complex.
6. Prefer concise studyable entries, but do not enforce a maximum Chinese character count.
7. Reword or split longer ideas when that makes the practice material clearer.
8. Do not create fragments. Each zh value must be a complete, speakable sentence or conversation line.
9. IDs must be stable and lowercase, using page_practice plus a zero-padded sequence number, for example "page_practice_001".
10. Vary the concrete people, places, problems, opinions, questions, answers, and conversation contexts.
11. Include practical conversation patterns: questions, answers, polite requests, offers, preferences, opinions, comparisons, clarifications, and short responses when relevant to the inferred theme.
12. Make some entries refer to timely or popular topics when they fit naturally, but keep each sentence useful even after the topic is no longer trending.
13. Do not include analysis, metadata, notes, markdown, comments, or explanation text. Radix derives those during import.

Before returning, silently validate that the JSON is valid, imports cleanly, and every entry contains only the required keys.

""",
                subjectType: .page
            ),
            PromptTask(
                id: "task12",
                title: "Extract Sentences",
                template: """
Extract Sentences

Extract the meaningful content of one Radix saved page into a clean list of distinct, studyable sentences.

Page: {collection_name}
Saved page characters in reading order:
{capture_chars}

Original OCR/source context:
{capture_text}

Your job is to scrape/extract the usable saved-page/OCR material, filter out noise and nonsensical fragments, and return complete, grammatically correct Chinese prose plus sentence records for Radix Study.

Completeness requirement: process the entire meaningful source page. Do not summarize, sample, choose representative sentences, or omit usable source content merely because it feels difficult, long, or less interesting. Filter out pure OCR noise, broken character runs, duplicated lines, isolated labels with no study value, nonsensical fragments that cannot be repaired, and repeated content. The "sentences" array must cover the full cleaned_chinese_text in reading order. If one source line contains multiple ideas, split it into multiple complete sentences. If a source fragment is too short or telegraphic, expand it only enough to preserve that fragment's meaning as a natural learning sentence. If a fragment cannot be made coherent without inventing facts, skip it and mention the omission in repair_notes.

Use the source faithfully, but repair obvious OCR/capture errors when context makes the repair likely. Expand telegraphic media shorthand, abbreviations, compressed journalistic compounds, headline compression, captions, list fragments, or social-media shorthand into natural complete Chinese sentences. Replace concise headline-style compounds with normal phrases or clauses a learner could say, while preserving the original meaning. Do not invent unrelated facts, people, dates, claims, or events. If a detail is uncertain, keep it modest and note the uncertainty in repair_notes.

Return JSON only. Do not wrap it in Markdown. Do not include explanations outside the JSON.

The JSON must match this exact top-level shape:
{
  "cleaned_title": "Readable title for the cleaned page",
  "cleaned_chinese_text": "Complete cleaned Chinese prose, suitable for sentence-by-sentence study.",
  "sentences": [
    {
      "id": "ai_page_sentence_001",
      "chinese": "One complete cleaned Chinese sentence.",
      "pinyin": "Tone-mark pinyin for the full Chinese sentence.",
      "english": "Natural English meaning.",
      "phrase_hints": ["useful phrase", "another useful phrase"]
    }
  ],
  "english_summary": "One short English summary of the cleaned page.",
  "repair_notes": ["Brief note about one OCR repair or shorthand expansion."]
}

Rules:
1. Use Simplified Chinese in cleaned_chinese_text and sentences unless the source is clearly Traditional-only.
2. cleaned_chinese_text must be the joined, readable cleaned page prose, not a list of isolated characters or unrepaired OCR fragments.
3. The sentences array must be a list of distinct, fully formed, grammatically correct sentences that represents the entire cleaned page, not a sample. Every meaningful source clause, caption, subtitle, headline fragment, menu item, or list item should appear in cleaned_chinese_text and be represented by one or more sentence records.
4. IDs must be stable and lowercase, using ai_page_sentence plus a zero-padded sequence number, for example "ai_page_sentence_001".
5. Add accurate tone-mark pinyin for the full sentence in each sentence item's "pinyin" value.
6. phrase_hints should contain useful 2- to 6-character Chinese chunks that help explain the sentence. Do not include pinyin or English in phrase_hints.
7. If the original source is only a headline, caption, menu, subtitle, or short fragment, expand only enough to make natural learning sentences while preserving the source's meaning.
8. Expand abbreviated or journalistic compound wording into ordinary Chinese phrasing; do not keep telegraphic headline style when it would be unnatural for sentence study.
9. repair_notes should be in English and should mention only meaningful OCR repairs, inferred expansions, or uncertainty. Use an empty array if there are none.
10. Do not keep duplicated sentences, nonsense, partial character strings, or unrepairable fragments just to preserve volume. Mention meaningful omissions in repair_notes.
11. Do not drop difficult or low-interest content if it can be repaired into a coherent sentence without invention.
12. Do not include markdown, comments, extra keys, or analysis outside the JSON.

Before returning, silently validate that the JSON is valid, every sentence contains exactly these keys: "id", "chinese", "pinyin", "english", and "phrase_hints", every sentence is distinct and fully formed, and the sentence list covers the entire cleaned_chinese_text rather than a representative subset.

""",
                subjectType: .page
            ),
            PromptTask(
                id: "task13",
                title: "Sentence",
                template: """
Sentence

Work with this Radix sentence as the subject.

Chinese:
{sentence_zh}

Pinyin:
{sentence_pinyin}

English:
{sentence_en}

Useful phrases:
{sentence_phrases}

Characters:
{sentence_characters}

Explain the whole sentence naturally for a Chinese learner. Focus on meaning, grammar, word choice, useful phrases, and what sounds natural in real Mandarin. Do not analyze it as isolated characters unless that helps explain the sentence.

""",
                subjectType: .sentence
            ),
            PromptTask(
                id: "task14",
                title: "Sentence Improvement",
                template: """
Sentence Improvement

Improve this Radix Chinese sentence or messy input string and return the full synced Radix sentence payload.

Input sentence:
{sentence_zh}

Pinyin if available:
{sentence_pinyin}

Current English meaning if available:
{sentence_en}

Useful phrases if available:
{sentence_phrases}

Task:
Rewrite the input into one clean, complete, coherent Chinese sentence. Preserve the original core intent, topic, people, places, time, tone, and factual claims as much as possible.

Rules:
1. Output Chinese in `sentence`. Do not translate the sentence into another language.
2. Repair awkward wording, broken grammar, OCR/copy-paste damage, telegraphic phrasing, missing connectors, and nonsensical wording when the intended meaning is reasonably clear.
3. If the input contains several unrelated ideas, choose the main intended idea and rewrite it as one complete sentence.
4. Do not invent new facts, names, dates, opinions, locations, or claims.
5. If part of the input is unrecoverable noise, omit only that noise while preserving the coherent intent.
6. Generate `pinyin` from the final `sentence`, not from the original input.
7. Generate `english` as the natural English meaning of the final `sentence`, not the old sentence.
8. The three fields must match each other exactly: `sentence`, `pinyin`, and `english` must describe the same final sentence.

Return JSON only, with exactly these keys:
{
  "sentence": "clean improved Chinese sentence",
  "pinyin": "pinyin for the final sentence",
  "english": "natural English meaning of the final sentence"
}

Before answering, silently verify that the sentence is grammatical, complete, coherent, and that pinyin and English match the final sentence.

""",
                subjectType: .sentence
            ),
            PromptTask(
                id: "task9",
                title: "Generate Practice Pack",
                template: """
Generate Conversation Practice Pack

Create a personalized, current, and varied Mandarin conversation practice pack for Radix.

Topic ID: {practice_topic_id}
Topic: {practice_topic_title}
Summary: {practice_topic_summary}
Theme brief: {practice_topic_brief}
Required situations:
{practice_topic_situations}

Use the selected topic as the anchor, but do not make a generic textbook list.
Use any context you have from this chat about the learner's goals, location, interests, upcoming plans, work, study, travel, hobbies, current needs, or preferred style.
If you can browse, search, or use current knowledge, include timely everyday scenarios and popular topics of the day that naturally fit the selected theme.
If you do not have user context or current-event access, invent varied realistic circumstances that would be useful for a Mandarin learner.
The result should feel tailored to this learner and this moment, while still being practical language-learning material.

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

Create exactly {conversation_entry_count} entries in the "entries" array.

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
9. Cover the required situations across the full pack, but vary the concrete people, places, problems, and conversation contexts.
10. Include practical conversation patterns: questions, answers, polite requests, offers, preferences, prices, opinions, comparisons, clarifications, and short responses when relevant to the theme.
11. Make some entries refer to timely or popular topics when they fit naturally, but keep each sentence useful even after the topic is no longer trending.
12. Do not include analysis, metadata, notes, markdown, comments, or explanation text. Radix derives those during import.

Before returning, silently validate that the JSON is valid, imports cleanly, and every entry contains only the required keys.

""",
                subjectType: .practiceTopic
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

    static let collectionTaskIDs: Set<String> = ["task4", "task5", "task7", "task8", "task10", "task11", "task12"]
    static let practiceTopicTaskIDs: Set<String> = ["task9"]
    static let defaultSentenceTaskID = "task13"
    static let sentenceImprovementTaskID = "task14"
    static let conversationEntryCountTaskIDs: Set<String> = ["task9", "task10", "task11"]
    static let conversationEntryCountOptions = [25, 50, 100]
    static let defaultConversationEntryCount = 25

    static func defaultSubjectType(forTaskID taskID: String) -> PromptTaskSubjectType {
        if taskID == defaultSentenceTaskID || taskID == sentenceImprovementTaskID { return .sentence }
        if collectionTaskIDs.contains(taskID) { return .page }
        if practiceTopicTaskIDs.contains(taskID) { return .practiceTopic }
        return .characterPhrase
    }

    static func normalizedConversationEntryCount(_ value: Int) -> Int {
        conversationEntryCountOptions.contains(value) ? value : defaultConversationEntryCount
    }

    static var defaultSelectedTaskIDs: [String] {
        streamlitDefault.tasks
            .filter { $0.subjectType == .characterPhrase }
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
    let sentenceChinese: String
    let sentencePinyin: String
    let sentenceEnglish: String
    let sentencePhrases: String
    let sentenceCharacters: String
    let conversationEntryCount: String
    let sentenceExtractionDetail: String

    init(
        char: String,
        definitionEN: String,
        decomposition: String,
        semantic: String,
        phonetic: String,
        phoneticPinyin: String,
        isSoundMatch: String,
        pronunciationFamily: String,
        semanticFamily: String,
        collectionName: String,
        captureCharacters: String,
        captureText: String,
        originalOCRText: String,
        recognizedOCRCharacters: String,
        unrecognizedOCRCharacters: String,
        nearbyOCRPhrases: String,
        practiceTopicID: String,
        practiceTopicTitle: String,
        practiceTopicSummary: String,
        practiceTopicBrief: String,
        practiceTopicSituations: String,
        sentenceChinese: String = "",
        sentencePinyin: String = "",
        sentenceEnglish: String = "",
        sentencePhrases: String = "",
        sentenceCharacters: String = "",
        conversationEntryCount: String,
        sentenceExtractionDetail: String
    ) {
        self.char = char
        self.definitionEN = definitionEN
        self.decomposition = decomposition
        self.semantic = semantic
        self.phonetic = phonetic
        self.phoneticPinyin = phoneticPinyin
        self.isSoundMatch = isSoundMatch
        self.pronunciationFamily = pronunciationFamily
        self.semanticFamily = semanticFamily
        self.collectionName = collectionName
        self.captureCharacters = captureCharacters
        self.captureText = captureText
        self.originalOCRText = originalOCRText
        self.recognizedOCRCharacters = recognizedOCRCharacters
        self.unrecognizedOCRCharacters = unrecognizedOCRCharacters
        self.nearbyOCRPhrases = nearbyOCRPhrases
        self.practiceTopicID = practiceTopicID
        self.practiceTopicTitle = practiceTopicTitle
        self.practiceTopicSummary = practiceTopicSummary
        self.practiceTopicBrief = practiceTopicBrief
        self.practiceTopicSituations = practiceTopicSituations
        self.sentenceChinese = sentenceChinese
        self.sentencePinyin = sentencePinyin
        self.sentenceEnglish = sentenceEnglish
        self.sentencePhrases = sentencePhrases
        self.sentenceCharacters = sentenceCharacters
        self.conversationEntryCount = conversationEntryCount
        self.sentenceExtractionDetail = sentenceExtractionDetail
    }
}
