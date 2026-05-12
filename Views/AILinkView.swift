import SwiftUI

/*
 AI LINK VIEW
 ============
 Manages character, phrase, and image prompt generation for the user's default AI.
 The root view owns state and high-level mode switching; focused extensions own
 task selection, template editing, prompt display, and launch/copy actions.
*/

struct AILinkView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case promptGeneration = "Prompt Generation"
        case templateEditor = "Edit Task Template"

        var id: String { rawValue }
    }

    @EnvironmentObject var store: RadixStore
    @Environment(\.horizontalSizeClass) var sizeClass
    @Environment(\.openURL) var openURL
    let item: ComponentItem?
    @State var copied = false
    @State var openedDefaultAI = false
    @State var isTasksExpanded = true
    @State var mode: Mode = .promptGeneration
    @State var selectedAIPreset: DefaultAIPreset?
    @State var isRunningGeminiPhraseAPI = false
    @State var geminiPhraseAPIMessage: String?

    /// The character or phrase word that tasks 1-3 will act on.
    /// Phrase preview takes priority over single character preview.
    var activeCharacter: String? {
        if let phrase = store.activeSidebarPhrasePreview {
            return phrase.word
        }
        return item?.character ?? store.previewCharacter
    }

    var selectedCollection: CharacterCollection? {
        store.selectedAICollection
    }

    var hasCharacterTasks: Bool {
        store.promptSelectedTaskIDs.contains { !PromptConfig.collectionTaskIDs.contains($0) }
    }

    var hasCollectionTasks: Bool {
        store.promptSelectedTaskIDs.contains { PromptConfig.collectionTaskIDs.contains($0) }
    }

    var canGeneratePrompt: Bool {
        (!hasCharacterTasks || activeCharacter != nil) &&
        (!hasCollectionTasks || selectedCollection != nil) &&
        (hasCharacterTasks || hasCollectionTasks)
    }

    var canRunGeminiPhraseAPI: Bool {
        store.promptSelectedTaskIDs.contains("task6") && selectedCollection != nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if sizeClass == .compact, let item {
                    standardPhoneCharacterPreview(
                        character: item.character,
                        onClear: { store.previewCharacter = nil }
                    )
                }

                modePicker

                switch mode {
                case .promptGeneration:
                    promptGenerationSection
                case .templateEditor:
                    templateEditorSection
                }
            }
            .padding(20)
        }
        .navigationTitle("AI Link")
        .background(Color(.systemGroupedBackground))
        .onAppear {
            store.refreshPhrases()
            if store.shouldAutoOpenAILinkTask4 {
                store.shouldAutoOpenAILinkTask4 = false
                openPromptInDefaultAI()
            }
            if selectedAIPreset == nil {
                selectedAIPreset = store.defaultAIPreset
            }
        }
    }

    var modePicker: some View {
        Picker("AI Link Mode", selection: $mode) {
            ForEach(Mode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }
}
