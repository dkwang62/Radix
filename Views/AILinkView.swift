import SwiftUI

/*
 AI LINK VIEW
 ============
 Manages character, phrase, and image instruction generation for the user's default AI.
 The root view owns state and high-level mode switching; focused extensions own
 task selection, template editing, instruction display, and launch/copy actions.
*/

struct AILinkView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case promptGeneration = "Instructions"
        case templateEditor = "Customize"

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
        store.promptSelectedTaskIDs.contains("task4") && selectedCollection != nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Go beyond the dictionary")
                        .font(ResponsiveFont.headline)
                    Text("Use AI to explore nuance and current usage, understand Chinese in context, translate complete pages naturally, and find useful phrases or concepts that traditional dictionaries may not yet cover.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if sizeClass == .compact {
                    aiPhoneSubjectPreview
                }

                aiPracticeContextSection
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
        .navigationTitle(RadixCopy.aiLink)
        .background(RadixTheme.groupedBackground)
        .onAppear {
            store.refreshPhrases()
            if store.shouldAutoOpenAILinkTask4 {
                store.shouldAutoOpenAILinkTask4 = false
                openPromptInDefaultAI()
            }
            if store.shouldAutoRunGeminiPhraseAPI {
                store.shouldAutoRunGeminiPhraseAPI = false
                runGeminiPhraseAPI()
            }
            if selectedAIPreset == nil {
                selectedAIPreset = store.defaultAIPreset
            }
        }
    }

    @ViewBuilder
    var aiPhoneSubjectPreview: some View {
        if let phrase = store.activeSidebarPhrasePreview {
            PhraseInfoCard(
                phrase: phrase,
                onSelectCharacter: { character in
                    store.previewPhraseCardCharacter(character, in: phrase, announce: false)
                },
                onDone: {
                    store.dismissSidebarPhrasePreview()
                }
            )
            .environmentObject(store)
        } else if let character = item?.character ?? store.previewCharacter {
            standardPhoneCharacterPreview(
                character: character,
                onClear: { store.previewCharacter = nil }
            )
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

    var aiPracticeContextSection: some View {
        LazyVGrid(columns: aiPracticeContextColumns, spacing: 10) {
            aiSubjectCard
            aiCollectionCard
        }
    }

    var aiPracticeContextColumns: [GridItem] {
        if sizeClass == .compact {
            return [GridItem(.flexible(minimum: 220), spacing: 10)]
        }
        return Array(repeating: GridItem(.flexible(minimum: 220), spacing: 10), count: 2)
    }

    var aiSubjectCard: some View {
        HStack(spacing: 12) {
            Image(systemName: store.activeSidebarPhrasePreview == nil ? "character" : "text.quote")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(activeCharacter == nil ? Color.secondary : Color.accentColor)
                .frame(width: 34, height: 34)
                .background((activeCharacter == nil ? Color.secondary : Color.accentColor).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text("Subject")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                Text(aiSubjectTitle)
                    .font(ResponsiveFont.body.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(aiSubjectSubtitle)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .layoutPriority(1)

            Spacer(minLength: 0)

            Button {
                store.goToSearchRoot()
            } label: {
                ViewThatFits(in: .horizontal) {
                    Label("Choose in Search", systemImage: "magnifyingglass")
                        .font(ResponsiveFont.caption.weight(.semibold))
                        .fixedSize(horizontal: true, vertical: false)

                    Image(systemName: "magnifyingglass")
                        .radixMinimumTapTarget()
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel("Choose AI Link Subject")
            .help("Open Search, choose a character or phrase, then return to AI Link.")
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
        .background(RadixTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    var aiCollectionCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(selectedCollection == nil ? Color.secondary : Color.accentColor)
                .frame(width: 34, height: 34)
                .background((selectedCollection == nil ? Color.secondary : Color.accentColor).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(RadixCopy.savedPage)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                Text(selectedCollection?.name ?? "No page selected")
                    .font(ResponsiveFont.body.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(aiCollectionSubtitle)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            aiCollectionMenu
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
        .background(RadixTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    var aiSubjectTitle: String {
        if let phrase = store.activeSidebarPhrasePreview {
            return phrase.word
        }
        if let activeCharacter {
            return activeCharacter
        }
        return "No subject selected"
    }

    var aiSubjectSubtitle: String {
        if let phrase = store.activeSidebarPhrasePreview {
            return phrase.pinyin.isEmpty ? "Phrase" : phrase.pinyin
        }
        if let activeCharacter {
            let pinyin = store.item(for: activeCharacter)?.pinyinText ?? ""
            return pinyin.isEmpty ? "Character" : pinyin
        }
        return "Search or browse first"
    }

    var aiCollectionSubtitle: String {
        guard let selectedCollection else {
            return store.allCollections.isEmpty ? "No saved pages" : "\(store.allCollections.count) available"
        }
        return "\(selectedCollection.characters.count) characters"
    }
}
