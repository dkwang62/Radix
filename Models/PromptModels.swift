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
                id: "task4",
                title: "Extract Phrases",
                template: """
Extract Phrases

You are producing data for an automatic parser. Follow the output contract exactly.

From the collection details below, extract relevant and high-impact 2-, 3-, and 4-character Chinese phrases that function as dictionary headwords.

Rules:

Keep the OCR text context in mind.

Relevance Filter: Prioritize specialized terminology, news keywords, idioms, and high-impact phrases that define the core narrative of the text (e.g., military, geopolitical, or descriptive terms).

Exclude Generic Terms: Avoid overly common words that do not contribute to the specific context of the page (e.g., "China," "Company," "Beijing," "Revenue") unless they are part of a larger specific phrase.

Return only useful phrase candidates (in Reading Order sequence) that are attested in Chinese dictionaries.

Provide pinyin with tone marks.

Provide a concise English meaning.

STRICT OUTPUT CONTRACT:

Output records only. No introduction, no conclusion, no explanation.

Do not output a header row.

Do not use Markdown tables, bullets, numbering, code blocks, or labels.

Every non-empty output line must contain exactly one phrase record.

Every record must contain exactly 3 fields separated by exactly 2 pipe characters.

Field order must be: Chinese phrase | pinyin with tone marks | concise English meaning.

Do not put pipe characters inside the English meaning.

VALID OUTPUT EXAMPLE:
人工智能 | rén gōng zhì néng | artificial intelligence
国际关系 | guó jì guān xì | international relations

INVALID OUTPUT EXAMPLES:
Phrase | Pinyin | Meaning
| Phrase | Pinyin | Meaning |
1. 人工智能 | rén gōng zhì néng | artificial intelligence

Important:

Do not explain your method.

Before answering, silently verify that every non-empty line has exactly this structure:
Chinese phrase | pinyin | meaning

"""
            ),
            PromptTask(
                id: "task6",
                title: "Gemini JSON Extract Phrases",
                template: """
Gemini JSON Extract Phrases

Use this task with the Gemini API using responseMimeType application/json and the JSON schema below. If you are using Gemini in a chat window instead of the API, return the same JSON object only.

System instruction:
You are a bilingual Chinese dictionary editor producing structured data for Radix. Extract only useful, dictionary-attested 2-, 3-, and 4-character Chinese phrase headwords from the supplied OCR text/context. Return valid JSON only.

Response JSON schema:
{
  "type": "object",
  "properties": {
    "phrases": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "phrase": {
            "type": "string",
            "description": "A 2-, 3-, or 4-character Chinese dictionary headword found in or strongly supported by the OCR text."
          },
          "pinyin": {
            "type": "string",
            "description": "Pinyin with tone marks."
          },
          "meaning": {
            "type": "string",
            "description": "A concise English meaning with no pipe characters."
          }
        },
        "required": ["phrase", "pinyin", "meaning"],
        "additionalProperties": false
      }
    }
  },
  "required": ["phrases"],
  "additionalProperties": false
}

Extraction rules:
- Keep the OCR text context in mind.
- Prioritize specialized terminology, news keywords, idioms, and high-impact phrases that define the core narrative of the text.
- Avoid overly common words that do not contribute to the specific page context unless they are part of a larger specific phrase.
- Return only phrase candidates that are attested in Chinese dictionaries.
- Preserve reading-order sequence.
- Do not include names, dates, arbitrary n-grams, sentence fragments, or OCR accidents unless they are also normal dictionary entries.
- If unsure whether a phrase is dictionary-attested, omit it.
- Use an empty phrases array if no useful new candidates are found.

Valid output example:
{
  "phrases": [
    {
      "phrase": "人工智能",
      "pinyin": "rén gōng zhì néng",
      "meaning": "artificial intelligence"
    },
    {
      "phrase": "国际关系",
      "pinyin": "guó jì guān xì",
      "meaning": "international relations"
    }
  ]
}

Do not output Markdown, comments, code fences, explanations, or any text outside the JSON object.

"""
            ),
            PromptTask(
                id: "task5",
                title: "Translate",
                template: """
Translate

Role: Act as an expert Bilingual Chinese Dictionary Editor, Translator, and Content Strategist.

Task: Translate the provided Chinese text into English. Instead of a literal word-for-word translation, organize the content into a structured report based on the logical patterns and emotional nuances found in the source.

Instructions:

Identify Content Type: Briefly state what the text appears to be (e.g., social media caption, technical manual, news headline, or poetic prose).

Structural Grouping: Group related ideas under descriptive headings (##).

Linguistic Mapping: For each key point, include the original Chinese characters in parentheses—e.g., Key Concept (中文版本)—to show how the source was interpreted.

Clarity & Nuance: Translate idiomatic expressions into natural English equivalents. Use Bold text for high-impact phrases or key themes.

Meta-Data & Noise: Separate any hashtags, timestamps, or system noise into a dedicated section at the bottom using a horizontal rule (---).

Visual Scannability: Use bullet points for lists to ensure the information is easy to digest at a glance.

Source Material:

Characters: {capture_chars}

Context/OCR Note: {collection_name}
{capture_text}

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

    static let collectionTaskIDs: Set<String> = ["task4", "task5", "task6"]

    static var defaultSelectedTaskIDs: [String] {
        streamlitDefault.tasks
            .filter { !collectionTaskIDs.contains($0.id) }
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

    private static var defaultCollectionPreamble: String {
        streamlitDefault.collectionPreamble
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
}

extension PromptConfig {
    func normalized() -> PromptConfig {
        var seen = Set<String>()
        let cleaned = tasks.filter {
            guard !$0.id.isEmpty, !seen.contains($0.id) else { return false }
            seen.insert($0.id)
            return true
        }.map { task in
            guard PromptConfig.collectionTaskIDs.contains(task.id),
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
                (task.id == "task4" && !task.template.contains("STRICT OUTPUT CONTRACT")) ||
                task.template.contains("Task 5 – Universal Content Architect") ||
                (task.id == "task5" && !task.template.contains("Bilingual Chinese Dictionary Editor")) {
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
                PromptConfig.collectionTaskIDs.contains(defaultTask.id) &&
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
            if selected == ["task5"] {
                full = cfg.collectionPreamble + body
            } else {
                full = cfg.collectionPreamble + body + cfg.collectionEpilogue
            }
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
    }
}
