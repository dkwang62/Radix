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
    @State var draftPromptTitle = ""
    @State var draftPromptTemplate = ""
    @State var draftPromptSubjectType: PromptTaskSubjectType = .characterPhrase
    @State var promptSaveStatus: String?
    @State var selectedAIPreset: DefaultAIPreset?
    @State var isRunningGeminiPhraseAPI = false
    @State var geminiPhraseAPIMessage: String?
    @State var isPromptTemplateExpanded = false
    @State var aiResultText = ""
    @State var aiResultMessage: String?
    @State var aiResultError: String?
    @State var aiImportedPracticePack: ConversationPracticePack?
    @State var isAIResultTextExpanded = true
    @State var isShowingTemplateManager = false
    @State var selectedAISentenceRecord: SentenceExampleRecord?
    @State var aiSentenceSearchText = ""
    @State var aiSentencePickerRecords: [SentenceExampleRecord] = []
    @State var aiSentencePickerResultCount = 0
    @State var isPromptTemplateRevisionExpanded = false
    @State var promptTemplateChangeRequest = ""
    @State var promptTemplateRevisionText = ""
    @State var promptTemplateRevisionMessage: String?
    @State var isRunningPromptTest = false
    @State var promptTestOutput = ""
    @State var promptTestMessage: String?
    @State var promptTestError: String?
    @State var promptTestTask: Task<Void, Never>?
    @State var activePromptTestRequestID: UUID?
    @State var promptTestOutputContext: PromptTestRequestContext?

    /// The character or phrase word that character/phrase tasks act on.
    /// Explicit object launches take priority over preview-derived subjects.
    var activeCharacter: String? {
        if case .character(let subject) = store.activeSubject {
            return subject
        }
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
        if let selectedPromptTaskID = store.selectedPromptTaskID,
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
        return task.subjectType == .page
    }

    var isSelectedTaskPracticeTopicTask: Bool {
        guard let task = selectedPromptTask else { return false }
        return task.subjectType == .practiceTopic
    }

    var isSelectedTaskSentenceTask: Bool {
        guard let task = selectedPromptTask else { return false }
        return task.subjectType == .sentence
    }

    var isSelectedTaskFreeTextTask: Bool {
        guard let task = selectedPromptTask else { return false }
        return task.subjectType == .freeText
    }

    var selectedTaskSupportsConversationEntryCount: Bool {
        guard let task = selectedPromptTask else { return false }
        return PromptConfig.conversationEntryCountTaskIDs.contains(task.id)
    }

    var selectedTaskSupportsSentenceExtractionDetail: Bool {
        selectedPromptTask?.id == BuiltInPromptTaskID.sentencePractice.rawValue
    }

    var hasCharacterTasks: Bool {
        selectedPromptTask?.subjectType == .characterPhrase
    }

    var hasCollectionTasks: Bool {
        selectedPromptTask != nil && isSelectedTaskPageTask
    }

    var hasSentenceTasks: Bool {
        selectedPromptTask != nil && isSelectedTaskSentenceTask
    }

    var hasPracticeTopicTasks: Bool {
        selectedPromptTask != nil && isSelectedTaskPracticeTopicTask
    }

    var hasFreeTextTasks: Bool {
        selectedPromptTask != nil && isSelectedTaskFreeTextTask
    }

    var canGeneratePrompt: Bool {
        let freeText = store.aiFreeTextInput.trimmingCharacters(in: .whitespacesAndNewlines)
        return (!hasCharacterTasks || activeCharacter != nil) &&
        (!hasCollectionTasks || selectedCollection != nil) &&
        (!hasSentenceTasks || activeSentenceItem != nil) &&
        (!hasFreeTextTasks || !freeText.isEmpty) &&
        (hasCharacterTasks || hasCollectionTasks || hasSentenceTasks || hasPracticeTopicTasks || hasFreeTextTasks)
    }

    var canRunGeminiPhraseAPI: Bool {
        selectedPromptTask?.id == BuiltInPromptTaskID.extractPhrases.rawValue && selectedCollection != nil
    }

    var draftPromptTask: PromptTask? {
        guard let selectedPromptTask else { return nil }
        return PromptTask(
            id: selectedPromptTask.id,
            title: draftPromptTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? selectedPromptTask.title
                : draftPromptTitle,
            template: draftPromptTemplate,
            subjectType: draftPromptSubjectType
        )
    }

    var hasUnsavedPromptChanges: Bool {
        guard let selectedPromptTask else { return false }
        return draftPromptTitle != selectedPromptTask.title ||
            draftPromptTemplate != selectedPromptTask.template ||
            draftPromptSubjectType != selectedPromptTask.subjectType
    }

    var isCustomPromptTask: Bool {
        guard let selectedPromptTask else { return false }
        return !PromptConfig.streamlitDefault.tasks.contains { $0.id == selectedPromptTask.id }
    }

    var isObjectLaunchedAIWorkflow: Bool {
        store.rootsReturnContext != nil ||
            store.shouldAutoOpenAILinkPrompt ||
            store.shouldAutoRunGeminiPhraseAPI
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if isObjectLaunchedAIWorkflow || isSelectedTaskFreeTextTask {
                    promptGenerationSection
                } else {
                    aiTemplateDashboardSection
                }
            }
            .padding(20)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isObjectLaunchedAIWorkflow || isSelectedTaskFreeTextTask {
                    Button {
                        isShowingTemplateManager = true
                    } label: {
                        Label("AI Templates", systemImage: "slider.horizontal.3")
                    }
                    .accessibilityLabel("AI Templates")
                    .help("AI Templates")
                }
            }
        }
        .background(RadixTheme.groupedBackground)
        .sheet(isPresented: $isShowingTemplateManager, onDismiss: {
            ensureSelectedPromptTask()
        }) {
            NavigationStack {
                ScrollView {
                    templateEditorSection
                        .padding()
                }
                .background(RadixTheme.groupedBackground)
                .navigationTitle("AI Templates")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            isShowingTemplateManager = false
                        }
                    }
                }
            }
            .presentationDetents([.large])
        }
        .onAppear {
            store.refreshPhrases()
            if selectedAIPreset == nil {
                selectedAIPreset = store.defaultAIPreset
            }
            store.cleanupBlankCustomPromptTasks()
            ensureSelectedPromptTask()
            if !isObjectLaunchedAIWorkflow {
                isPromptTemplateExpanded = true
            }
            refreshAISentencePickerResults()
            if store.shouldAutoOpenAILinkPrompt {
                store.shouldAutoOpenAILinkPrompt = false
                openPromptInDefaultAI()
            }
            if store.shouldAutoRunGeminiPhraseAPI {
                store.shouldAutoRunGeminiPhraseAPI = false
                runGeminiPhraseAPI()
            }
        }
        .onChange(of: selectedPromptTask?.id) { _, _ in
            resetAIResultWorkflow()
            resetPromptTest()
            refreshAISentencePickerResults()
        }
        .onChange(of: aiSentenceSearchText) { _, _ in
            refreshAISentencePickerResults()
        }
        .onChange(of: store.selectedPromptTaskID) { _, newValue in
            guard let newValue else { return }
            loadPromptDraft(taskID: newValue)
        }
        .onChange(of: selectedCollection?.id) { _, _ in
            resetAIResultWorkflow()
            resetPromptTest()
        }
        .onChange(of: promptTestSelectionIdentity) { _, _ in
            resetPromptTest()
        }
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

    var activeSentenceItem: ConversationPracticeItem? {
        if let selectedAISentenceRecord {
            return ConversationPracticeItem(sentenceExample: selectedAISentenceRecord, rank: 1)
        }
        return store.activePracticeSentenceItem
    }

    var activeSentenceTitle: String {
        guard let sentence = activeSentenceItem else { return "No sentence selected" }
        return sentence.simplified
    }

    var activeSentenceSubtitle: String {
        guard let sentence = activeSentenceItem else { return "Open a sentence card first" }
        let english = sentence.english.trimmingCharacters(in: .whitespacesAndNewlines)
        return english.isEmpty ? "Sentence" : english
    }

    func ensureSelectedPromptTask() {
        store.cleanupBlankCustomPromptTasks(keeping: store.selectedPromptTaskID)
        let normalizedTasks = store.promptConfig.normalized().tasks
        guard !normalizedTasks.isEmpty else {
            store.selectedPromptTaskID = nil
            return
        }
        if let savedID = store.promptSelectedTaskIDs.first,
           normalizedTasks.contains(where: { $0.id == savedID }) {
            store.selectedPromptTaskID = savedID
            loadPromptDraft(taskID: savedID)
            return
        }
        if let selectedPromptTaskID = store.selectedPromptTaskID,
           normalizedTasks.contains(where: { $0.id == selectedPromptTaskID }) {
            loadPromptDraft(taskID: selectedPromptTaskID)
            return
        }
        let fallbackID = normalizedTasks[0].id
        store.selectedPromptTaskID = fallbackID
        loadPromptDraft(taskID: fallbackID)
    }

    func selectPromptTask(_ taskID: String) {
        store.selectedPromptTaskID = taskID
        store.promptSelectedTaskIDs = [taskID]
        store.persistPromptSettings()
        loadPromptDraft(taskID: taskID)
    }

    func loadPromptDraft(taskID: String) {
        let task = store.promptConfig.normalized().tasks.first(where: { $0.id == taskID })
        draftPromptTitle = task?.title ?? ""
        draftPromptTemplate = task?.template ?? ""
        draftPromptSubjectType = task?.subjectType ?? .characterPhrase
        promptSaveStatus = nil
        resetPromptTemplateRevision()
        resetPromptTest()
    }

    func savePromptDraft() {
        guard let selectedPromptTask else { return }
        store.setPromptTask(
            taskID: selectedPromptTask.id,
            title: draftPromptTitle,
            template: draftPromptTemplate,
            subjectType: draftPromptSubjectType
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
        draftPromptSubjectType = defaultTask.subjectType
        promptSaveStatus = "Changes reverted. You can continue editing."
    }

    func createCustomPromptTask() {
        let id = store.cleanupBlankCustomPromptTasks() ?? store.addPromptTask()
        store.selectedPromptTaskID = id
        store.promptSelectedTaskIDs = [id]
        store.persistPromptSettings()
        loadPromptDraft(taskID: id)
        isPromptTemplateExpanded = true
    }

    func deleteSelectedCustomPromptTask() {
        guard let selectedPromptTask, isCustomPromptTask else { return }
        store.removePromptTask(taskID: selectedPromptTask.id)
        store.cleanupBlankCustomPromptTasks()
        store.selectedPromptTaskID = nil
        ensureSelectedPromptTask()
        promptSaveStatus = nil
    }

    func refreshAISentencePickerResults() {
        let query = SentenceExampleQuery(
            scope: .all,
            searchText: aiSentenceSearchText,
            offset: 0,
            limit: 40
        )
        let result = RadixStudyPreferences.querySentenceExamples(query)
        aiSentencePickerRecords = result.records
        aiSentencePickerResultCount = result.totalCount
    }

    func resetPromptTemplateRevision() {
        promptTemplateChangeRequest = ""
        promptTemplateRevisionText = ""
        promptTemplateRevisionMessage = nil
        isPromptTemplateRevisionExpanded = false
    }

    func resetPromptTest() {
        promptTestTask?.cancel()
        promptTestTask = nil
        activePromptTestRequestID = nil
        promptTestOutputContext = nil
        promptTestOutput = ""
        promptTestMessage = nil
        promptTestError = nil
        isRunningPromptTest = false
    }
}
