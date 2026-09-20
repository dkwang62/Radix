import SwiftUI

struct SentenceAIContextMenuContent: View {
    @EnvironmentObject private var store: RadixStore

    let item: ConversationPracticeItem
    let displayChinese: String
    let english: String
    let isRunningAutomaticAI: Bool
    let onAutomaticExplanation: () -> Void
    let onAutomaticImprovement: () -> Void

    var body: some View {
        Menu("Explain Sentence") {
            Button(PageAIMethodCopy.manualTitle) {
                store.triggerSentenceAI(item)
            }
            automaticAIButton(action: onAutomaticExplanation)
        }

        Menu("Improve Sentence") {
            Button(PageAIMethodCopy.manualTitle) {
                store.goToAILinkSentenceTask(
                    item,
                    taskID: PromptConfig.sentenceImprovementTaskID
                )
            }
            automaticAIButton(action: onAutomaticImprovement)
        }

        Divider()

        Button {
            RadixPlatform.copyToPasteboard(displayChinese)
        } label: {
            Label("Copy Chinese", systemImage: RadixIcon.copy)
        }

        let trimmedEnglish = english.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedEnglish.isEmpty {
            Button {
                RadixPlatform.copyToPasteboard(trimmedEnglish)
            } label: {
                Label("Copy English", systemImage: RadixIcon.copy)
            }
        }
    }

    @ViewBuilder
    private func automaticAIButton(action: @escaping () -> Void) -> some View {
        if !store.hasAutomaticAIConfiguration {
            Button("Set Up Automatic AI…") {
                store.goToSettingsForAPIKeySetup()
            }
        } else {
            Button(PageAIMethodCopy.apiTitle, action: action)
                .disabled(isRunningAutomaticAI)
        }
    }
}
