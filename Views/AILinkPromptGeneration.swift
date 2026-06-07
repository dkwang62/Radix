import SwiftUI

extension AILinkView {
    var promptGenerationSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            taskSelectionSection
            promptBox
        }
    }

    var taskSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DisclosureGroup(isExpanded: $isTasksExpanded) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Choose what the AI should do.")
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 8)
                        Button {
                            store.selectAllPromptTasks()
                        } label: {
                            Label("All", systemImage: "checkmark.circle")
                        }
                        .buttonStyle(.bordered)
                        .font(ResponsiveFont.caption.bold())
                        .controlSize(.small)
                    }
                    .padding(.vertical, 4)

                    Divider()

                    ForEach(store.promptConfig.tasks) { task in
                        taskToggleRow(task)
                        if task.id != store.promptConfig.tasks.last?.id {
                            Divider().padding(.leading, 48)
                        }
                    }
                }
                .padding(.top, 10)
            } label: {
                HStack {
                    Image(systemName: "checklist")
                    Text("Instructions \(store.promptSelectedTaskIDs.count)/\(store.promptConfig.tasks.count)")
                        .font(ResponsiveFont.headline)
                }
            }
        }
        .padding()
        .background(RadixTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
