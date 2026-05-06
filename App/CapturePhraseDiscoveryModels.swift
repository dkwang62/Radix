import Foundation

struct PhraseDiscoveryCandidate: Identifiable, Hashable {
    let id = UUID()
    var phrase: String
    var pinyin: String
    var meaning: String
    var isSelected = true
}

struct PhraseDiscoveryPreparedCandidate {
    var candidate: PhraseDiscoveryCandidate
    var phrase: String
}

struct PhraseDiscoveryImportPreparation {
    var candidates: [PhraseDiscoveryPreparedCandidate]
    var skippedCount: Int
}

enum PhraseDiscoveryCandidateTools {
    static func selectingAll(_ candidates: [PhraseDiscoveryCandidate], isSelected: Bool) -> [PhraseDiscoveryCandidate] {
        candidates.map { candidate in
            var candidate = candidate
            candidate.isSelected = isSelected
            return candidate
        }
    }

    static func deselecting(_ candidates: [PhraseDiscoveryCandidate], ids: Set<UUID>) -> [PhraseDiscoveryCandidate] {
        candidates.map { candidate in
            var candidate = candidate
            if ids.contains(candidate.id) {
                candidate.isSelected = false
            }
            return candidate
        }
    }

    static func mergingAddedResults(
        _ current: [PhraseDiscoveryCandidate],
        _ newItems: [PhraseDiscoveryCandidate]
    ) -> [PhraseDiscoveryCandidate] {
        var seen = Set<String>()
        var merged: [PhraseDiscoveryCandidate] = []
        for candidate in newItems + current {
            let phrase = candidate.phrase.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !phrase.isEmpty, seen.insert(phrase).inserted else { continue }
            merged.append(candidate)
        }
        return merged
    }

    static func preparingForImport(_ candidates: [PhraseDiscoveryCandidate]) -> PhraseDiscoveryImportPreparation {
        var prepared: [PhraseDiscoveryPreparedCandidate] = []
        var skipped = 0
        var seen = Set<String>()

        for candidate in candidates {
            let phrase = candidate.phrase.trimmingCharacters(in: .whitespacesAndNewlines)
            guard PhraseDiscoveryParser.isValidPhrase(phrase), seen.insert(phrase).inserted else {
                skipped += 1
                continue
            }
            prepared.append(PhraseDiscoveryPreparedCandidate(candidate: candidate, phrase: phrase))
        }

        return PhraseDiscoveryImportPreparation(candidates: prepared, skippedCount: skipped)
    }
}

struct PhraseDiscoveryImportSummary {
    var selectedCount: Int
    var addedCount: Int
    var skippedCount: Int
    var errors: [String]

    func message(defaultAIName: String) -> String {
        if selectedCount == 0 {
            return "No new phrases were found in the \(defaultAIName) answer."
        }
        if addedCount == 0 {
            return "Radix read \(selectedCount) phrase\(selectedCount == 1 ? "" : "s"), but none were added to My Phrases. Skipped \(skippedCount).\(errorSuffix)"
        }
        return "Added or updated \(addedCount) in My Phrases. Delete any phrase below that you do not want to keep.\(skippedCount == 0 ? "" : " Skipped \(skippedCount).")\(errorSuffix)"
    }

    private var errorSuffix: String {
        errors.isEmpty ? "" : " Errors: \(errors.joined(separator: "; "))"
    }
}

enum CapturePhrasePromptLaunchMessage {
    static func opening(defaultAIName: String, prefillsPrompt: Bool) -> String {
        prefillsPrompt
            ? "Opening \(defaultAIName) in 3 seconds. Copy its answer, then come back and tap Add Phrases."
            : "Opening \(defaultAIName) in 3 seconds. The prompt was copied, so paste it into \(defaultAIName), then come back and tap Add Phrases."
    }
}

enum CaptureStatusText {
    static let noChineseCharactersFound = "No Chinese characters found. You can edit the fields manually."
    static let noChineseCharactersToRead = "No Chinese characters to read."
    static let clipboardIsEmpty = "Clipboard is empty."

    static func savedCollection(name: String, characterCount: Int) -> String {
        "Saved \(name) with \(characterCount) characters."
    }

    static func readingCharacters(count: Int) -> String {
        "Reading \(count) character\(count == 1 ? "" : "s") aloud."
    }

    static func removedPhrase(_ phrase: String) -> String {
        "Removed \(phrase) from My Phrases."
    }
}

enum PhraseDiscoveryPreviewMessage {
    static func message(candidateCount: Int) -> String {
        candidateCount == 0
            ? "Radix could not read any phrases from that answer."
            : "Radix found \(candidateCount) phrase\(candidateCount == 1 ? "" : "s"). You can edit the list, then tap Add Selected to My Phrases."
    }
}

enum CaptureBrowseTargetResolver {
    static func targetID(
        lastSavedCollectionID: UUID?,
        selectedBrowseCollectionID: UUID?,
        collections: [CharacterCollection]
    ) -> UUID? {
        lastSavedCollectionID ?? selectedBrowseCollectionID ?? collections.first?.id
    }
}

enum CaptureCollectionName {
    static func ocrImageName(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ddMMyy HHmm"
        return formatter.string(from: date)
    }

    static func pastedName(_ name: String, date: Date = Date()) -> String {
        name.isEmpty ? "Pasted \(date.formatted(date: .numeric, time: .shortened))" : name
    }
}

struct CaptureWorkflowStep: Identifiable {
    var id: String { title }
    let title: String
    let detail: String
    let isComplete: Bool
    let systemImage: String
}

enum CaptureWorkflowStepBuilder {
    static func makeSteps(
        parserSource: PhraseParserSource,
        defaultAIName: String,
        promptCopied: Bool,
        output: String,
        importedCount: Int,
        candidateCount: Int
    ) -> [CaptureWorkflowStep] {
        let outputIsEmpty = output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return [
            CaptureWorkflowStep(
                title: "Choose",
                detail: parserSource.shortTitle,
                isComplete: true,
                systemImage: "checkmark.circle"
            ),
            CaptureWorkflowStep(
                title: "Copy",
                detail: promptCopied ? "Prompt copied" : "Open \(defaultAIName)",
                isComplete: promptCopied,
                systemImage: "doc.on.doc"
            ),
            CaptureWorkflowStep(
                title: "Paste",
                detail: outputIsEmpty ? "\(defaultAIName) answer" : "Answer pasted",
                isComplete: !outputIsEmpty,
                systemImage: "doc.on.clipboard"
            ),
            CaptureWorkflowStep(
                title: "Add",
                detail: importedCount == 0 ? "To My Phrases" : "\(importedCount) added",
                isComplete: importedCount > 0,
                systemImage: "plus.circle"
            ),
            CaptureWorkflowStep(
                title: "Check",
                detail: candidateCount == 0 ? "No list yet" : "\(candidateCount) shown",
                isComplete: candidateCount > 0,
                systemImage: "checklist"
            )
        ]
    }
}

enum CapturePhraseMode: Equatable {
    case apple
    case parser
}

enum PhraseParserSource: Equatable {
    case appleCandidates
    case chatGPTDerived

    var title: String {
        switch self {
        case .appleCandidates:
            return "Add Apple Candidates to My Phrases"
        case .chatGPTDerived:
            return "Add AI Suggestions to My Phrases"
        }
    }

    var shortTitle: String {
        switch self {
        case .appleCandidates:
            return "Apple candidates"
        case .chatGPTDerived:
            return "More phrases"
        }
    }

    func guidanceTitle(defaultAIName: String) -> String {
        switch self {
        case .appleCandidates:
            return "You chose Apple-derived phrases."
        case .chatGPTDerived:
            return "You chose \(defaultAIName) suggestions."
        }
    }

    func guidanceDetail(count: Int, defaultAIName: String) -> String {
        switch self {
        case .appleCandidates:
            let phraseText = count == 1 ? "1 phrase" : "\(count) phrases"
            return "Radix copies \(phraseText) to \(defaultAIName) so it can add pinyin and meaning. Copy \(defaultAIName)'s answer, then tap Paste \(defaultAIName) Answer and Add."
        case .chatGPTDerived:
            return "Radix copies the OCR text to \(defaultAIName) so it can find more phrases with pinyin and meaning. Copy \(defaultAIName)'s answer, then tap Paste \(defaultAIName) Answer and Add."
        }
    }
}

struct PhraseDiscoveryStats {
    var totalParsed = 0
    var duplicatesRemoved = 0
    var alreadyExisting = 0
    var invalidLines = 0
}

struct PhraseDiscoveryReadResult {
    var candidates: [PhraseDiscoveryCandidate]
    var stats: PhraseDiscoveryStats
}

enum PhraseDiscoveryReader {
    static func read(_ text: String, existingWords: Set<String>) -> PhraseDiscoveryReadResult {
        read(PhraseDiscoveryParser.parse(text), existingWords: existingWords)
    }

    static func read(_ parsed: PhraseDiscoveryParseResult, existingWords: Set<String>) -> PhraseDiscoveryReadResult {
        let candidates = PhraseDiscoveryCandidateTools.selectingAll(parsed.candidates, isSelected: true)
        let stats = PhraseDiscoveryStats(
            totalParsed: parsed.totalParsed,
            duplicatesRemoved: parsed.duplicatesRemoved,
            alreadyExisting: existingWords.count,
            invalidLines: parsed.invalidLines
        )

        return PhraseDiscoveryReadResult(candidates: candidates, stats: stats)
    }
}

struct PhraseDiscoveryParseResult {
    var candidates: [PhraseDiscoveryCandidate]
    var totalParsed: Int
    var duplicatesRemoved: Int
    var invalidLines: Int
}

enum PhraseDiscoveryParser {
    static func parse(_ text: String) -> PhraseDiscoveryParseResult {
        var candidates: [PhraseDiscoveryCandidate] = []
        var seen = Set<String>()
        var totalParsed = 0
        var duplicatesRemoved = 0
        var invalidLines = 0

        for rawLine in text.components(separatedBy: .newlines) {
            guard let row = parseLine(rawLine) else {
                if !isIgnorableLine(rawLine) {
                    invalidLines += 1
                }
                continue
            }

            totalParsed += 1
            guard seen.insert(row.phrase).inserted else {
                duplicatesRemoved += 1
                continue
            }
            candidates.append(row)
        }

        return PhraseDiscoveryParseResult(
            candidates: candidates,
            totalParsed: totalParsed,
            duplicatesRemoved: duplicatesRemoved,
            invalidLines: invalidLines
        )
    }

    static func isValidPhrase(_ phrase: String) -> Bool {
        let trimmed = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...12).contains(trimmed.count) else { return false }
        return trimmed.allSatisfy { character in
            character.unicodeScalars.contains {
                (0x3400...0x4DBF).contains($0.value)
                || (0x4E00...0x9FFF).contains($0.value)
                || (0x20000...0x2EBEF).contains($0.value)
            }
        }
    }

    private static func parseLine(_ rawLine: String) -> PhraseDiscoveryCandidate? {
        let line = cleanedLine(rawLine)
        guard !line.isEmpty, !isMarkdownSeparator(line) else { return nil }

        let parts: [String]
        if line.contains("|") {
            parts = line
                .split(separator: "|", omittingEmptySubsequences: false)
                .map { cleanCell(String($0)) }
        } else if line.contains("\t") {
            parts = line
                .split(separator: "\t", omittingEmptySubsequences: false)
                .map { cleanCell(String($0)) }
        } else {
            parts = splitLooseLine(line)
        }

        guard !isHeaderRow(parts) else { return nil }
        guard let first = parts.first else { return nil }
        let phrase = cleanPhrase(first)
        guard isValidPhrase(phrase) else { return nil }

        let pinyin = parts.indices.contains(1) ? cleanLabeledValue(parts[1]) : ""
        let meaning = parts.indices.contains(2)
            ? parts[2...].map(cleanLabeledValue).filter { !$0.isEmpty }.joined(separator: " | ")
            : ""

        return PhraseDiscoveryCandidate(phrase: phrase, pinyin: pinyin, meaning: meaning)
    }

    private static func cleanedLine(_ rawLine: String) -> String {
        var line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        while line.hasPrefix("|") { line.removeFirst() }
        while line.hasSuffix("|") { line.removeLast() }
        line = line.trimmingCharacters(in: .whitespacesAndNewlines)
        line = line.replacingOccurrences(
            of: #"^\s*(?:[-*•]\s+|\d+[.)]\s*)"#,
            with: "",
            options: .regularExpression
        )
        return line.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func cleanCell(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "`")))
    }

    private static func cleanPhrase(_ value: String) -> String {
        let cleaned = cleanLabeledValue(value)
            .trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.symbols))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if isValidPhrase(cleaned) {
            return cleaned
        }
        let matches = chineseRuns(in: cleaned)
        return matches.last ?? cleaned
    }

    private static func cleanLabeledValue(_ value: String) -> String {
        cleanCell(value)
            .replacingOccurrences(
                of: #"^\s*(?:phrase|word|pinyin|meaning|english|definition|短语|词语|词|拼音|意思|含义|英文)\s*[:：]\s*"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func chineseRuns(in value: String) -> [String] {
        let pattern = #"[\u{3400}-\u{4DBF}\u{4E00}-\u{9FFF}\u{20000}-\u{2EBEF}]{1,12}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(value.startIndex..<value.endIndex, in: value)
        return regex.matches(in: value, range: nsRange).compactMap { match in
            guard let range = Range(match.range, in: value) else { return nil }
            return String(value[range])
        }
    }

    private static func isHeaderRow(_ parts: [String]) -> Bool {
        let normalized = parts
            .map { cleanCell($0).lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !normalized.isEmpty else { return false }
        let headerWords: Set<String> = [
            "phrase", "word", "pinyin", "meaning", "english", "definition",
            "短语", "词语", "词", "拼音", "意思", "含义", "英文", "英文含义"
        ]
        return normalized.allSatisfy { headerWords.contains($0) }
    }

    private static func isMarkdownSeparator(_ line: String) -> Bool {
        let compact = line.replacingOccurrences(of: "|", with: "")
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return compact.isEmpty
    }

    private static func isIgnorableLine(_ rawLine: String) -> Bool {
        let line = cleanedLine(rawLine)
        guard !line.isEmpty, !isMarkdownSeparator(line) else { return true }
        let hasChinese = line.contains { character in
            character.unicodeScalars.contains {
                (0x3400...0x4DBF).contains($0.value)
                || (0x4E00...0x9FFF).contains($0.value)
                || (0x20000...0x2EBEF).contains($0.value)
            }
        }
        if !hasChinese { return true }
        return false
    }

    private static func splitLooseLine(_ line: String) -> [String] {
        guard let phraseRange = line.range(
            of: #"[\u{3400}-\u{4DBF}\u{4E00}-\u{9FFF}\u{20000}-\u{2EBEF}]{2,4}"#,
            options: .regularExpression
        ) else {
            return []
        }
        let phrase = String(line[phraseRange])
        let rest = line[phraseRange.upperBound...]
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "-–—:：")))
        guard !rest.isEmpty else { return [phrase] }
        return [phrase, "", rest]
    }
}

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
