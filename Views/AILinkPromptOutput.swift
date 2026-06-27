import SwiftUI

extension AILinkView {
    var promptBox: some View {
        VStack(alignment: .leading, spacing: 8) {
            promptActions
        }
        .padding()
        .background(RadixTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    var promptActions: some View {
        let currentPreset = selectedAIPreset ?? store.defaultAIPreset
        let currentAIName = store.aiName(for: currentPreset)

        if sizeClass == .compact {
            VStack(alignment: .leading, spacing: 10) {
                readyToSendLine
                promptActionButtons(currentPreset: currentPreset, currentAIName: currentAIName)
                promptStatusText(currentPreset: currentPreset, currentAIName: currentAIName)
            }
        } else {
            HStack(spacing: 12) {
                readyToSendLine
                promptActionButtons(currentPreset: currentPreset, currentAIName: currentAIName)
                promptStatusText(currentPreset: currentPreset, currentAIName: currentAIName)
            }
        }
    }

    var readyToSendLine: some View {
        Label(readyToSendText, systemImage: canGeneratePrompt ? "checkmark.circle" : "exclamationmark.triangle")
            .font(ResponsiveFont.caption.weight(.semibold))
            .foregroundStyle(canGeneratePrompt ? Color.accentColor : Color.orange)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background((canGeneratePrompt ? Color.accentColor : Color.orange).opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .layoutPriority(1)
    }

    func promptActionButtons(currentPreset: DefaultAIPreset, currentAIName: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                promptCopyButton
                promptOpenMenu(currentPreset: currentPreset, currentAIName: currentAIName)
                geminiPhraseButton
            }

            VStack(alignment: .leading, spacing: 8) {
                promptCopyButton
                promptOpenMenu(currentPreset: currentPreset, currentAIName: currentAIName)
                geminiPhraseButton
            }
        }
    }

    var promptCopyButton: some View {
        Button {
            copyPromptToClipboard()
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }
        .buttonStyle(.bordered)
        .font(ResponsiveFont.headline)
        .disabled(!canGeneratePrompt)
    }

    func promptOpenMenu(currentPreset: DefaultAIPreset, currentAIName: String) -> some View {
        Menu {
            ForEach(DefaultAIPreset.allCases, id: \.self) { preset in
                Button {
                    selectedAIPreset = preset
                    openPromptInAI(preset)
                } label: {
                    Label(
                        "Open \(store.aiName(for: preset))",
                        systemImage: preset == currentPreset ? "checkmark" : "arrow.up.forward.app"
                    )
                }
                .disabled(preset == .custom && store.aiBaseURLString(for: .custom).isEmpty)
            }
        } label: {
            Label("Open \(currentAIName)", systemImage: "arrow.up.forward.app")
        }
        .menuStyle(.button)
        .buttonStyle(.borderedProminent)
        .font(ResponsiveFont.headline)
        .disabled(!canGeneratePrompt)
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
            .font(ResponsiveFont.headline)
            .disabled(isRunningGeminiPhraseAPI)
        }
    }

    @ViewBuilder
    func promptStatusText(currentPreset: DefaultAIPreset, currentAIName: String) -> some View {
        if openedDefaultAI {
            Text(store.aiPrefillsPrompt(for: currentPreset)
                 ? "Opening \(currentAIName). AI prompt copied as backup."
                 : "Opening \(currentAIName). AI prompt copied. Paste it into \(currentAIName).")
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
        if PromptConfig.collectionTaskIDs.contains(task.id), let selectedCollection {
            text = store.promptForTask(task, subject: .collection(selectedCollection))
        } else if let activeCharacter {
            text = store.promptForTask(task, subject: .character(activeCharacter))
        } else {
            text = ""
        }
        return text.isEmpty ? "Choose an AI task." : text
    }

    var readyToSendText: String {
        let taskTitle = draftPromptTask?.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let taskName = (taskTitle?.isEmpty == false ? taskTitle : selectedPromptTask?.title) ?? "AI Task"
        if hasCharacterTasks {
            return "Ready to send: \(taskName) · Subject: \(activeCharacter ?? "Choose subject")"
        }
        if hasCollectionTasks {
            let pageName = selectedCollection?.name.trimmingCharacters(in: .whitespacesAndNewlines)
            return "Ready to send: \(taskName) · Page: \((pageName?.isEmpty == false ? pageName : nil) ?? "Choose page")"
        }
        return "Choose an AI task"
    }

    var promptContextLine: String? {
        var parts: [String] = []

        if hasCharacterTasks {
            if let activeCharacter {
                parts.append("Subject: \(activeCharacter)")
            } else {
                parts.append("Choose subject")
            }
        }

        if hasCollectionTasks {
            if let selectedCollection {
                let name = selectedCollection.name.trimmingCharacters(in: .whitespacesAndNewlines)
                parts.append("Page: \(name.isEmpty ? "Saved Page" : name)")
            } else {
                parts.append("Choose page")
            }
        }

        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    func openPromptInDefaultAI() {
        openPromptInAI(selectedAIPreset ?? store.defaultAIPreset)
    }

    func openPromptInAI(_ preset: DefaultAIPreset) {
        guard canGeneratePrompt else { return }
        let text = generatedPromptText
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
