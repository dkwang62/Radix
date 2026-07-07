import Foundation

/*
 RADIX STORE — AI PROMPT PERSISTENCE
 =====================================
 Manages PromptConfig mutations, task management, prompt rendering, and
 UserDefaults persistence for AI template settings. Portable prompt and launch
 workflow values and the active prompt subject are owned by RadixAILinkState.
*/

extension RadixStore {

    func loadPromptSettings() {
        if preferences.object(forKey: RadixPreferenceKey.speechEnabled) != nil {
            speechEnabled = preferences.bool(forKey: RadixPreferenceKey.speechEnabled)
        } else if preferences.object(forKey: RadixPreferenceKey.legacySpeakOnSelection) != nil
                    || preferences.object(forKey: RadixPreferenceKey.legacySpeakOnPreview) != nil {
            speechEnabled = preferences.bool(forKey: RadixPreferenceKey.legacySpeakOnSelection)
                || preferences.bool(forKey: RadixPreferenceKey.legacySpeakOnPreview)
        }
        if let data = preferences.data(forKey: RadixPreferenceKey.promptConfig),
           let saved = try? JSONDecoder().decode(PromptConfig.self, from: data) {
            promptConfig = saved.normalized()
        }
        if let selection = preferences.array(forKey: RadixPreferenceKey.promptTaskSelection) as? [String] {
            promptSelectedTaskIDs = selection
        }
        if let topicID = preferences.string(forKey: RadixPreferenceKey.conversationPracticeTopic) {
            selectedConversationPracticeTopicID = topicID
        }
        if preferences.object(forKey: RadixPreferenceKey.aiConversationEntryCount) != nil {
            aiConversationEntryCount = PromptConfig.normalizedConversationEntryCount(
                preferences.integer(forKey: RadixPreferenceKey.aiConversationEntryCount)
            )
        }
        if let rawPreset = preferences.string(forKey: RadixPreferenceKey.defaultAIPreset),
           let preset = DefaultAIPreset(rawValue: rawPreset) {
            defaultAIPreset = preset
        }
        if let value = preferences.string(forKey: RadixPreferenceKey.customAIURL) { customAIURLString = value }
        if let value = preferences.string(forKey: RadixPreferenceKey.openAIAPIKey) { openAIAPIKey = value }
        if let value = preferences.string(forKey: RadixPreferenceKey.geminiAPIKey) { geminiAPIKey = value }
        if let value = preferences.string(forKey: RadixPreferenceKey.claudeAPIKey) { claudeAPIKey = value }
        if let value = preferences.string(forKey: RadixPreferenceKey.deepSeekAPIKey) { deepSeekAPIKey = value }
        if let value = preferences.string(forKey: RadixPreferenceKey.customAIAPIKey) { customAIAPIKey = value }
        if let value = preferences.string(forKey: RadixPreferenceKey.geminiModelID),
           !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            geminiModelID = value
        }
        restoreRetainedGeminiAPIKeyIfNeeded()
    }

    func persistPromptSettings() {
        persistRetainedGeminiAPIKeyIfNeeded()
        if let data = try? JSONEncoder().encode(promptConfig) {
            preferences.set(data, forKey: RadixPreferenceKey.promptConfig)
        }
        preferences.set(promptSelectedTaskIDs, forKey: RadixPreferenceKey.promptTaskSelection)
        preferences.set(selectedConversationPracticeTopicID, forKey: RadixPreferenceKey.conversationPracticeTopic)
        preferences.set(aiConversationEntryCount, forKey: RadixPreferenceKey.aiConversationEntryCount)
        preferences.set(defaultAIPreset.rawValue, forKey: RadixPreferenceKey.defaultAIPreset)
        preferences.set(customAIURLString, forKey: RadixPreferenceKey.customAIURL)
        preferences.set(openAIAPIKey, forKey: RadixPreferenceKey.openAIAPIKey)
        preferences.set(geminiAPIKey, forKey: RadixPreferenceKey.geminiAPIKey)
        preferences.set(claudeAPIKey, forKey: RadixPreferenceKey.claudeAPIKey)
        preferences.set(deepSeekAPIKey, forKey: RadixPreferenceKey.deepSeekAPIKey)
        preferences.set(customAIAPIKey, forKey: RadixPreferenceKey.customAIAPIKey)
        preferences.set(geminiModelID, forKey: RadixPreferenceKey.geminiModelID)
        updatePromptAutosaveStatus()
    }

    func restoreRetainedGeminiAPIKeyIfNeeded(imported: String? = nil) {
        let resolved = APIKeyRetentionPolicy.resolvedGeminiKey(
            current: geminiAPIKey,
            retainedLatest: preferences.string(forKey: RadixPreferenceKey.latestGeminiAPIKey),
            imported: imported
        )
        guard !resolved.isEmpty, resolved != geminiAPIKey else { return }
        geminiAPIKey = resolved
        preferences.set(resolved, forKey: RadixPreferenceKey.latestGeminiAPIKey)
    }

    func persistRetainedGeminiAPIKeyIfNeeded() {
        let trimmed = geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        preferences.set(trimmed, forKey: RadixPreferenceKey.latestGeminiAPIKey)
    }

    func updatePromptAutosaveStatus(now: Date = Date()) {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let savedText = formatter.localizedString(for: now, relativeTo: now)
        promptAutosaveStatus = "Changes save automatically. Last saved \(savedText)."
    }

    func speakCharacter(_ character: String) {
        guard speechEnabled else { return }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 70_000_000)
            speechService.speak(character)
        }
    }

    func speakPhrase(_ phrase: PhraseItem) {
        guard speechEnabled else { return }
        speechService.speakPhrase(phrase)
    }

    func readPhraseAloud(_ phrase: PhraseItem) {
        speechService.speakPhrase(phrase)
    }

    func readCharacterAloud(_ character: String) {
        speechService.speak(character)
    }

    @discardableResult
    func speakCharacters(in text: String) -> Int {
        speechService.speakCharacters(in: text)
    }

    // MARK: - Task selection

    func selectAllPromptTasks() {
        promptSelectedTaskIDs = promptConfig.tasks.map(\.id)
        persistPromptSettings()
    }

    // MARK: - Config mutation

    func setPromptPreamble(_ value: String) {
        promptConfig.preamble = value
        persistPromptSettings()
    }

    func setPromptEpilogue(_ value: String) {
        promptConfig.epilogue = value
        persistPromptSettings()
    }

    func setCollectionPromptPreamble(_ value: String) {
        promptConfig.collectionPreamble = value
        persistPromptSettings()
    }

    func setCollectionPromptEpilogue(_ value: String) {
        promptConfig.collectionEpilogue = value
        persistPromptSettings()
    }

    func setPromptTaskTitle(taskID: String, title: String) {
        guard let idx = promptConfig.tasks.firstIndex(where: { $0.id == taskID }) else { return }
        promptConfig.tasks[idx].title = title
        persistPromptSettings()
    }

    func setPromptTaskTemplate(taskID: String, template: String) {
        guard let idx = promptConfig.tasks.firstIndex(where: { $0.id == taskID }) else { return }
        promptConfig.tasks[idx].template = template
        persistPromptSettings()
    }

    @discardableResult
    func addPromptTask() -> String {
        let next = (promptConfig.tasks.count + 1)
        var id = "task\(next)"
        var suffix = 1
        while promptConfig.tasks.contains(where: { $0.id == id }) {
            suffix += 1
            id = "task\(next)_\(suffix)"
        }
        let task = PromptTask(id: id, title: "Custom Task", template: "Custom Task\n\n")
        promptConfig.tasks.append(task)
        promptSelectedTaskIDs = [id]
        persistPromptSettings()
        return id
    }

    func setPromptTask(taskID: String, title: String, template: String) {
        guard let idx = promptConfig.tasks.firstIndex(where: { $0.id == taskID }) else { return }
        promptConfig.tasks[idx].title = title
        promptConfig.tasks[idx].template = template
        persistPromptSettings()
    }

    func defaultPromptTask(for taskID: String) -> PromptTask {
        PromptConfig.streamlitDefault.tasks.first(where: { $0.id == taskID }) ??
        PromptTask(id: taskID, title: "Custom Task", template: "Custom Task\n\n")
    }

    func removePromptTask(taskID: String) {
        promptConfig.tasks.removeAll { $0.id == taskID }
        promptSelectedTaskIDs.removeAll { $0 == taskID }
        persistPromptSettings()
    }

    func resetPromptConfigToDefaults() {
        promptConfig = .streamlitDefault
        promptSelectedTaskIDs = PromptConfig.defaultSelectedTaskIDs
        aiConversationEntryCount = PromptConfig.defaultConversationEntryCount
        persistPromptSettings()
    }

    func setPromptTask(_ taskID: String, enabled: Bool) {
        promptSelectedTaskIDs = PromptTaskSelection.toggled(taskID, in: promptSelectedTaskIDs, isEnabled: enabled)
        persistPromptSettings()
    }

    // MARK: - Prompt rendering

    func promptForTask(_ task: PromptTask, subject: ActiveSubject) -> String {
        let config = PromptConfig(
            version: promptConfig.version,
            preamble: promptConfig.preamble,
            tasks: [task],
            epilogue: promptConfig.epilogue,
            collectionPreamble: promptConfig.collectionPreamble,
            collectionEpilogue: promptConfig.collectionEpilogue
        )
        return config.renderPrompt(selectedTaskIDs: [task.id], context: promptRenderContext(for: subject), subject: subject)
    }

    func promptText(for subject: ActiveSubject) -> String {
        promptConfig.renderPrompt(selectedTaskIDs: promptSelectedTaskIDs, context: promptRenderContext(for: subject), subject: subject)
    }

    func promptText(for subject: ActiveSubject, selectedTaskIDs: [String]) -> String {
        promptConfig.renderPrompt(selectedTaskIDs: selectedTaskIDs, context: promptRenderContext(for: subject), subject: subject)
    }

    func promptText(character: String?, collection: CharacterCollection?) -> String {
        let selectedIDs = Set(promptSelectedTaskIDs)
        let selectedTasks = promptConfig.normalized().tasks.filter { selectedIDs.contains($0.id) }
        let characterTaskIDs = selectedTasks.filter {
            !PromptConfig.collectionTaskIDs.contains($0.id) &&
                !PromptConfig.practiceTopicTaskIDs.contains($0.id)
        }.map(\.id)
        let collectionTaskIDs = selectedTasks.filter { PromptConfig.collectionTaskIDs.contains($0.id) }.map(\.id)
        var sections: [String] = []

        if !characterTaskIDs.isEmpty, let character {
            sections.append(promptConfig.renderPrompt(
                selectedTaskIDs: characterTaskIDs,
                context: promptRenderContext(for: .character(character)),
                subject: .character(character)
            ))
        }

        if !collectionTaskIDs.isEmpty, let collection {
            sections.append(promptConfig.renderPrompt(
                selectedTaskIDs: collectionTaskIDs,
                context: promptRenderContext(for: .collection(collection)),
                subject: .collection(collection)
            ))
        }

        return sections.joined(separator: "\n\n")
    }

    func promptText(for character: String) -> String {
        promptText(for: .character(character))
    }

    func ocrReviewPrompt(for collection: CharacterCollection) -> String {
        promptText(for: .collection(collection), selectedTaskIDs: ["task7"])
    }

    // MARK: - Render context

    func promptRenderContext(for subject: ActiveSubject) -> PromptRenderContext {
        let char: String
        let collectionName: String
        let collectionCharacters: String
        let collectionCharacterSet: Set<String>?
        let originalOCRText: String
        let recognizedOCRCharacters: String
        let unrecognizedOCRCharacters: String
        let nearbyOCRPhrases: String
        let practiceTopic: ConversationPracticeTopic?
        switch subject {
        case .character(let character):
            char = character.trimmingCharacters(in: .whitespacesAndNewlines)
            collectionName = ""
            collectionCharacters = ""
            collectionCharacterSet = nil
            originalOCRText = ""
            recognizedOCRCharacters = ""
            unrecognizedOCRCharacters = ""
            nearbyOCRPhrases = ""
            practiceTopic = nil
        case .collection(let collection):
            char = collection.characters.first ?? ""
            collectionName = collection.name
            collectionCharacters = collection.characters.joined(separator: " ")
            collectionCharacterSet = collection.uniqueCharacters
            originalOCRText = collection.characters.joined()
            let captured = collection.characters
            let recognized = captured.filter { componentRepo.hasCharacter($0) }
            let unrecognized = captured.filter { !componentRepo.hasCharacter($0) }
            recognizedOCRCharacters = recognized.joined(separator: " ")
            unrecognizedOCRCharacters = unrecognized.isEmpty ? "None detected in saved page characters" : unrecognized.joined(separator: " ")
            let nearby = browsePagePhraseCandidates(in: collection).prefix(30).map(\.phrase.word)
            nearbyOCRPhrases = nearby.isEmpty ? "None detected" : nearby.joined(separator: ", ")
            practiceTopic = nil
        case .practiceTopic(let topic):
            char = ""
            collectionName = ""
            collectionCharacters = ""
            collectionCharacterSet = nil
            originalOCRText = ""
            recognizedOCRCharacters = ""
            unrecognizedOCRCharacters = ""
            nearbyOCRPhrases = ""
            practiceTopic = topic
        }
        let item = componentRepo.byCharacter[char]
        let analysis = componentRepo.analyzeStructure(for: char)
        let pFamily = componentRepo.pronunciationFamily(for: char)
        let sFamily = componentRepo.semanticFamily(for: char)
        let rawCaptureText = activeCaptureDraft.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        let captureText: String = {
            guard let collectionCharacterSet else { return rawCaptureText }
            let rawCharacters = Set(CaptureTextExtractor.uniqueCharacters(in: rawCaptureText))
            if !rawCharacters.isEmpty && rawCharacters == collectionCharacterSet {
                return ""
            }
            return rawCaptureText
        }()
        return PromptRenderContext(
            char: char,
            definitionEN: item?.definition ?? "",
            decomposition: item?.decomposition.isEmpty == false ? (item?.decomposition ?? "") : "None",
            semantic: analysis?.semantic ?? "None",
            phonetic: analysis?.phonetic ?? "None",
            phoneticPinyin: analysis?.phoneticPinyin ?? "None",
            isSoundMatch: String(analysis?.isSoundMatch ?? false),
            pronunciationFamily: pFamily.isEmpty ? "None" : pFamily.joined(separator: ", "),
            semanticFamily: sFamily.isEmpty ? "None" : sFamily.joined(separator: ", "),
            collectionName: collectionName,
            captureCharacters: collectionCharacters.isEmpty ? CaptureTextExtractor.uniqueCharacters(in: activeCaptureDraft.charactersText).joined(separator: " ") : collectionCharacters,
            captureText: captureText,
            originalOCRText: originalOCRText,
            recognizedOCRCharacters: recognizedOCRCharacters,
            unrecognizedOCRCharacters: unrecognizedOCRCharacters,
            nearbyOCRPhrases: nearbyOCRPhrases,
            practiceTopicID: practiceTopic?.id ?? "",
            practiceTopicTitle: practiceTopic?.title ?? "",
            practiceTopicSummary: practiceTopic?.summary ?? "",
            practiceTopicBrief: practiceTopic?.generationBrief ?? "",
            practiceTopicSituations: practiceTopic?.situations.map { "- \($0)" }.joined(separator: "\n") ?? "",
            conversationEntryCount: "\(aiConversationEntryCount)"
        )
    }
}
