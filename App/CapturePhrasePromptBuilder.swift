import Foundation

enum CapturePhrasePromptBuilder {
    static func makePrompt(
        source: PhraseParserSource,
        parserInputPhrases: [String],
        rawText: String,
        knownPhrases: [String]
    ) -> String {
        switch source {
        case .appleCandidates:
            return makeApplePhraseParserPrompt(phrases: parserInputPhrases)
        case .chatGPTDerived:
            return makeChatGPTPhraseDiscoveryPrompt(rawText: rawText, knownPhrases: knownPhrases)
        }
    }

    private static func makeApplePhraseParserPrompt(phrases: [String]) -> String {
        let phraseList = phrases.joined(separator: "\n")

        return """
        You are producing data for an automatic parser. Follow the output contract exactly.

        For each valid Chinese phrase below, provide pinyin with tone marks and one concise English meaning.

        STRICT OUTPUT CONTRACT:
        - Output records only. No introduction, no conclusion, no explanation.
        - Do not output a header row.
        - Do not use Markdown tables, bullets, numbering, code blocks, or labels.
        - Every non-empty output line must contain exactly one phrase record.
        - Every record must contain exactly 3 fields separated by exactly 2 pipe characters.
        - Field order must be: Chinese phrase | pinyin with tone marks | concise English meaning
        - Preserve each Chinese phrase exactly as written in the input.
        - Do not add phrases that are not in the input list.
        - If a phrase is invalid or not a real phrase, omit it.
        - Do not put pipe characters inside the English meaning.

        VALID OUTPUT EXAMPLE:
        人工智能 | rén gōng zhì néng | artificial intelligence
        国际关系 | guó jì guān xì | international relations

        INVALID OUTPUT EXAMPLES:
        Phrase | Pinyin | Meaning
        | Phrase | Pinyin | Meaning |
        1. 人工智能 | rén gōng zhì néng | artificial intelligence

        Phrases:
        \(phraseList)

        Before answering, silently verify that every non-empty line has exactly this structure:
        Chinese phrase | pinyin | meaning
        """
    }

    private static func makeChatGPTPhraseDiscoveryPrompt(rawText: String, knownPhrases: [String]) -> String {
        let knownList = knownPhrases.isEmpty ? "(none)" : knownPhrases.joined(separator: "\n")

        return """
        You are producing data for an automatic parser. Follow the output contract exactly.

        From the Chinese text below, extract useful 2-, 3-, and 4-character Chinese phrases that are found as dictionary headwords.

        Ignore phrases already in this known list:
        \(knownList)

        Rules:
        - Keep the full text context in mind.
        - Return only useful NEW phrase candidates that are attested in Chinese dictionaries.
        - Only include a phrase if it would normally appear as an entry in a reputable dictionary such as CC-CEDICT, Pleco, MDBG, Wiktionary, or a standard Chinese dictionary.
        - Prioritize common, natural dictionary phrases.
        - Avoid rare, awkward, or accidental character combinations.
        - Avoid arbitrary n-grams, sentence fragments, partial grammar patterns, names, titles, dates, and OCR accidents unless they are also normal dictionary entries.
        - Do not invent phrases that are not clearly supported by the text.
        - If you are unsure whether a phrase is dictionary-attested, omit it.
        - Include only 2-, 3-, and 4-character Chinese phrases.
        - Provide pinyin with tone marks.
        - Provide a concise English meaning.

        STRICT OUTPUT CONTRACT:
        - Output records only. No introduction, no conclusion, no explanation.
        - Do not output a header row.
        - Do not use Markdown tables, bullets, numbering, code blocks, or labels.
        - Every non-empty output line must contain exactly one phrase record.
        - Every record must contain exactly 3 fields separated by exactly 2 pipe characters.
        - Field order must be: Chinese phrase | pinyin with tone marks | concise English meaning
        - Do not put pipe characters inside the English meaning.

        VALID OUTPUT EXAMPLE:
        人工智能 | rén gōng zhì néng | artificial intelligence
        国际关系 | guó jì guān xì | international relations

        INVALID OUTPUT EXAMPLES:
        Phrase | Pinyin | Meaning
        | Phrase | Pinyin | Meaning |
        1. 人工智能 | rén gōng zhì néng | artificial intelligence

        Chinese text:
        \(rawText)

        Important:
        - Do not delete or shorten the OCR text.
        - Do not analyze one character at a time unless explicitly asked.
        - The known phrase list is for ignoring existing phrases, not for removing context.
        - Before answering, silently verify that every non-empty line has exactly this structure:
          Chinese phrase | pinyin | meaning
        """
    }
}
