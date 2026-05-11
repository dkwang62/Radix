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
        For each Chinese phrase below, provide pinyin with tone marks and a concise English meaning.

        Output only in this format:
        Phrase | Pinyin | Concise English meaning

        Phrases:
        \(phraseList)

        Important:
        - Preserve each phrase exactly as written.
        - Do not add phrases that are not in the list.
        - Do not include headings, numbering, bullets, markdown tables, or explanations.
        - If a phrase is invalid or not a real phrase, omit it.
        """
    }

    private static func makeChatGPTPhraseDiscoveryPrompt(rawText: String, knownPhrases: [String]) -> String {
        let knownList = knownPhrases.isEmpty ? "(none)" : knownPhrases.joined(separator: "\n")

        return """
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
        - Output only in this format:
        Phrase | Pinyin | Concise English meaning

        Chinese text:
        \(rawText)

        Important:
        - Do not delete or shorten the OCR text.
        - Do not analyze one character at a time unless explicitly asked.
        - The known phrase list is for ignoring existing phrases, not for removing context.
        """
    }
}
