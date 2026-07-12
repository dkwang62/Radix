import SwiftUI

extension AILinkView {
    var promptGenerationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            taskSelectionSection
            selectedTaskSourceSection
            promptBox
            aiResultWorkflowSection
            selectedTaskTemplateSection
        }
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
                            }
                        ))
                        .font(ResponsiveFont.body.bold())
                        .textFieldStyle(.roundedBorder)
                    }

                    TextEditor(text: Binding(
                        get: { draftPromptTemplate },
                        set: {
                            draftPromptTemplate = $0
                            promptSaveStatus = nil
                        }
                    ))
                    .font(.system(size: 14, design: .monospaced))
                    .frame(minHeight: sizeClass == .compact ? 180 : 220)
                    .padding(8)
                    .background(RadixTheme.tertiaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

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
        }
    }

    var selectedTaskSourceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isSelectedTaskPageTask {
                aiSelectedPageRow
            } else if isSelectedTaskPracticeTopicTask {
                aiSelectedPracticeTopicRow
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

}
