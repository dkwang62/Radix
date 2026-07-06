import SwiftUI

extension AILinkView {
    var promptBox: some View {
        VStack(alignment: .leading, spacing: 8) {
            promptActions
        }
        .padding(12)
        .background(RadixTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    var promptActions: some View {
        let currentPreset = selectedAIPreset ?? store.defaultAIPreset
        let currentAIName = store.aiName(for: currentPreset)

        VStack(alignment: .leading, spacing: 8) {
            promptActionButtons(currentPreset: currentPreset, currentAIName: currentAIName)
            promptStatusText(currentPreset: currentPreset, currentAIName: currentAIName)
        }
    }

    func promptActionButtons(currentPreset: DefaultAIPreset, currentAIName: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                promptOpenControl(currentPreset: currentPreset, currentAIName: currentAIName)
                geminiPhraseButton
            }

            VStack(alignment: .leading, spacing: 8) {
                promptOpenControl(currentPreset: currentPreset, currentAIName: currentAIName)
                geminiPhraseButton
            }
        }
    }

    func promptOpenControl(currentPreset: DefaultAIPreset, currentAIName: String) -> some View {
        HStack(spacing: 0) {
            Button {
                openPromptInAI(currentPreset)
            } label: {
                Label(openPromptButtonTitle(currentAIName: currentAIName), systemImage: "arrow.up.forward.app")
                    .padding(.trailing, 2)
            }
            .buttonStyle(.borderedProminent)
            .font(ResponsiveFont.body.bold())
            .disabled(!canGeneratePrompt)

            Menu {
                ForEach(DefaultAIPreset.allCases, id: \.self) { preset in
                    Button {
                        openPromptInAI(preset)
                    } label: {
                        Label(
                            openPromptButtonTitle(currentAIName: store.aiName(for: preset)),
                            systemImage: preset == currentPreset ? "checkmark" : "arrow.up.forward.app"
                        )
                    }
                    .disabled(preset == .custom && store.aiBaseURLString(for: .custom).isEmpty)
                }

                Divider()

                Button {
                    copyPromptToClipboard()
                } label: {
                    Label("Copy Prompt Only", systemImage: "doc.on.doc")
                }
            } label: {
                RadixCompactChevronLabel(
                    chevronFont: .system(size: 14, weight: .bold),
                    width: 38,
                    height: 34
                )
            }
            .menuStyle(.button)
            .buttonStyle(.borderedProminent)
            .disabled(!canGeneratePrompt)
            .accessibilityLabel("Choose AI app")
        }
    }

    func openPromptButtonTitle(currentAIName: String) -> String {
        if hasCharacterTasks && activeCharacter == nil {
            return "Choose Subject"
        }
        if hasCollectionTasks && selectedCollection == nil {
            return "Choose Page"
        }
        return "Open \(currentAIName): \(sendTaskName)"
    }

    @ViewBuilder
    var geminiPhraseButton: some View {
        if canRunGeminiPhraseAPI {
            Button {
                runGeminiPhraseAPI()
            } label: {
                if isRunningGeminiPhraseAPI {
                    Label("Running", systemImage: "hourglass")
                } else {
                    Label("Extract Phrases", systemImage: "curlybraces")
                }
            }
            .buttonStyle(.borderedProminent)
            .font(ResponsiveFont.body.bold())
            .disabled(isRunningGeminiPhraseAPI)
        }
    }

    @ViewBuilder
    func promptStatusText(currentPreset: DefaultAIPreset, currentAIName: String) -> some View {
        if openedDefaultAI {
            Text(store.aiPrefillsPrompt(for: currentPreset)
                 ? "Prompt copied. Opening \(currentAIName)."
                 : "Prompt copied. Opening \(currentAIName). Paste it into \(currentAIName).")
                .font(ResponsiveFont.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else if let geminiPhraseAPIMessage {
            Text(geminiPhraseAPIMessage)
                .font(ResponsiveFont.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else if copied {
            Text("Copied. Paste into \(currentAIName).")
                .font(ResponsiveFont.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    func runGeminiPhraseAPI() {
        guard let collection = selectedCollection else { return }
        let key = store.geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            geminiPhraseAPIMessage = "Add a Gemini API key in Settings first."
            return
        }

        isRunningGeminiPhraseAPI = true
            geminiPhraseAPIMessage = "Extracting phrases..."
        Task {
            do {
                let summary = try await store.runGeminiPhraseExtraction(for: collection)
                await MainActor.run {
                    geminiPhraseAPIMessage = summary.message(defaultAIName: "Gemini API")
                    isRunningGeminiPhraseAPI = false
                }
            } catch {
                await MainActor.run {
                    geminiPhraseAPIMessage = error.localizedDescription
                    isRunningGeminiPhraseAPI = false
                }
            }
        }
    }

    var generatedPromptText: String {
        guard let task = draftPromptTask else {
            return "Choose an AI task."
        }
        if hasCollectionTasks && selectedCollection == nil {
            return "Choose a saved page for this AI prompt."
        }
        if hasCharacterTasks && activeCharacter == nil {
            return "Choose a character or phrase first."
        }
        let text: String
        if PromptConfig.practiceTopicTaskIDs.contains(task.id) {
            text = store.promptForTask(task, subject: .practiceTopic(store.selectedConversationPracticeTopic))
        } else if PromptConfig.collectionTaskIDs.contains(task.id), let selectedCollection {
            text = store.promptForTask(task, subject: .collection(selectedCollection))
        } else if let activeCharacter {
            text = store.promptForTask(task, subject: .character(activeCharacter))
        } else {
            text = ""
        }
        return text.isEmpty ? "Choose an AI task." : text
    }

    var sendTaskName: String {
        let taskTitle = draftPromptTask?.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let taskName = (taskTitle?.isEmpty == false ? taskTitle : selectedPromptTask?.title) ?? "AI Task"
        for separator in [" – ", " - "] {
            if let prefix = taskName.components(separatedBy: separator).first,
               prefix != taskName,
               !prefix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return prefix
            }
        }
        return taskName
    }

    func openPromptInDefaultAI() {
        openPromptInAI(selectedAIPreset ?? store.defaultAIPreset)
    }

    func openPromptInAI(_ preset: DefaultAIPreset) {
        guard canGeneratePrompt else { return }
        let text = generatedPromptText
        selectedAIPreset = preset
        copyPromptToClipboard(showStatus: false)
        openedDefaultAI = true

        if let url = store.aiURL(for: preset, prompt: text) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                openURL(url)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
            openedDefaultAI = false
        }
    }

    func copyPromptToClipboard() {
        copyPromptToClipboard(showStatus: true)
    }

    func copyPromptToClipboard(showStatus: Bool) {
        guard canGeneratePrompt else { return }
        let text = generatedPromptText
        RadixPlatform.copyToPasteboard(text)
        guard showStatus else { return }
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            copied = false
        }
    }
}

extension AILinkView {
    @ViewBuilder
    var aiResultWorkflowSection: some View {
        if let selectedPromptTask {
            VStack(alignment: .leading, spacing: 10) {
                resultWorkflowHeader(for: selectedPromptTask)

                if aiResultWorkflowSupportsPaste(selectedPromptTask.id) {
                    aiResultActions(for: selectedPromptTask)
                    aiResultStatusBlock
                    aiResultTextSection
                } else {
                    aiResultNoPasteNeeded(for: selectedPromptTask)
                    aiResultStatusBlock
                }
            }
            .padding(12)
            .background(RadixTheme.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    var aiResultStatusBlock: some View {
        if let aiResultMessage {
            VStack(alignment: .leading, spacing: 8) {
                Label(aiResultMessage, systemImage: "checkmark.circle")
                    .font(ResponsiveFont.caption.weight(.semibold))
                    .foregroundStyle(RadixAccent.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if let aiImportedPracticePack {
                    Button {
                        store.openConversationPractice(topicID: aiImportedPracticePack.packID)
                    } label: {
                        Label("Study Practice", systemImage: "arrow.forward.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .font(ResponsiveFont.caption.weight(.semibold))
                    .accessibilityLabel("Open imported practice in Study")
                }
            }
        } else if let aiResultError {
            Label(aiResultError, systemImage: "exclamationmark.triangle")
                .font(ResponsiveFont.caption.weight(.semibold))
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    func resultWorkflowHeader(for task: PromptTask) -> some View {
        HStack(spacing: 10) {
            Image(systemName: aiResultIcon(for: task.id))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(RadixAccent.primary)
                .radixIconButtonSurface(
                    size: 32,
                    background: RadixAccent.primary.opacity(0.12)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("AI Result")
                    .font(ResponsiveFont.subheadline.weight(.semibold))
                Text(aiResultInstruction(for: task.id))
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)

            if aiResultWorkflowSupportsPaste(task.id),
               !aiResultText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    withAnimation(.snappy(duration: 0.16)) {
                        isAIResultTextExpanded.toggle()
                    }
                } label: {
                    ViewThatFits(in: .horizontal) {
                        RadixCompactChevronLabel(
                            title: isAIResultTextExpanded ? "Hide Text" : "Show Text",
                            chevronSystemName: isAIResultTextExpanded ? "chevron.up.circle" : "chevron.down.circle",
                            font: ResponsiveFont.caption.weight(.semibold),
                            chevronFont: .system(size: 14, weight: .semibold),
                            chevronOpacity: 1,
                            spacing: 6
                        )

                        RadixCompactChevronLabel(
                            chevronSystemName: isAIResultTextExpanded ? "chevron.up.circle" : "chevron.down.circle",
                            chevronFont: .system(size: 18, weight: .semibold),
                            chevronOpacity: 1,
                            width: 34,
                            height: 34
                        )
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel(isAIResultTextExpanded ? "Hide AI result text" : "Show AI result text")
                .help(isAIResultTextExpanded ? "Hide AI result text" : "Show AI result text")
            }
        }
    }

    @ViewBuilder
    var aiResultTextSection: some View {
        if isAIResultTextExpanded || aiResultText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            aiResultPasteEditor
        } else {
            aiResultCollapsedSummary
        }
    }

    var aiResultCollapsedSummary: some View {
        Button {
            withAnimation(.snappy(duration: 0.16)) {
                isAIResultTextExpanded = true
            }
        } label: {
            RadixChevronRow(
                icon: "doc.text.magnifyingglass",
                title: "Result Text Hidden",
                subtitle: aiResultTextSummary,
                minHeight: 54,
                titleFont: ResponsiveFont.caption.weight(.semibold),
                chevronSystemName: "chevron.down"
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Show AI result text")
    }

    var aiResultTextSummary: String {
        let trimmed = aiResultText.trimmingCharacters(in: .whitespacesAndNewlines)
        let lineCount = max(1, trimmed.split(whereSeparator: \.isNewline).count)
        return "\(trimmed.count) characters · \(lineCount) lines"
    }

    var aiResultPasteEditor: some View {
        TextEditor(text: Binding(
            get: { aiResultText },
            set: {
                aiResultText = $0
                aiResultMessage = nil
                aiResultError = nil
                aiImportedPracticePack = nil
                isAIResultTextExpanded = true
            }
        ))
        .font(.system(size: 14, design: .monospaced))
        .frame(height: sizeClass == .compact ? 170 : 210)
        .padding(8)
        .background(RadixTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .topLeading) {
            if aiResultText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Paste the AI answer here.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 16)
                    .padding(.leading, 14)
                    .allowsHitTesting(false)
            }
        }
    }

    func aiResultActions(for task: PromptTask) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                aiPasteButton
                aiApplyResultButton(for: task)
                aiClearResultButton
            }

            VStack(alignment: .leading, spacing: 8) {
                aiPasteButton
                aiApplyResultButton(for: task)
                aiClearResultButton
            }
        }
    }

    var aiPasteButton: some View {
        Button {
            aiResultText = RadixPlatform.pasteboardString
            aiResultMessage = nil
            aiResultError = nil
            aiImportedPracticePack = nil
            isAIResultTextExpanded = true
        } label: {
            Label("Paste", systemImage: "doc.on.clipboard")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    func aiApplyResultButton(for task: PromptTask) -> some View {
        Button {
            applyAIResult(for: task)
        } label: {
            Label(aiResultApplyTitle(for: task.id), systemImage: "checkmark.circle")
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .disabled(!canApplyAIResult(for: task))
    }

    var aiClearResultButton: some View {
        Button(role: .destructive) {
            aiResultText = ""
            aiResultMessage = nil
            aiResultError = nil
            aiImportedPracticePack = nil
            isAIResultTextExpanded = true
        } label: {
            Label("Clear", systemImage: "xmark.circle")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(aiResultText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    func aiResultNoPasteNeeded(for task: PromptTask) -> some View {
        Label(aiResultNoPasteText(for: task.id), systemImage: "checkmark.circle")
            .font(ResponsiveFont.caption)
            .foregroundStyle(.secondary)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RadixTheme.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    func aiResultWorkflowSupportsPaste(_ taskID: String) -> Bool {
        store.supportsAIResultImport(taskID: taskID)
    }

    func canApplyAIResult(for task: PromptTask) -> Bool {
        let hasText = !aiResultText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard hasText else { return false }
        if PromptConfig.collectionTaskIDs.contains(task.id), selectedCollection == nil {
            return false
        }
        return aiResultWorkflowSupportsPaste(task.id)
    }

    func applyAIResult(for task: PromptTask) {
        aiResultMessage = nil
        aiResultError = nil
        let result = aiResultText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { return }

        do {
            let outcome = try store.applyAIResult(
                taskID: task.id,
                responseText: result,
                collection: selectedCollection,
                sourceName: aiResultSourceName(for: task.id)
            )

            if case .correctedOCR(let corrected) = outcome {
                store.selectAICollection(id: corrected.id)
            }
            if case .conversationPractice(let pack) = outcome {
                aiImportedPracticePack = pack
            } else {
                aiImportedPracticePack = nil
            }
            aiResultMessage = outcome.message(defaultAIName: store.defaultAIName)
            isAIResultTextExpanded = false
        } catch {
            aiImportedPracticePack = nil
            aiResultError = error.localizedDescription
        }
    }

    func aiResultSourceName(for taskID: String) -> String {
        switch taskID {
        case AIResultTaskID.extractSentences, AIResultTaskID.createPagePractice:
            return selectedCollection?.name ?? "AI Link"
        default:
            return "AI Link"
        }
    }

    func resetAIResultWorkflow() {
        aiResultText = ""
        aiResultMessage = nil
        aiResultError = nil
        aiImportedPracticePack = nil
        isAIResultTextExpanded = true
    }

    func aiResultIcon(for taskID: String) -> String {
        switch taskID {
        case AIResultTaskID.extractPhrases: return "text.badge.plus"
        case AIResultTaskID.translatePage: return "translate"
        case AIResultTaskID.checkOCR: return "text.viewfinder"
        case AIResultTaskID.generatePracticePack, AIResultTaskID.extractSentences, AIResultTaskID.createPagePractice: return "bubble.left.and.bubble.right"
        default: return "doc.text"
        }
    }

    func aiResultInstruction(for taskID: String) -> String {
        switch taskID {
        case AIResultTaskID.extractPhrases: return "Paste the extracted phrase list here to add the phrases to Radix."
        case AIResultTaskID.translatePage: return "Paste the translation here to save it with the selected page."
        case AIResultTaskID.checkOCR: return "Paste the OCR review here to create a corrected saved page."
        case AIResultTaskID.generatePracticePack: return "Paste the practice-pack JSON here to import it into Study."
        case AIResultTaskID.extractSentences: return "Paste the extracted-sentences JSON here to import it into Conversation Practice."
        case AIResultTaskID.createPagePractice: return "Paste the page-practice JSON here to import it into Conversation Practice."
        case AIResultTaskID.createQuiz: return "This prompt runs the quiz inside the AI app, so there is no Radix paste step."
        default: return "Use the AI answer as a reference. This task does not import data back into Radix."
        }
    }

    func aiResultApplyTitle(for taskID: String) -> String {
        switch taskID {
        case AIResultTaskID.extractPhrases: return "Add Phrases"
        case AIResultTaskID.translatePage: return "Save Translation"
        case AIResultTaskID.checkOCR: return "Create Corrected Page"
        case AIResultTaskID.generatePracticePack, AIResultTaskID.extractSentences, AIResultTaskID.createPagePractice: return "Import Practice"
        default: return "Apply"
        }
    }

    func aiResultNoPasteText(for taskID: String) -> String {
        switch taskID {
        case AIResultTaskID.createQuiz:
            return "After opening the prompt, continue the quiz in the AI app. Radix has no separate result to import for this task."
        default:
            return "After opening the prompt, read or save the AI answer where it is useful. Radix has no structured import step for this task."
        }
    }
}
