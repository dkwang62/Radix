import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension AILinkView {
    var promptBox: some View {
        VStack(alignment: .leading, spacing: 8) {
            promptActions

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Generated Prompt")
                    .font(ResponsiveFont.subheadline)
                    .foregroundStyle(.secondary)

                if let promptContextLine {
                    Text(promptContextLine)
                        .font(ResponsiveFont.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(Capsule())
                }
            }

            ScrollView {
                Text(generatedPromptText)
                    .font(.system(size: 15, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(12)
            }
            .frame(minHeight: 350)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.separator), lineWidth: 1)
            )
        }
    }

    var promptActions: some View {
        let currentPreset = selectedAIPreset ?? store.defaultAIPreset
        let currentAIName = store.aiName(for: currentPreset)

        return HStack(spacing: 12) {
            Button("Copy Prompt") {
                copyPromptToClipboard()
            }
            .buttonStyle(.bordered)
            .font(ResponsiveFont.headline)
            .disabled(!canGeneratePrompt)

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

            if canRunGeminiPhraseAPI {
                Button {
                    runGeminiPhraseAPI()
                } label: {
                    if isRunningGeminiPhraseAPI {
                        Label("Running Gemini", systemImage: "hourglass")
                    } else {
                        Label("Run Gemini API and Add", systemImage: "curlybraces")
                    }
                }
                .buttonStyle(.borderedProminent)
                .font(ResponsiveFont.headline)
                .disabled(isRunningGeminiPhraseAPI)
            }

            if openedDefaultAI {
                Text(store.aiPrefillsPrompt(for: currentPreset)
                     ? "Opening \(currentAIName). Prompt copied as backup."
                     : "Opening \(currentAIName). Prompt copied. Paste it into \(currentAIName).")
                    .font(ResponsiveFont.footnote)
                    .foregroundStyle(.secondary)
            } else if let geminiPhraseAPIMessage {
                Text(geminiPhraseAPIMessage)
                    .font(ResponsiveFont.footnote)
                    .foregroundStyle(.secondary)
            } else if copied {
                Text("Copied. Paste into \(currentAIName).")
                    .font(ResponsiveFont.footnote)
                    .foregroundStyle(.secondary)
            }
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
        geminiPhraseAPIMessage = "Running Gemini API..."
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
        if hasCollectionTasks && selectedCollection == nil {
            return "Choose an image for Tasks 4-6."
        }
        if hasCharacterTasks && activeCharacter == nil {
            return "Choose a character for Tasks 1-3."
        }
        let text = store.promptText(character: activeCharacter, collection: selectedCollection)
        return text.isEmpty ? "Choose at least one AI task." : text
    }

    var promptContextLine: String? {
        var parts: [String] = []

        if hasCharacterTasks {
            if let activeCharacter {
                parts.append("Tasks 1-3: \(activeCharacter)")
            } else {
                parts.append("Tasks 1-3: no character")
            }
        }

        if hasCollectionTasks {
            if let selectedCollection {
                parts.append("Tasks 4-6: \(selectedCollection.name)")
            } else {
                parts.append("Tasks 4-6: no image")
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
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #endif
        guard showStatus else { return }
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            copied = false
        }
    }
}
