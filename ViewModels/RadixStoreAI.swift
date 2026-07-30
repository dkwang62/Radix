import Foundation
import CoreGraphics

/*
 RADIX STORE - AI HELPERS
 ========================
 AI task selection for character launch, URL construction for AI presets,
 prompt settings persistence, and Mac clipboard paste automation.
 Extracted from RadixStore Private Utilities.
*/

enum AIResultTaskID {
    static let extractPhrases = "task4"
    static let translatePage = "task5"
    static let checkOCR = "task7"
    static let createQuiz = "task8"
    static let generatePracticePack = "task9"
    static let extractSentences = "task10"
    static let createPagePractice = "task11"
    static let createAICleanedPage = "task12"
    static let sentenceImprovement = "task14"

    static let importableTasks: Set<String> = [
        extractPhrases,
        translatePage,
        checkOCR,
        generatePracticePack,
        extractSentences,
        createPagePractice,
        createAICleanedPage,
        sentenceImprovement
    ]
}

enum AIResultApplicationError: LocalizedError {
    case missingCollection
    case invalidOCRReview
    case emptyCorrectedOCR
    case missingSentence
    case emptyImprovedSentence
    case incompleteSentenceImprovement
    case unsupportedTask

    var errorDescription: String? {
        switch self {
        case .missingCollection:
            return "Choose a saved page first."
        case .invalidOCRReview:
            return "Radix could not read the AI answer. Ask it to keep the required [[CORRECTED TEXT]], [[CHANGES]], and [[UNCERTAIN]] headings."
        case .emptyCorrectedOCR:
            return "The corrected text does not contain a Chinese character recognized by Radix."
        case .missingSentence:
            return "Choose a sentence first."
        case .emptyImprovedSentence:
            return "Paste the improved sentence first."
        case .incompleteSentenceImprovement:
            return "Paste the full sentence improvement answer with sentence, pinyin, and English meaning."
        case .unsupportedTask:
            return "This AI task does not import data back into Radix."
        }
    }
}

enum AIResultApplicationOutcome {
    case phraseExtraction(PhraseDiscoveryImportSummary)
    case translation(CharacterCollection)
    case correctedOCR(CharacterCollection)
    case conversationPractice(ConversationPracticePack)
    case aiCleanedPage(AICleanedPageRecord)
    case sentenceImprovement(SentenceExampleRecord)

    func message(defaultAIName: String) -> String {
        switch self {
        case .phraseExtraction(let summary):
            return summary.message(defaultAIName: defaultAIName)
        case .translation(let collection):
            return "Translation saved to \(collection.name)."
        case .correctedOCR(let collection):
            return "Corrected page created: \(collection.name)."
        case .conversationPractice(let pack):
            return "Imported \(pack.title) - \(pack.entries.count) sentences."
        case .aiCleanedPage(let record):
            return "Extracted sentences saved: \(record.cleanedTitle.isEmpty ? record.sourceTitle : record.cleanedTitle)."
        case .sentenceImprovement:
            return "Sentence updated."
        }
    }
}

extension RadixStore {

    // MARK: - Task selection

    func selectedPromptTaskIDsForCharacterLaunch() -> [String] {
        let normalizedTasks = promptConfig.normalized().tasks
        let availableTaskIDs = Set(normalizedTasks.map(\.id))
        let tasksByID = Dictionary(uniqueKeysWithValues: normalizedTasks.map { ($0.id, $0) })
        let characterTaskIDs = promptSelectedTaskIDs.filter {
            tasksByID[$0]?.subjectType == .characterPhrase
        }
        if !characterTaskIDs.isEmpty { return characterTaskIDs }
        if availableTaskIDs.contains("task1") { return ["task1"] }
        return normalizedTasks
            .map(\.id)
            .filter { tasksByID[$0]?.subjectType == .characterPhrase }
            .prefix(1)
            .map { $0 }
    }

    func runGeminiPhraseExtraction(for collection: CharacterCollection) async throws -> PhraseDiscoveryImportSummary {
        let text = collection.characters.joined()
        let responseText = try await GeminiPhraseExtractionService().extractPhrases(
            apiKey: geminiAPIKey,
            modelID: geminiModelID,
            collectionName: collection.name,
            characters: text,
            knownPhrases: phraseDiscoveryKnownPhrases(in: text)
        )
        return importPhraseDiscoveryResponse(responseText, sourceCollection: collection)
    }

    func importPhraseDiscoveryResponse(_ responseText: String, sourceCollection: CharacterCollection? = nil) -> PhraseDiscoveryImportSummary {
        let parsed = PhraseDiscoveryParser.parse(responseText)
        let candidates = PhraseDiscoveryCandidateTools.selectingAll(parsed.candidates, isSelected: true)
        let prepared = PhraseDiscoveryCandidateTools.preparingForImport(candidates)
        var added = 0
        var addedWords: [String] = []
        let preExistingNonBaseWords = prepared.candidates
            .map(\.phrase)
            .filter { !isPhraseInBase($0) && isPhraseInAdd($0) }
        var skippedExisting = 0
        var errors: [String] = []

        for item in prepared.candidates {
            do {
                let wasAdded = try addAIPastedPhraseIfNew(
                    word: item.phrase,
                    pinyin: item.candidate.pinyin,
                    meanings: item.candidate.meaning,
                    refreshViews: false
                )
                if wasAdded {
                    added += 1
                    addedWords.append(item.phrase)
                } else {
                    skippedExisting += 1
                }
            } catch {
                errors.append("\(item.phrase): \(error.localizedDescription)")
            }
        }

        refreshPhraseOverlayViews()
        let linkedPhraseWords = PagePhraseExtractionRecord.deduplicated(preExistingNonBaseWords + addedWords)
        if let sourceCollection, !linkedPhraseWords.isEmpty {
            RadixStudyPreferences.recordPagePhraseExtraction(
                pageID: sourceCollection.id,
                title: sourceCollection.name,
                words: linkedPhraseWords
            )
        }
        return PhraseDiscoveryImportSummary(
            selectedCount: candidates.count,
            addedCount: added,
            addedWords: addedWords,
            skippedCount: prepared.skippedCount + skippedExisting,
            skippedExistingCount: skippedExisting,
            errors: errors
        )
    }

    func supportsAIResultImport(taskID: String) -> Bool {
        AIResultTaskID.importableTasks.contains(taskID)
    }

    @discardableResult
    func applySentenceImprovement(
        fromAIResponse responseText: String,
        to item: ConversationPracticeItem
    ) throws -> SentenceExampleRecord {
        let improvement = try parsedSentenceImprovementResponse(responseText)
        guard !improvement.sentence.isEmpty else {
            throw AIResultApplicationError.emptyImprovedSentence
        }
        guard !improvement.pinyin.isEmpty, !improvement.english.isEmpty else {
            throw AIResultApplicationError.incompleteSentenceImprovement
        }

        var record = sentenceExample(for: item) ?? SentenceExampleRecord.fromPracticeItem(item, pack: nil)
        record.chinese = ScriptTextConverter.simplified(improvement.sentence)
        record.pinyin = improvement.pinyin
        record.english = improvement.english
        record.targetCharacters = SentenceExampleRecord.detectChineseCharacters(in: record.chinese)
        record.detectedCharacters = record.targetCharacters
        record.targetPhrases = retainedPhraseHints(record.targetPhrases, in: record.chinese)
        record.detectedPhrases = retainedPhraseHints(record.detectedPhrases, in: record.chinese)
        RadixStudyPreferences.replaceSentenceExample(record)
        favoriteSentenceRevision += 1
        return record
    }

    private struct SentenceImprovementPayload {
        var sentence: String
        var pinyin: String
        var english: String
    }

    private func parsedSentenceImprovementResponse(_ responseText: String) throws -> SentenceImprovementPayload {
        let cleaned = cleanedAIResponseText(responseText)
        guard !cleaned.isEmpty else {
            throw AIResultApplicationError.emptyImprovedSentence
        }
        if let payload = decodedSentenceImprovementPayload(from: cleaned) {
            return payload
        }
        if let payload = labeledSentenceImprovementPayload(from: cleaned) {
            return payload
        }
        throw AIResultApplicationError.incompleteSentenceImprovement
    }

    private func cleanedAIResponseText(_ responseText: String) -> String {
        var cleaned = responseText.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            var lines = cleaned.split(whereSeparator: \.isNewline).map(String.init)
            if !lines.isEmpty {
                lines.removeFirst()
            }
            if let last = lines.last,
               last.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("```") {
                lines.removeLast()
            }
            cleaned = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return cleaned
    }

    private func decodedSentenceImprovementPayload(from responseText: String) -> SentenceImprovementPayload? {
        guard
            let jsonText = jsonObjectSubstring(in: responseText),
            let data = jsonText.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return sentenceImprovementPayload(from: object)
    }

    private func jsonObjectSubstring(in text: String) -> String? {
        guard let firstBrace = text.firstIndex(of: "{"),
              let lastBrace = text.lastIndex(of: "}"),
              firstBrace <= lastBrace else { return nil }
        return String(text[firstBrace...lastBrace])
    }

    private func sentenceImprovementPayload(from object: [String: Any]) -> SentenceImprovementPayload? {
        let sentence = firstString(
            in: object,
            keys: ["sentence", "improved_sentence", "improvedSentence", "chinese", "zh", "text"]
        )
        let pinyin = firstString(in: object, keys: ["pinyin", "pin_yin", "romanization"])
        let english = firstString(in: object, keys: ["english", "en", "meaning", "translation"])
        return normalizedSentenceImprovementPayload(sentence: sentence, pinyin: pinyin, english: english)
    }

    private func firstString(in object: [String: Any], keys: [String]) -> String {
        for key in keys {
            if let value = object[key] as? String {
                return value.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let nested = object[key] as? [String: Any] {
                let nestedValue = firstString(in: nested, keys: keys)
                if !nestedValue.isEmpty { return nestedValue }
            }
        }
        return ""
    }

    private func labeledSentenceImprovementPayload(from responseText: String) -> SentenceImprovementPayload? {
        let labels: [(field: String, keys: [String])] = [
            ("sentence", ["sentence", "improved sentence", "chinese", "zh", "句子", "中文"]),
            ("pinyin", ["pinyin", "pin yin", "拼音"]),
            ("english", ["english", "meaning", "translation", "英文", "意思"])
        ]
        var values: [String: String] = [:]
        for line in responseText.split(whereSeparator: \.isNewline) {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let separatorIndex = trimmedLine.firstIndex(where: { $0 == ":" || $0 == "：" }) else {
                continue
            }
            let rawLabel = String(trimmedLine[..<separatorIndex])
                .lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let value = String(trimmedLine[trimmedLine.index(after: separatorIndex)...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { continue }
            for label in labels where label.keys.contains(rawLabel) {
                values[label.field] = value
            }
        }
        return normalizedSentenceImprovementPayload(
            sentence: values["sentence"] ?? "",
            pinyin: values["pinyin"] ?? "",
            english: values["english"] ?? ""
        )
    }

    private func normalizedSentenceImprovementPayload(
        sentence: String,
        pinyin: String,
        english: String
    ) -> SentenceImprovementPayload? {
        let trimmedSentence = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPinyin = pinyin.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEnglish = english.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSentence.isEmpty || !trimmedPinyin.isEmpty || !trimmedEnglish.isEmpty else {
            return nil
        }
        return SentenceImprovementPayload(
            sentence: trimmedSentence,
            pinyin: trimmedPinyin,
            english: trimmedEnglish
        )
    }

    private func retainedPhraseHints(_ hints: [String], in sentence: String) -> [String] {
        let sentenceKey = SentenceExampleRecord.normalizedChineseKey(sentence)
        return hints.filter {
            let key = SentenceExampleRecord.normalizedChineseKey(ScriptTextConverter.simplified($0))
            return !key.isEmpty && sentenceKey.contains(key)
        }
    }

    func createCorrectedOCRCollection(fromAIResponse responseText: String, original collection: CharacterCollection) throws -> CharacterCollection {
        guard let proposal = OCRReviewParser.parse(responseText) else {
            throw AIResultApplicationError.invalidOCRReview
        }
        guard let corrected = createCorrectedOCRCollection(
            from: collection.id,
            correctedText: proposal.correctedText
        ) else {
            throw AIResultApplicationError.emptyCorrectedOCR
        }
        return corrected
    }

    @discardableResult
    func saveTranslationReport(fromAIResponse responseText: String, for collection: CharacterCollection) -> CharacterCollection {
        updateCollectionTranslationReport(id: collection.id, report: responseText)
        return self.collection(id: collection.id) ?? collection
    }

    @discardableResult
    func importConversationPracticePack(
        fromAIResponse responseText: String,
        sourceName: String,
        sourceCollection: CharacterCollection? = nil
    ) throws -> ConversationPracticePack {
        var pack = try ConversationPracticeService().loadPack(
            fromPastedText: responseText,
            sourceName: sourceName
        )
        if let sourceCollection {
            pack = pack.withSourceLink(conversationPracticeSourceLink(for: sourceCollection))
        }
        saveImportedConversationPracticePack(pack)
        selectedConversationPracticeTopicID = pack.packID
        persistPromptSettings()
        return pack
    }

    @discardableResult
    func importAICleanedPage(
        fromAIResponse responseText: String,
        for collection: CharacterCollection
    ) throws -> AICleanedPageRecord {
        let record = try AICleanedPageImportParser.parse(
            responseText,
            sourcePageID: collection.id,
            sourceTitle: collection.name
        )
        let preprocessed = preprocessedAICleanedPage(record)
        RadixStudyPreferences.recordAICleanedPage(preprocessed)
        return preprocessed
    }

    func preprocessedAICleanedPage(_ record: AICleanedPageRecord) -> AICleanedPageRecord {
        var updated = record
        updated.sentences = record.sentences.map(preprocessedAICleanedPageSentence(_:))
        return updated
    }

    func preprocessedAICleanedPages(_ records: [AICleanedPageRecord]?) -> [AICleanedPageRecord]? {
        records?.map(preprocessedAICleanedPage(_:))
    }

    func preprocessStoredAICleanedPagesIfNeeded() {
        let records = RadixStudyPreferences.aiCleanedPages
        guard !records.isEmpty else { return }
        let updated = records.map(preprocessedAICleanedPage(_:))
        guard updated != records else { return }
        RadixStudyPreferences.aiCleanedPages = updated
        RadixStudyPreferences.recordSentenceExamples(updated.flatMap(SentenceExampleRecord.fromAICleanedPage(_:)))
    }

    private func preprocessedAICleanedPageSentence(_ sentence: AICleanedPageSentence) -> AICleanedPageSentence {
        let discovered = phraseDiscoveryKnownPhraseItems(in: sentence.chinese).map(\.word)
        let mergedHints = mergedPreprocessedPhraseHints(primary: discovered, secondary: sentence.phraseHints)
        guard mergedHints != sentence.phraseHints else { return sentence }
        var updated = sentence
        updated.phraseHints = mergedHints
        return updated
    }

    private func mergedPreprocessedPhraseHints(primary: [String], secondary: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for phrase in primary + secondary {
            let key = phraseStorageWord(phrase)
            guard !key.isEmpty, seen.insert(key).inserted else { continue }
            result.append(key)
        }
        return result
    }

    func applyAIResult(
        taskID: String,
        responseText: String,
        collection: CharacterCollection?,
        sentence: ConversationPracticeItem?,
        sourceName: String
    ) throws -> AIResultApplicationOutcome {
        switch taskID {
        case AIResultTaskID.extractPhrases:
            return .phraseExtraction(importPhraseDiscoveryResponse(responseText, sourceCollection: collection))
        case AIResultTaskID.translatePage:
            guard let collection else { throw AIResultApplicationError.missingCollection }
            return .translation(saveTranslationReport(fromAIResponse: responseText, for: collection))
        case AIResultTaskID.checkOCR:
            guard let collection else { throw AIResultApplicationError.missingCollection }
            return .correctedOCR(try createCorrectedOCRCollection(fromAIResponse: responseText, original: collection))
        case AIResultTaskID.generatePracticePack:
            return .conversationPractice(try importConversationPracticePack(fromAIResponse: responseText, sourceName: sourceName))
        case AIResultTaskID.extractSentences, AIResultTaskID.createPagePractice:
            guard let collection else { throw AIResultApplicationError.missingCollection }
            return .conversationPractice(try importConversationPracticePack(
                fromAIResponse: responseText,
                sourceName: sourceName,
                sourceCollection: collection
            ))
        case AIResultTaskID.createAICleanedPage:
            guard let collection else { throw AIResultApplicationError.missingCollection }
            return .aiCleanedPage(try importAICleanedPage(fromAIResponse: responseText, for: collection))
        case AIResultTaskID.sentenceImprovement:
            guard let sentence else { throw AIResultApplicationError.missingSentence }
            return .sentenceImprovement(try applySentenceImprovement(fromAIResponse: responseText, to: sentence))
        default:
            throw AIResultApplicationError.unsupportedTask
        }
    }

    func runGeminiTranslationReport(for collection: CharacterCollection) async throws -> String {
        let prompt = promptText(for: .collection(collection), selectedTaskIDs: ["task5"])
        let report = try await GeminiTextGenerationService().generateText(
            apiKey: geminiAPIKey,
            modelID: geminiModelID,
            prompt: prompt,
            systemInstruction: """
            You are an expert bilingual Chinese editor and translator. Return a polished translation only, with no preface about being an AI and no follow-up questions.
            """
        )
        saveTranslationReport(fromAIResponse: report, for: collection)
        return report
    }

    func runGeminiPageSentenceExtraction(for collection: CharacterCollection) async throws -> ConversationPracticePack {
        let prompt = promptText(for: .collection(collection), selectedTaskIDs: ["task10"])
        let response = try await GeminiTextGenerationService().generateText(
            apiKey: geminiAPIKey,
            modelID: geminiModelID,
            prompt: prompt,
            systemInstruction: """
            You create validated JSON import packs for a Chinese learning app. Return valid JSON only, with no Markdown and no explanatory text.
            """
        )
        return try importConversationPracticePack(
            fromAIResponse: response,
            sourceName: collection.name,
            sourceCollection: collection
        )
    }

    func runGeminiPagePracticeGeneration(for collection: CharacterCollection) async throws -> ConversationPracticePack {
        let prompt = promptText(for: .collection(collection), selectedTaskIDs: [AIResultTaskID.createPagePractice])
        let response = try await GeminiTextGenerationService().generateText(
            apiKey: geminiAPIKey,
            modelID: geminiModelID,
            prompt: prompt,
            systemInstruction: """
            You create validated JSON import packs for a Chinese learning app. Return valid JSON only, with no Markdown and no explanatory text.
            """
        )
        return try importConversationPracticePack(
            fromAIResponse: response,
            sourceName: collection.name,
            sourceCollection: collection
        )
    }

    func runGeminiAICleanedPage(for collection: CharacterCollection) async throws -> AICleanedPageRecord {
        let prompt = promptText(for: .collection(collection), selectedTaskIDs: [AIResultTaskID.createAICleanedPage])
        let response = try await GeminiTextGenerationService().generateText(
            apiKey: geminiAPIKey,
            modelID: geminiModelID,
            prompt: prompt,
            systemInstruction: """
            You create structured JSON for Radix. Return valid JSON only, without Markdown fences or commentary.
            """
        )
        return try importAICleanedPage(fromAIResponse: response, for: collection)
    }

    func runGeminiOCRReview(for collection: CharacterCollection) async throws -> String {
        try await GeminiTextGenerationService().generateText(
            apiKey: geminiAPIKey,
            modelID: geminiModelID,
            prompt: ocrReviewPrompt(for: collection),
            systemInstruction: """
            You are a meticulous Chinese OCR editor. Follow the requested output headings exactly. Preserve Chinese source text, write all explanations in English, and clearly mark uncertainty.
            """,
            imageJPEGData: collection.sourceImageJPEGData ?? collection.thumbnailJPEGData
        )
    }

    // MARK: - Mac clipboard paste

    func scheduleMacClipboardPasteIfPossible() {
        #if targetEnvironment(macCatalyst)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.performMacPasteShortcut()
        }
        #endif
    }

    #if targetEnvironment(macCatalyst)
    func performMacPasteShortcut() {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let commandDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true),
              let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
              let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false),
              let commandUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false) else {
            return
        }
        vDown.flags = .maskCommand
        vUp.flags = .maskCommand
        commandDown.post(tap: .cghidEventTap)
        vDown.post(tap: .cghidEventTap)
        vUp.post(tap: .cghidEventTap)
        commandUp.post(tap: .cghidEventTap)
    }
    #endif

    // MARK: - AI preset name / URL helpers

    var defaultAIName: String { aiName(for: defaultAIPreset) }
    var defaultAIBaseURLString: String { aiBaseURLString(for: defaultAIPreset) }
    var defaultAIPrefillsPrompt: Bool { aiPrefillsPrompt(for: defaultAIPreset) }

    func aiName(for preset: DefaultAIPreset) -> String {
        switch preset {
        case .custom:
            if let host = normalizedCustomAIURL?.host, !host.isEmpty { return host }
            return preset.displayName
        default:
            return preset.displayName
        }
    }

    func aiBaseURLString(for preset: DefaultAIPreset) -> String {
        switch preset {
        case .custom: return normalizedCustomAIURL?.absoluteString ?? ""
        default:      return preset.baseURLString
        }
    }

    func aiPrefillsPrompt(for preset: DefaultAIPreset) -> Bool {
        switch preset {
        case .chatGPT: return false
        case .custom:  return normalizedCustomAIURL?.absoluteString.contains("{prompt}") == true
        default:       return false
        }
    }

    func defaultAIURL(prompt: String) -> URL? { aiURL(for: defaultAIPreset, prompt: prompt) }

    func aiURL(for preset: DefaultAIPreset, prompt: String) -> URL? {
        switch preset {
        case .chatGPT:
            return URL(string: preset.baseURLString)
        case .custom:
            guard let custom = normalizedCustomAIURL else { return nil }
            let urlString = custom.absoluteString
            if urlString.contains("{prompt}") {
                let encoded = prompt.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? prompt
                return URL(string: urlString.replacingOccurrences(of: "{prompt}", with: encoded))
            }
            return custom
        default:
            return URL(string: preset.baseURLString)
        }
    }

    var normalizedCustomAIURL: URL? {
        let trimmed = customAIURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let direct = URL(string: trimmed), direct.scheme != nil { return direct }
        return URL(string: "https://\(trimmed)")
    }
}
