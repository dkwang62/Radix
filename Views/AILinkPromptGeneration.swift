import SwiftUI

extension AILinkView {
    var promptGenerationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isSelectedTaskFreeTextTask && !isObjectLaunchedAIWorkflow {
                taskSelectionSection
            }
            selectedTaskSourceSection
            promptBox
            aiResultWorkflowSection
        }
    }

    var aiTemplateDashboardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if store.latestAIResult != nil {
                latestAIResultButton
            }
            aiTemplateDashboardHeader
            taskSelectionSection
            selectedTaskTemplateSection
            promptTestSection
        }
    }

    var latestAIResultButton: some View {
        Button {
            store.showLatestAIResult = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "sparkles.rectangle.stack")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Latest AI Result")
                        .font(ResponsiveFont.subheadline.weight(.semibold))
                    Text(store.latestAIResult?.taskTitle ?? "AI Result")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(RadixAccent.primary.opacity(0.09))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the most recent automatic AI explanation")
    }

    var aiTemplateDashboardHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Label("AI Templates", systemImage: "slider.horizontal.3")
                    .font(ResponsiveFont.title3.weight(.bold))

                Spacer()

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        aiTemplateSettingsButton
                        aiTemplateManagerButton
                    }

                    HStack(spacing: 6) {
                        aiTemplateSettingsIconButton
                        aiTemplateManagerIconButton
                    }
                }
            }

            HStack(spacing: 8) {
                Label("Edit", systemImage: "pencil")
                Label("Revise with AI", systemImage: "wand.and.stars")
                Label("Restore", systemImage: "arrow.uturn.backward")
            }
            .font(ResponsiveFont.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(RadixTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    var promptTestSection: some View {
        if selectedPromptTask != nil {
            VStack(alignment: .leading, spacing: 12) {
                Label("Test AI", systemImage: "play.circle")
                    .font(ResponsiveFont.subheadline.weight(.semibold))

                selectedTaskSourceSection

                VStack(alignment: .leading, spacing: 10) {
                    promptTestActions
                    promptTestStatus
                    promptTestOutputSection
                }
                .padding(12)
                .background(RadixTheme.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    var promptTestActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                promptTestRunButton
                promptTestCopyPromptButton
                promptTestCopyAnswerButton
                promptTestClearButton
            }

            VStack(alignment: .leading, spacing: 8) {
                promptTestRunButton
                promptTestCopyPromptButton
                promptTestCopyAnswerButton
                promptTestClearButton
            }
        }
    }

    var promptTestRunButton: some View {
        Button {
            runPromptTest()
        } label: {
            if isRunningPromptTest {
                Label("Running", systemImage: "hourglass")
            } else if store.geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Label("Set Up Gemini Key", systemImage: "key")
            } else {
                Label("Run Test", systemImage: "sparkles")
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .disabled(isRunningPromptTest || (!canGeneratePrompt && !store.geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
    }

    var promptTestCopyPromptButton: some View {
        Button {
            RadixPlatform.copyToPasteboard(generatedPromptText)
            promptTestMessage = "Prompt copied."
            promptTestError = nil
        } label: {
            Label("Copy Prompt", systemImage: "doc.on.doc")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(!canGeneratePrompt)
    }

    var promptTestCopyAnswerButton: some View {
        Button {
            RadixPlatform.copyToPasteboard(promptTestOutput)
            promptTestMessage = "Answer copied."
            promptTestError = nil
        } label: {
            Label("Copy Answer", systemImage: "doc.on.doc")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(promptTestOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    var promptTestClearButton: some View {
        Button(role: .destructive) {
            resetPromptTest()
        } label: {
            Label("Clear", systemImage: "xmark.circle")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(promptTestOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                  promptTestMessage == nil &&
                  promptTestError == nil)
    }

    @ViewBuilder
    var promptTestStatus: some View {
        if let promptTestMessage {
            Label(promptTestMessage, systemImage: "checkmark.circle")
                .font(ResponsiveFont.caption.weight(.semibold))
                .foregroundStyle(RadixAccent.primary)
                .fixedSize(horizontal: false, vertical: true)
        } else if let promptTestError {
            Label(promptTestError, systemImage: "exclamationmark.triangle")
                .font(ResponsiveFont.caption.weight(.semibold))
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    var promptTestOutputSection: some View {
        if !promptTestOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ScrollView {
                Text(promptTestOutput)
                    .font(.system(size: 14, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(8)
            }
            .frame(minHeight: 150, maxHeight: sizeClass == .compact ? 220 : 300)
            .background(RadixTheme.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    func runPromptTest() {
        let key = store.geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            store.goToSettingsForAPIKeySetup()
            return
        }
        guard canGeneratePrompt else {
            promptTestError = "Choose a test source first."
            promptTestMessage = nil
            return
        }

        isRunningPromptTest = true
        promptTestMessage = "Testing with Gemini..."
        promptTestError = nil
        promptTestOutput = ""
        let prompt = generatedPromptText
        Task {
            do {
                let output = try await store.runGeminiPromptTest(prompt: prompt)
                await MainActor.run {
                    promptTestOutput = output
                    promptTestMessage = "Test complete. Nothing was saved."
                    isRunningPromptTest = false
                }
            } catch {
                await MainActor.run {
                    promptTestError = error.localizedDescription
                    promptTestMessage = nil
                    isRunningPromptTest = false
                }
            }
        }
    }

    var aiTemplateSettingsButton: some View {
        Button {
            store.goToSettingsForAPIKeySetup()
        } label: {
            Label("AI Setup", systemImage: "key")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    var aiTemplateManagerButton: some View {
        Button {
            isShowingTemplateManager = true
        } label: {
            Label("All Templates", systemImage: "list.bullet.rectangle")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    var aiTemplateSettingsIconButton: some View {
        Button {
            store.goToSettingsForAPIKeySetup()
        } label: {
            Image(systemName: "key")
                .radixIconButtonSurface(size: 34)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("AI Setup")
        .help("AI Setup")
    }

    var aiTemplateManagerIconButton: some View {
        Button {
            isShowingTemplateManager = true
        } label: {
            Image(systemName: "list.bullet.rectangle")
                .radixIconButtonSurface(size: 34)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("All Templates")
        .help("All Templates")
    }

    var taskSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AI Task")
                .font(ResponsiveFont.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Menu {
                ForEach(store.promptConfig.normalized().tasks) { task in
                    Button {
                        selectPromptTask(task.id)
                    } label: {
                        Label(
                            task.title,
                            systemImage: task.id == selectedPromptTask?.id ? "checkmark" : "sparkles"
                        )
                    }
                }

                Divider()

                Button {
                    createCustomPromptTask()
                } label: {
                    Label("New AI Task...", systemImage: "plus.circle")
                }
            } label: {
                RadixMenuSelectorRow(
                    icon: "sparkles",
                    title: selectedPromptTask?.title ?? "Choose AI Task",
                    subtitle: nil,
                    isMissing: false,
                    minHeight: 48,
                    titleFont: ResponsiveFont.body.bold()
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Choose AI task")
        }
        .padding()
        .background(RadixTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    var selectedTaskTemplateSection: some View {
        if selectedPromptTask != nil {
            DisclosureGroup(isExpanded: $isPromptTemplateExpanded) {
                VStack(alignment: .leading, spacing: 8) {
                    if let promptSaveStatus {
                        Text(promptSaveStatus)
                            .font(ResponsiveFont.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if isCustomPromptTask {
                        TextField("AI task name", text: Binding(
                            get: { draftPromptTitle },
                            set: {
                                draftPromptTitle = $0
                                promptSaveStatus = nil
                                resetPromptTest()
                            }
                        ))
                        .font(ResponsiveFont.body.bold())
                        .textFieldStyle(.roundedBorder)

                        promptSubjectTypePicker(selection: Binding(
                            get: { draftPromptSubjectType },
                            set: {
                                draftPromptSubjectType = $0
                                promptSaveStatus = nil
                                resetPromptTest()
                            }
                        ))
                    }

                    TextEditor(text: Binding(
                        get: { draftPromptTemplate },
                        set: {
                            draftPromptTemplate = $0
                            promptSaveStatus = nil
                            resetPromptTest()
                        }
                    ))
                    .font(.system(size: 14, design: .monospaced))
                    .frame(minHeight: sizeClass == .compact ? 180 : 220)
                    .padding(8)
                    .background(RadixTheme.tertiaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    promptTemplateRevisionSection
                    promptEditorActions
                }
                .padding(.top, 10)
            } label: {
                Label("AI Prompt Template", systemImage: "slider.horizontal.3")
                    .font(ResponsiveFont.subheadline.weight(.semibold))
            }
            .padding(12)
            .background(RadixTheme.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    var promptEditorActions: some View {
        HStack(spacing: 6) {
            Button {
                savePromptDraft()
            } label: {
                Label("Save", systemImage: "checkmark.circle")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .font(ResponsiveFont.footnote.weight(.semibold))
            .disabled(!hasUnsavedPromptChanges)

            Button {
                resetPromptDraftToDefault()
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .font(ResponsiveFont.footnote.weight(.semibold))

            if isCustomPromptTask {
                Button(role: .destructive) {
                    deleteSelectedCustomPromptTask()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .font(ResponsiveFont.footnote.weight(.semibold))
            }
        }
    }

    var promptTemplateRevisionSection: some View {
        DisclosureGroup(isExpanded: $isPromptTemplateRevisionExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: Binding(
                    get: { promptTemplateChangeRequest },
                    set: {
                        promptTemplateChangeRequest = $0
                        promptTemplateRevisionMessage = nil
                    }
                ))
                .font(ResponsiveFont.footnote)
                .frame(minHeight: 76)
                .padding(8)
                .background(RadixTheme.tertiaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .topLeading) {
                    if promptTemplateChangeRequest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Describe the change you want.")
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 16)
                            .padding(.leading, 14)
                            .allowsHitTesting(false)
                    }
                }

                promptTemplateRevisionActions

                if !promptTemplateRevisionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    TextEditor(text: Binding(
                        get: { promptTemplateRevisionText },
                        set: {
                            promptTemplateRevisionText = $0
                            promptTemplateRevisionMessage = nil
                        }
                    ))
                    .font(.system(size: 13, design: .monospaced))
                    .frame(minHeight: 130)
                    .padding(8)
                    .background(RadixTheme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                if let promptTemplateRevisionMessage {
                    Text(promptTemplateRevisionMessage)
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 8)
        } label: {
            Label("Revise Template with AI", systemImage: "wand.and.stars")
                .font(ResponsiveFont.caption.weight(.semibold))
        }
        .padding(10)
        .background(RadixAccent.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    var promptTemplateRevisionActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                promptTemplateCopyRevisionPromptButton
                promptTemplateOpenRevisionPromptButton
                promptTemplatePasteRevisionButton
                promptTemplateApplyRevisionButton
            }

            VStack(alignment: .leading, spacing: 8) {
                promptTemplateCopyRevisionPromptButton
                promptTemplateOpenRevisionPromptButton
                promptTemplatePasteRevisionButton
                promptTemplateApplyRevisionButton
            }
        }
    }

    var promptTemplateCopyRevisionPromptButton: some View {
        Button {
            copyPromptTemplateRevisionPrompt(openInAI: false)
        } label: {
            Label("Copy to AI Chat", systemImage: "doc.on.doc")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(!canCopyPromptTemplateRevisionPrompt)
    }

    var promptTemplateOpenRevisionPromptButton: some View {
        Button {
            copyPromptTemplateRevisionPrompt(openInAI: true)
        } label: {
            Label("Open AI Chat", systemImage: "arrow.up.forward.app")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(!canCopyPromptTemplateRevisionPrompt)
    }

    var promptTemplatePasteRevisionButton: some View {
        Button {
            promptTemplateRevisionText = RadixPlatform.pasteboardString
            promptTemplateRevisionMessage = nil
        } label: {
            Label("Paste", systemImage: "doc.on.clipboard")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    var promptTemplateApplyRevisionButton: some View {
        Button {
            applyPromptTemplateRevision()
        } label: {
            Label("Apply to Draft", systemImage: "checkmark.circle")
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .disabled(promptTemplateRevisionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    var canCopyPromptTemplateRevisionPrompt: Bool {
        !draftPromptTemplate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !promptTemplateChangeRequest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func copyPromptTemplateRevisionPrompt(openInAI: Bool) {
        guard canCopyPromptTemplateRevisionPrompt else { return }
        let prompt = PromptTemplateRevision.revisionPrompt(
            taskTitle: draftPromptTitle,
            subjectType: draftPromptSubjectType,
            currentTemplate: draftPromptTemplate,
            changeRequest: promptTemplateChangeRequest
        )
        RadixPlatform.copyToPasteboard(prompt)
        promptTemplateRevisionMessage = "Template revision prompt copied."

        guard openInAI else { return }
        let preset = selectedAIPreset ?? store.defaultAIPreset
        if let url = store.aiURL(for: preset, prompt: prompt) {
            openURL(url)
            promptTemplateRevisionMessage = "Template revision prompt copied. Opening \(store.aiName(for: preset))."
        }
    }

    func applyPromptTemplateRevision() {
        let revised = PromptTemplateRevision.revisedTemplate(from: promptTemplateRevisionText)
        guard !revised.isEmpty else { return }
        draftPromptTemplate = revised
        promptSaveStatus = "Revised template applied to draft. Save when ready."
        promptTemplateRevisionMessage = "Applied to draft."
        promptTemplateRevisionText = ""
        resetPromptTest()
    }

    func promptSubjectTypePicker(selection: Binding<PromptTaskSubjectType>) -> some View {
        Menu {
            ForEach(PromptTaskSubjectType.allCases.filter { $0 != .practiceTopic }) { type in
                Button {
                    selection.wrappedValue = type
                } label: {
                    Label(
                        type.title,
                        systemImage: selection.wrappedValue == type ? "checkmark" : type.systemImage
                    )
                }
            }
        } label: {
            RadixMenuSelectorRow(
                icon: selection.wrappedValue.systemImage,
                title: "Subject",
                subtitle: selection.wrappedValue.title,
                minHeight: 44,
                titleFont: ResponsiveFont.subheadline.weight(.semibold)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Choose AI task subject")
    }

    var selectedTaskSourceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isSelectedTaskPageTask {
                aiSelectedPageRow
            } else if isSelectedTaskPracticeTopicTask {
                aiSelectedPracticeTopicRow
            } else if isSelectedTaskSentenceTask {
                aiSelectedSentenceRow
                aiSentenceSearchRow
            } else if isSelectedTaskFreeTextTask {
                aiFreeTextInputSection
            } else {
                aiSelectedSubjectRow
            }

            if selectedTaskSupportsConversationEntryCount {
                aiConversationEntryCountRow
            }

            if selectedTaskSupportsSentenceExtractionDetail {
                aiSentenceExtractionDetailRow
            }
        }
        .padding(12)
        .background(RadixTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    var aiConversationEntryCountRow: some View {
        Menu {
            ForEach(PromptConfig.conversationEntryCountOptions, id: \.self) { count in
                Button {
                    store.aiConversationEntryCount = count
                    store.persistPromptSettings()
                } label: {
                    Label(
                        "\(count) entries",
                        systemImage: count == store.aiConversationEntryCount ? "checkmark" : "list.number"
                    )
                }
            }
        } label: {
            RadixMenuSelectorRow(
                icon: "number",
                title: "Quantity",
                subtitle: "\(store.aiConversationEntryCount) entries"
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Choose AI conversation quantity")
    }

    var aiSentenceExtractionDetailRow: some View {
        Menu {
            ForEach(SentenceExtractionDetail.allCases) { detail in
                Button {
                    store.aiSentenceExtractionDetail = detail
                    store.persistPromptSettings()
                } label: {
                    Label(
                        detail.title,
                        systemImage: detail == store.aiSentenceExtractionDetail ? "checkmark" : "text.alignleft"
                    )
                }
            }
        } label: {
            RadixMenuSelectorRow(
                icon: "text.alignleft",
                title: "Detail",
                subtitle: store.aiSentenceExtractionDetail.title
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Choose sentence extraction detail")
    }

    var aiFreeTextInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label("Source Text", systemImage: "text.badge.plus")
                    .font(ResponsiveFont.subheadline.weight(.semibold))

                Spacer()

                Button {
                    store.aiFreeTextInput = RadixPlatform.pasteboardString
                    resetAIResultWorkflow()
                    resetPromptTest()
                } label: {
                    Label("Paste", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            TextEditor(text: Binding(
                get: { store.aiFreeTextInput },
                set: {
                    store.aiFreeTextInput = $0
                    resetAIResultWorkflow()
                    resetPromptTest()
                }
            ))
            .font(ResponsiveFont.body)
            .frame(minHeight: 140)
            .padding(8)
            .scrollContentBackground(.hidden)
            .background(RadixTheme.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(RadixTheme.separator, lineWidth: 1)
            )
        }
    }

    var aiSelectedSubjectRow: some View {
        Menu {
            if store.rootBreadcrumb.isEmpty {
                Text("No recent subjects")
            } else {
                Section("Recent Subjects") {
                    ForEach(store.rootBreadcrumb, id: \.self) { subject in
                        Button {
                            store.activateBreadcrumbCharacter(subject)
                        } label: {
                            Label(
                                subjectMenuTitle(subject),
                                systemImage: subject == activeCharacter ? "checkmark" : subjectIcon(subject)
                            )
                        }
                    }
                }
            }
        } label: {
            sourceSelectorLabel(
                icon: activeSubjectIcon,
                title: aiSubjectTitle,
                subtitle: aiSubjectSubtitle,
                isMissing: activeCharacter == nil
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Choose AI Subject")
    }

    var aiSelectedPageRow: some View {
        Menu {
            Button("Use latest viewed page") { store.selectAICollection(id: nil) }
            if !store.favoriteCollections.isEmpty {
                Section("Favorites") {
                    ForEach(store.favoriteCollections) { collection in
                        Button {
                            store.selectAICollection(id: collection.id)
                        } label: {
                            Label(
                                collection.name.isEmpty ? RadixCopy.savedPage : collection.name,
                                systemImage: collection.id == selectedCollection?.id ? "checkmark" : "photo.on.rectangle"
                            )
                        }
                    }
                }
            }
            if !store.allCollections.isEmpty {
                Section("All Pages") {
                    ForEach(store.allCollections) { collection in
                        Button {
                            store.selectAICollection(id: collection.id)
                        } label: {
                            Label(
                                collection.name.isEmpty ? RadixCopy.savedPage : collection.name,
                                systemImage: collection.id == selectedCollection?.id ? "checkmark" : "photo.on.rectangle"
                            )
                        }
                    }
                }
            }
        } label: {
            sourceSelectorLabel(
                icon: "photo.on.rectangle",
                title: selectedCollectionName,
                subtitle: aiCollectionSubtitle,
                isMissing: selectedCollection == nil
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Choose Saved Page")
    }

    var aiSelectedPracticeTopicRow: some View {
        Menu {
            let bundledTopics = ConversationPracticeTopic.defaults.filter(\.hasBundledContent)
            let generationTopics = ConversationPracticeTopic.defaults.filter { !$0.hasBundledContent }

            Section("Ready Practice Packs") {
                ForEach(bundledTopics) { topic in
                    aiPracticeTopicButton(topic)
                }
            }

            Section("Generate Broad Themes") {
                ForEach(generationTopics) { topic in
                    aiPracticeTopicButton(topic)
                }
            }
        } label: {
            sourceSelectorLabel(
                icon: "bubble.left.and.bubble.right",
                title: store.selectedConversationPracticeTopic.title,
                subtitle: store.selectedConversationPracticeTopic.summary,
                isMissing: false
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Choose Conversation Practice Topic")
    }

    var aiSelectedSentenceRow: some View {
        Menu {
            if let activePracticeSentenceItem = store.activePracticeSentenceItem {
                Section("Current Sentence") {
                    Button {
                        selectedAISentenceRecord = nil
                    } label: {
                        Label(
                            sentenceMenuTitle(
                                chinese: activePracticeSentenceItem.simplified,
                                english: activePracticeSentenceItem.english
                            ),
                            systemImage: selectedAISentenceRecord == nil ? "checkmark" : "quote.bubble"
                        )
                    }
                }
            }

            if aiSentencePickerRecords.isEmpty {
                Text(aiSentenceSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                     ? "No saved sentences"
                     : "No matches")
            } else {
                Section(sentencePickerSectionTitle) {
                    ForEach(aiSentencePickerRecords) { record in
                        Button {
                            selectedAISentenceRecord = record
                        } label: {
                            Label(
                                sentenceMenuTitle(
                                    chinese: record.chinese,
                                    english: record.english ?? ""
                                ),
                                systemImage: record.id == selectedAISentenceRecord?.id ? "checkmark" : "quote.bubble"
                            )
                        }
                    }
                }
            }
        } label: {
            sourceSelectorLabel(
                icon: "quote.bubble",
                title: activeSentenceTitle,
                subtitle: activeSentenceSubtitle,
                isMissing: activeSentenceItem == nil
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Choose AI sentence subject")
    }

    var aiSentenceSearchRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search saved sentences", text: $aiSentenceSearchText)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
            if !aiSentenceSearchText.isEmpty {
                Button {
                    aiSentenceSearchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Clear sentence search")
            }
        }
        .font(ResponsiveFont.subheadline)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RadixTheme.tertiaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    var sentencePickerSectionTitle: String {
        let count = aiSentencePickerResultCount
        let visible = aiSentencePickerRecords.count
        guard count > visible else { return "Saved Sentences" }
        return "Saved Sentences (\(visible) of \(count))"
    }

    func aiPracticeTopicButton(_ topic: ConversationPracticeTopic) -> some View {
        Button {
            store.selectedConversationPracticeTopicID = topic.id
            store.persistPromptSettings()
        } label: {
            Label(
                topic.title,
                systemImage: topic.id == store.selectedConversationPracticeTopic.id ? "checkmark" : "bubble.left.and.bubble.right"
            )
        }
    }

    func sourceSelectorLabel(icon: String, title: String, subtitle: String, isMissing: Bool) -> some View {
        RadixMenuSelectorRow(
            icon: icon,
            title: title,
            subtitle: subtitle,
            isMissing: isMissing
        )
    }

    func subjectIcon(_ subject: String) -> String {
        subject.count > 1 ? "text.quote" : "character"
    }

    func subjectMenuTitle(_ subject: String) -> String {
        if subject.count > 1,
           let phrase = store.mergedPhrase(for: subject) {
            let pinyin = phrase.pinyin.trimmingCharacters(in: .whitespacesAndNewlines)
            return pinyin.isEmpty ? phrase.word : "\(phrase.word)  \(pinyin)"
        }
        let pinyin = store.item(for: subject)?.pinyinText.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return pinyin.isEmpty ? subject : "\(subject)  \(pinyin)"
    }

    func sentenceMenuTitle(chinese: String, english: String) -> String {
        let cleanChinese = chinese.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEnglish = english.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanEnglish.isEmpty {
            return cleanChinese
        }
        return "\(cleanChinese)  \(cleanEnglish)"
    }

}
