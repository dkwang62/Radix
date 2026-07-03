import SwiftUI

/*
 AI LINK VIEW
 ============
 Manages character, phrase, and image AI prompt generation for the user's default AI.
 The root view owns state and high-level task/source switching; focused
 extensions own task selection, template editing, prompt display, and
 launch/copy actions.
*/

struct AILinkView: View {
    @EnvironmentObject var store: RadixStore
    @Environment(\.horizontalSizeClass) var sizeClass
    @Environment(\.openURL) var openURL
    let item: ComponentItem?
    @State var copied = false
    @State var openedDefaultAI = false
    @State var selectedPromptTaskID: String?
    @State var draftPromptTitle = ""
    @State var draftPromptTemplate = ""
    @State var promptSaveStatus: String?
    @State var selectedAIPreset: DefaultAIPreset?
    @State var isRunningGeminiPhraseAPI = false
    @State var geminiPhraseAPIMessage: String?
    @State var isPromptTemplateExpanded = false
    @State var aiResultText = ""
    @State var aiResultMessage: String?
    @State var aiResultError: String?
    @State var aiImportedPracticePack: ConversationPracticePack?

    /// The character or phrase word that tasks 1-3 will act on.
    /// Phrase preview takes priority over single character preview.
    var activeCharacter: String? {
        if let phrase = store.activeSidebarPhrasePreview {
            return phrase.word
        }
        if let remembered = store.rootBreadcrumb.first {
            return remembered
        }
        return item?.character ?? store.previewCharacter
    }

    var activeSubjectIsPhrase: Bool {
        guard let activeCharacter else { return false }
        return activeCharacter.count > 1 && store.mergedPhrase(for: activeCharacter) != nil
    }

    var activeSubjectIcon: String {
        activeSubjectIsPhrase ? "text.quote" : "character"
    }

    var selectedCollection: CharacterCollection? {
        store.selectedAICollection ?? latestViewedCollection
    }

    var latestViewedCollection: CharacterCollection? {
        store.allCollections.max { lhs, rhs in
            let lhsDate = lhs.lastViewedAt ?? lhs.createdAt
            let rhsDate = rhs.lastViewedAt ?? rhs.createdAt
            return lhsDate < rhsDate
        }
    }

    var selectedPromptTask: PromptTask? {
        let normalizedTasks = store.promptConfig.normalized().tasks
        if let selectedPromptTaskID,
           let task = normalizedTasks.first(where: { $0.id == selectedPromptTaskID }) {
            return task
        }
        if let savedID = store.promptSelectedTaskIDs.first,
           let task = normalizedTasks.first(where: { $0.id == savedID }) {
            return task
        }
        return normalizedTasks.first
    }

    var isSelectedTaskPageTask: Bool {
        guard let task = selectedPromptTask else { return false }
        return PromptConfig.collectionTaskIDs.contains(task.id)
    }

    var isSelectedTaskPracticeTopicTask: Bool {
        guard let task = selectedPromptTask else { return false }
        return PromptConfig.practiceTopicTaskIDs.contains(task.id)
    }

    var selectedTaskSupportsConversationEntryCount: Bool {
        guard let task = selectedPromptTask else { return false }
        return PromptConfig.conversationEntryCountTaskIDs.contains(task.id)
    }

    var hasCharacterTasks: Bool {
        selectedPromptTask != nil && !isSelectedTaskPageTask && !isSelectedTaskPracticeTopicTask
    }

    var hasCollectionTasks: Bool {
        selectedPromptTask != nil && isSelectedTaskPageTask
    }

    var hasPracticeTopicTasks: Bool {
        selectedPromptTask != nil && isSelectedTaskPracticeTopicTask
    }

    var canGeneratePrompt: Bool {
        (!hasCharacterTasks || activeCharacter != nil) &&
        (!hasCollectionTasks || selectedCollection != nil) &&
        (hasCharacterTasks || hasCollectionTasks || hasPracticeTopicTasks)
    }

    var canRunGeminiPhraseAPI: Bool {
        selectedPromptTask?.id == "task4" && selectedCollection != nil
    }

    var draftPromptTask: PromptTask? {
        guard let selectedPromptTask else { return nil }
        return PromptTask(
            id: selectedPromptTask.id,
            title: draftPromptTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? selectedPromptTask.title
                : draftPromptTitle,
            template: draftPromptTemplate
        )
    }

    var hasUnsavedPromptChanges: Bool {
        guard let selectedPromptTask else { return false }
        return draftPromptTitle != selectedPromptTask.title ||
            draftPromptTemplate != selectedPromptTask.template
    }

    var isCustomPromptTask: Bool {
        guard let selectedPromptTask else { return false }
        return !PromptConfig.streamlitDefault.tasks.contains { $0.id == selectedPromptTask.id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                promptGenerationSection
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
            ensureSelectedPromptTask()
        }
        .onChange(of: selectedPromptTask?.id) { _, _ in
            resetAIResultWorkflow()
        }
        .onChange(of: selectedCollection?.id) { _, _ in
            resetAIResultWorkflow()
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
        if let activeCharacter {
            return activeCharacter
        }
        return "No subject selected"
    }

    var aiSubjectSubtitle: String {
        if let activeCharacter,
           activeCharacter.count > 1,
           let phrase = store.mergedPhrase(for: activeCharacter) {
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

    var selectedCollectionName: String {
        guard let selectedCollection else { return "Choose page" }
        let name = selectedCollection.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? RadixCopy.savedPage : name
    }

    func ensureSelectedPromptTask() {
        let normalizedTasks = store.promptConfig.normalized().tasks
        guard !normalizedTasks.isEmpty else {
            selectedPromptTaskID = nil
            return
        }
        if let selectedPromptTaskID,
           normalizedTasks.contains(where: { $0.id == selectedPromptTaskID }) {
            loadPromptDraft(taskID: selectedPromptTaskID)
            return
        }
        if let savedID = store.promptSelectedTaskIDs.first,
           normalizedTasks.contains(where: { $0.id == savedID }) {
            selectedPromptTaskID = savedID
            loadPromptDraft(taskID: savedID)
            return
        }
        let fallbackID = normalizedTasks[0].id
        selectedPromptTaskID = fallbackID
        loadPromptDraft(taskID: fallbackID)
    }

    func selectPromptTask(_ taskID: String) {
        selectedPromptTaskID = taskID
        store.promptSelectedTaskIDs = [taskID]
        store.persistPromptSettings()
        loadPromptDraft(taskID: taskID)
    }

    func loadPromptDraft(taskID: String) {
        let task = store.promptConfig.normalized().tasks.first(where: { $0.id == taskID })
        draftPromptTitle = task?.title ?? ""
        draftPromptTemplate = task?.template ?? ""
        promptSaveStatus = nil
    }

    func savePromptDraft() {
        guard let selectedPromptTask else { return }
        store.setPromptTask(
            taskID: selectedPromptTask.id,
            title: draftPromptTitle,
            template: draftPromptTemplate
        )
        store.promptSelectedTaskIDs = [selectedPromptTask.id]
        store.persistPromptSettings()
        promptSaveStatus = nil
    }

    func resetPromptDraftToDefault() {
        guard let selectedPromptTask else { return }
        let defaultTask = store.defaultPromptTask(for: selectedPromptTask.id)
        draftPromptTitle = defaultTask.title
        draftPromptTemplate = defaultTask.template
        promptSaveStatus = "Changes reverted. You can continue editing."
    }

    func createCustomPromptTask() {
        let id = store.addPromptTask()
        selectedPromptTaskID = id
        loadPromptDraft(taskID: id)
    }
}
