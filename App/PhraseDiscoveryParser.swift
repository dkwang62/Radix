import Foundation

enum PhraseDiscoveryParser {
    static func parse(_ text: String) -> PhraseDiscoveryParseResult {
        if let jsonResult = parseJSON(text) {
            return jsonResult
        }

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

    private static func parseJSON(_ text: String) -> PhraseDiscoveryParseResult? {
        guard let root = decodeJSONObject(from: text) else { return nil }
        guard let rawRecords = phraseRecords(in: root) else { return nil }

        var candidates: [PhraseDiscoveryCandidate] = []
        var seen = Set<String>()
        var totalParsed = 0
        var duplicatesRemoved = 0
        var invalidLines = 0

        for record in rawRecords {
            guard let candidate = candidate(from: record) else {
                invalidLines += 1
                continue
            }
            totalParsed += 1
            guard seen.insert(candidate.phrase).inserted else {
                duplicatesRemoved += 1
                continue
            }
            candidates.append(candidate)
        }

        return PhraseDiscoveryParseResult(
            candidates: candidates,
            totalParsed: totalParsed,
            duplicatesRemoved: duplicatesRemoved,
            invalidLines: invalidLines
        )
    }

    private static func decodeJSONObject(from text: String) -> Any? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        for candidate in jsonTextCandidates(from: trimmed) {
            guard let data = candidate.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) else {
                continue
            }
            return object
        }
        return nil
    }

    private static func jsonTextCandidates(from text: String) -> [String] {
        var candidates = [text]

        if text.hasPrefix("```") {
            let lines = text.components(separatedBy: .newlines)
            if lines.count >= 3, lines.last?.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("```") == true {
                candidates.append(lines.dropFirst().dropLast().joined(separator: "\n"))
            }
        }

        if let objectStart = text.firstIndex(of: "{"),
           let objectEnd = text.lastIndex(of: "}"),
           objectStart < objectEnd {
            candidates.append(String(text[objectStart...objectEnd]))
        }

        if let arrayStart = text.firstIndex(of: "["),
           let arrayEnd = text.lastIndex(of: "]"),
           arrayStart < arrayEnd {
            candidates.append(String(text[arrayStart...arrayEnd]))
        }

        var seen = Set<String>()
        return candidates
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    private static func phraseRecords(in value: Any) -> [[String: Any]]? {
        if let records = value as? [[String: Any]] {
            return records
        }

        guard let object = value as? [String: Any] else { return nil }

        if let records = object["phrases"] as? [[String: Any]] {
            return records
        }
        if let records = object["items"] as? [[String: Any]] {
            return records
        }
        if let records = object["results"] as? [[String: Any]] {
            return records
        }

        if let text = geminiResponseText(in: object),
           let nested = decodeJSONObject(from: text) {
            return phraseRecords(in: nested)
        }

        return nil
    }

    private static func geminiResponseText(in object: [String: Any]) -> String? {
        guard let candidates = object["candidates"] as? [[String: Any]] else { return nil }
        for candidate in candidates {
            guard let content = candidate["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]] else { continue }
            for part in parts {
                if let text = part["text"] as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return text
                }
            }
        }
        return nil
    }

    private static func candidate(from record: [String: Any]) -> PhraseDiscoveryCandidate? {
        let phrase = firstString(in: record, keys: ["phrase", "word", "chinese", "hanzi", "term"])
            .map(cleanPhrase) ?? ""
        guard isValidPhrase(phrase) else { return nil }

        let pinyin = firstString(in: record, keys: ["pinyin", "pronunciation", "reading"])
            .map(cleanLabeledValue) ?? ""
        let meaning = firstString(in: record, keys: ["meaning", "english", "definition", "gloss"])
            .map(cleanLabeledValue) ?? ""

        return PhraseDiscoveryCandidate(phrase: phrase, pinyin: pinyin, meaning: meaning)
    }

    private static func firstString(in record: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = record[key] as? String {
                return value
            }
        }
        return nil
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
