import Foundation

/*
 RADIX STORE — AI PROMPT PERSISTENCE
 =====================================
 Manages PromptConfig mutations, task management, prompt rendering, and
 UserDefaults persistence for AI template settings. Portable prompt and launch
 workflow values are owned by RadixAILinkState.
*/

extension RadixStore {

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

    func addPromptTask() {
        let next = (promptConfig.tasks.count + 1)
        var id = "task\(next)"
        var suffix = 1
        while promptConfig.tasks.contains(where: { $0.id == id }) {
            suffix += 1
            id = "task\(next)_\(suffix)"
        }
        let task = PromptTask(id: id, title: "Task \(next)", template: "Task \(next)\n\n")
        promptConfig.tasks.append(task)
        promptSelectedTaskIDs.append(id)
        persistPromptSettings()
    }

    func removePromptTask(taskID: String) {
        promptConfig.tasks.removeAll { $0.id == taskID }
        promptSelectedTaskIDs.removeAll { $0 == taskID }
        persistPromptSettings()
    }

    func resetPromptConfigToDefaults() {
        promptConfig = .streamlitDefault
        promptSelectedTaskIDs = PromptConfig.defaultSelectedTaskIDs
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
        let characterTaskIDs = selectedTasks.filter { !PromptConfig.collectionTaskIDs.contains($0.id) }.map(\.id)
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

    // MARK: - Render context

    func promptRenderContext(for subject: ActiveSubject) -> PromptRenderContext {
        let char: String
        let collectionName: String
        let collectionCharacters: String
        let collectionCharacterSet: Set<String>?
        switch subject {
        case .character(let character):
            char = character.trimmingCharacters(in: .whitespacesAndNewlines)
            collectionName = ""
            collectionCharacters = ""
            collectionCharacterSet = nil
        case .collection(let collection):
            char = collection.characters.first ?? ""
            collectionName = collection.name
            collectionCharacters = collection.characters.joined(separator: " ")
            collectionCharacterSet = collection.uniqueCharacters
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
            captureText: captureText
        )
    }
}
