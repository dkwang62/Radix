import SwiftUI

extension AILinkView {
    var promptGenerationSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            taskSelectionSection
            selectedTaskTemplateSection
            selectedTaskSourceSection
            promptBox
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
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 30, height: 30)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 7))

                    Text(selectedPromptTask?.title ?? "Choose AI Task")
                        .font(ResponsiveFont.body.bold())
                        .lineLimit(1)
                        .layoutPriority(1)

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 48)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RadixTheme.background)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor.opacity(0.45), lineWidth: 1)
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
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 8) {
                    Text("AI Prompt")
                        .font(ResponsiveFont.headline)

                    Spacer()

                    if let promptSaveStatus {
                        Text(promptSaveStatus)
                            .font(ResponsiveFont.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Button {
                        savePromptDraft()
                    } label: {
                        Label("Save Prompt", systemImage: "checkmark.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(!hasUnsavedPromptChanges)

                    Button {
                        resetPromptDraftToDefault()
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                TextField("AI prompt title", text: Binding(
                    get: { draftPromptTitle },
                    set: {
                        draftPromptTitle = $0
                        promptSaveStatus = nil
                    }
                ))
                .font(ResponsiveFont.body.bold())
                .textFieldStyle(.roundedBorder)

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
            }
            .padding()
            .background(RadixTheme.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    var selectedTaskSourceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isSelectedTaskPageTask ? "Page" : "Subject")
                .font(ResponsiveFont.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if isSelectedTaskPageTask {
                aiSelectedPageRow
            } else {
                aiSelectedSubjectRow
            }
        }
        .padding()
        .background(RadixTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    var aiSelectedSubjectRow: some View {
        HStack(spacing: 10) {
            Image(systemName: store.activeSidebarPhrasePreview == nil ? "character" : "text.quote")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(activeCharacter == nil ? Color.orange : Color.accentColor)
                .frame(width: 28, height: 28)
                .background((activeCharacter == nil ? Color.orange : Color.accentColor).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 2) {
                Text(aiSubjectTitle)
                    .font(ResponsiveFont.body.bold())
                    .lineLimit(1)
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
                Label("Change", systemImage: "magnifyingglass")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    var aiSelectedPageRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(selectedCollection == nil ? Color.orange : Color.accentColor)
                .frame(width: 28, height: 28)
                .background((selectedCollection == nil ? Color.orange : Color.accentColor).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 2) {
                Text(selectedCollection?.name ?? "No page selected")
                    .font(ResponsiveFont.body.bold())
                    .lineLimit(1)
                Text(aiCollectionSubtitle)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .layoutPriority(1)

            Spacer(minLength: 0)

            aiCollectionMenu
        }
    }

    @ViewBuilder
    func taskToggleRow(_ task: PromptTask) -> some View {
        let isEnabled = store.promptSelectedTaskIDs.contains(task.id)
        let isCollectionTask = PromptConfig.collectionTaskIDs.contains(task.id)
        let subject: (label: String, icon: String, isMissing: Bool) = taskSubjectInfo(task: task, isCollectionTask: isCollectionTask)

        Toggle(isOn: Binding(
            get: { isEnabled },
            set: { store.setPromptTask(task.id, enabled: $0) }
        )) {
            VStack(alignment: .leading, spacing: 6) {
                Text(task.title)
                    .font(ResponsiveFont.subheadline.bold())
                    .foregroundStyle(isEnabled ? .primary : .secondary)

                Text(taskExplanation(task))
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if isEnabled {
                    HStack(spacing: 6) {
                        Image(systemName: subject.icon)
                            .font(ResponsiveFont.tinySystem(size: 11, weight: .semibold))
                            .foregroundStyle(subject.isMissing ? Color.orange : Color.accentColor)

                        Text(subject.label)
                            .font(ResponsiveFont.caption.weight(.semibold))
                            .foregroundStyle(subject.isMissing ? Color.orange : Color.accentColor)
                            .lineLimit(1)

                        if isCollectionTask {
                            Spacer()
                            aiCollectionMenu
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(subject.isMissing ? Color.orange.opacity(0.12) : Color.accentColor.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                }
            }
        }
        .padding(.vertical, 6)
    }

    func taskExplanation(_ task: PromptTask) -> String {
        switch task.id {
        case "task1":
            return "Explain meaning, structure, modern usage, and why the character appears in compounds."
        case "task2":
            return "Show natural examples that reveal how the character is actually used."
        case "task3":
            return "Compare related ideas so subtle differences are easier to understand."
        case "task4":
            return "Find useful expressions in page text that you can review and keep in Radix."
        case "task5":
            return "Translate the complete page in context, including shorthand, tone, subtext, and newer usage."
        case "task7":
            return "Compare page OCR with its source image and Radix evidence, then propose clearly marked corrections for review."
        case "task8":
            return "Create a practice quiz from a saved page, with difficulty guidance and answers hidden until the learner responds."
        default:
            return "Use this reusable AI prompt to investigate the selected material with AI."
        }
    }

    var aiCollectionMenu: some View {
        Menu {
            Button("None") { store.selectAICollection(id: nil) }
            if !store.favoriteCollections.isEmpty {
                Section("Favorites") {
                    ForEach(store.favoriteCollections) { collection in
                        Button(collection.name) { store.selectAICollection(id: collection.id) }
                    }
                }
            }
            if !store.allCollections.isEmpty {
                Section("All Pages") {
                    ForEach(store.allCollections) { collection in
                        Button(collection.name) { store.selectAICollection(id: collection.id) }
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 16, weight: .semibold))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityLabel("Choose Saved Page")
    }

    func taskSubjectInfo(task: PromptTask, isCollectionTask: Bool) -> (label: String, icon: String, isMissing: Bool) {
        if isCollectionTask {
            if let collection = selectedCollection {
                let name = collection.name.trimmingCharacters(in: .whitespacesAndNewlines)
                return (name.isEmpty ? "Page" : name, "tray.full", false)
            } else {
                return ("Choose page", "exclamationmark.triangle", true)
            }
        } else {
            if let phrase = store.activeSidebarPhrasePreview {
                let pinyin = phrase.pinyin.trimmingCharacters(in: .whitespacesAndNewlines)
                let label = pinyin.isEmpty ? phrase.word : "\(phrase.word)  \(pinyin)"
                return (label, "text.quote", false)
            } else if let char = activeCharacter {
                let pinyin = store.item(for: char)?.pinyinText ?? ""
                let label = pinyin.isEmpty ? char : "\(char)  \(pinyin)"
                return (label, "character", false)
            } else {
                return ("Choose character", "exclamationmark.triangle", true)
            }
        }
    }
}
