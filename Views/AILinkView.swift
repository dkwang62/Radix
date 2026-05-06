import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/*
 AI LINK VIEW
 ============
 Manages the generation of character-specific AI prompts for the user's default AI.
 Includes a built-in configuration editor for customizing global templates.
*/

struct AILinkView: View {
    @EnvironmentObject private var store: RadixStore
    @Environment(\.horizontalSizeClass) var sizeClass
    @Environment(\.openURL) private var openURL
    let item: ComponentItem?
    @State private var copied = false
    @State private var openedDefaultAI = false
    @State private var isTasksExpanded = true // Default to expanded for better usability
    @State private var isConfigExpanded = false

    /// The character or phrase word that tasks 1-3 will act on.
    /// Phrase preview takes priority over single character preview.
    private var activeCharacter: String? {
        if let phrase = store.activeSidebarPhrasePreview {
            return phrase.word
        }
        return item?.character ?? store.previewCharacter
    }

    private var selectedCollection: CharacterCollection? {
        store.selectedAICollection
    }

    private var hasCharacterTasks: Bool {
        store.promptSelectedTaskIDs.contains { $0 != "task4" }
    }

    private var hasCollectionTasks: Bool {
        store.promptSelectedTaskIDs.contains("task4")
    }

    private var canGeneratePrompt: Bool {
        (!hasCharacterTasks || activeCharacter != nil) &&
        (!hasCollectionTasks || selectedCollection != nil) &&
        (hasCharacterTasks || hasCollectionTasks)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if sizeClass == .compact, let item {
                    // 0. Active Character Context
                    standardPhoneCharacterPreview(
                        character: item.character,
                        onClear: { store.previewCharacter = nil }
                    )
                }

                taskSelectionSection

                configEditorSection

                promptBox
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
        }
    }

    // MARK: - Sub-Sections




    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AI Prompt Generator")
                .font(ResponsiveFont.title2.bold())
            Text("Create custom analytical prompts for character exploration.")
                .font(ResponsiveFont.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var taskSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DisclosureGroup(isExpanded: $isTasksExpanded) {
                VStack(alignment: .leading, spacing: 6) {
                    Button("Enable all tasks") {
                        store.selectAllPromptTasks()
                    }
                    .buttonStyle(.bordered)
                    .font(ResponsiveFont.subheadline)
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
                    Text("Tasks (\(store.promptSelectedTaskIDs.count)/\(store.promptConfig.tasks.count) active)")
                        .font(ResponsiveFont.headline)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func taskToggleRow(_ task: PromptTask) -> some View {
        let isEnabled = store.promptSelectedTaskIDs.contains(task.id)
        let isTask4 = task.id == "task4"
        let subject: (label: String, icon: String, isMissing: Bool) = taskSubjectInfo(task: task, isTask4: isTask4)

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
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(subject.isMissing ? Color.orange : Color.accentColor)

                        Text(subject.label)
                            .font(ResponsiveFont.caption.weight(.semibold))
                            .foregroundStyle(subject.isMissing ? Color.orange : Color.accentColor)
                            .lineLimit(1)

                        if isTask4 {
                            Spacer()
                            Menu {
                                Button("No Image") { store.selectAICollection(id: nil) }
                                if !store.favoriteCollections.isEmpty {
                                    Section("Favorites") {
                                        ForEach(store.favoriteCollections) { c in
                                            Button(c.name) { store.selectAICollection(id: c.id) }
                                        }
                                    }
                                }
                                if !store.allCollections.isEmpty {
                                    Section("All Images") {
                                        ForEach(store.allCollections) { c in
                                            Button(c.name) { store.selectAICollection(id: c.id) }
                                        }
                                    }
                                }
                            } label: {
                                Text("Change")
                                    .font(ResponsiveFont.caption2.weight(.semibold))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
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

    private func taskSubjectInfo(task: PromptTask, isTask4: Bool) -> (label: String, icon: String, isMissing: Bool) {
        if isTask4 {
            if let col = selectedCollection {
                return ("Image: \(col.name)", "tray.full", false)
            } else {
                return ("No image selected — choose one below", "exclamationmark.triangle", true)
            }
        } else {
            if let phrase = store.activeSidebarPhrasePreview {
                // Phrase in preview on any platform
                let pinyin = phrase.pinyin.trimmingCharacters(in: .whitespacesAndNewlines)
                let label = pinyin.isEmpty ? "Phrase: \(phrase.word)" : "Phrase: \(phrase.word)  \(pinyin)"
                return (label, "text.quote", false)
            } else if let char = activeCharacter {
                let pinyin = store.item(for: char)?.pinyinText ?? ""
                let label = pinyin.isEmpty ? "Character: \(char)" : "Character: \(char)  \(pinyin)"
                return (label, "character", false)
            } else {
                return ("No character selected", "exclamationmark.triangle", true)
            }
        }
    }

    private var configEditorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DisclosureGroup(isExpanded: $isConfigExpanded) {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("AI settings")
                            .font(ResponsiveFont.subheadline.bold())
                        Text("Task templates contain their own context. Tasks 1–3 run for a single character; Task 4 runs for a saved image.")
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.secondary)
                        Text(store.promptAutosaveStatus)
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Character System Epilogue")
                            .font(ResponsiveFont.subheadline.bold())
                        TextEditor(text: Binding(
                            get: { store.promptConfig.epilogue },
                            set: { store.setPromptEpilogue($0) }
                        ))
                        .font(.system(size: 14, design: .monospaced))
                        .frame(minHeight: 100)
                        .padding(8)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Image System Epilogue")
                            .font(ResponsiveFont.subheadline.bold())
                        TextEditor(text: Binding(
                            get: { store.promptConfig.collectionEpilogue },
                            set: { store.setCollectionPromptEpilogue($0) }
                        ))
                        .font(.system(size: 14, design: .monospaced))
                        .frame(minHeight: 140)
                        .padding(8)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Divider()

                    Text("Task Templates")
                        .font(ResponsiveFont.subheadline.bold())

                    ForEach(store.promptConfig.tasks) { task in
                        taskEditorRow(task: task)
                    }

                    HStack {
                        Button {
                            store.addPromptTask()
                        } label: {
                            Label("Add Task", systemImage: "plus.circle")
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Button("Reset Defaults", role: .destructive) {
                            store.resetPromptConfigToDefaults()
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    }

                }
                .padding(.top, 10)
            } label: {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                    Text("AI Template Editor")
                        .font(ResponsiveFont.headline)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func taskEditorRow(task: PromptTask) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Task Title", text: Binding(
                    get: { taskTitle(task.id) },
                    set: { store.setPromptTaskTitle(taskID: task.id, title: $0) }
                ))
                .font(ResponsiveFont.body.bold())
                .textFieldStyle(.plain)
                
                Spacer()
                
                Button(role: .destructive) {
                    store.removePromptTask(taskID: task.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                }
            }

            TextEditor(text: Binding(
                get: { taskTemplate(task.id) },
                set: { store.setPromptTaskTemplate(taskID: task.id, template: $0) }
            ))
            .font(.system(size: 13, design: .monospaced))
            .frame(minHeight: 120)
            .padding(6)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(10)
        .background(Color.accentColor.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var promptBox: some View {
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
                    .font(.system(size: 15, design: .monospaced)) // Slightly larger monospaced
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

    private var promptActions: some View {
        HStack(spacing: 12) {
            Button("Copy Prompt") {
                copyPromptToClipboard()
            }
            .buttonStyle(.bordered)
            .font(ResponsiveFont.headline)
            .disabled(!canGeneratePrompt)

            Button {
                openPromptInDefaultAI()
            } label: {
                Label("Open \(store.defaultAIName)", systemImage: "arrow.up.forward.app")
            }
            .buttonStyle(.borderedProminent)
            .font(ResponsiveFont.headline)
            .disabled(!canGeneratePrompt)

            if openedDefaultAI {
                Text(store.defaultAIPrefillsPrompt
                     ? "Opening \(store.defaultAIName). Prompt copied as backup."
                     : "Opening \(store.defaultAIName). Prompt copied. Paste it into \(store.defaultAIName).")
                    .font(ResponsiveFont.footnote)
                    .foregroundStyle(.secondary)
            } else if copied {
                Text("Copied. Paste into \(store.defaultAIName).")
                    .font(ResponsiveFont.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Logic

    private var generatedPromptText: String {
        if hasCollectionTasks && selectedCollection == nil {
            return "Choose an image for Task 4."
        }
        if hasCharacterTasks && activeCharacter == nil {
            return "Choose a character for Tasks 1-3."
        }
        let text = store.promptText(character: activeCharacter, collection: selectedCollection)
        return text.isEmpty ? "Choose at least one AI task." : text
    }

    private var promptContextLine: String? {
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
                parts.append("Task 4: \(selectedCollection.name)")
            } else {
                parts.append("Task 4: no image")
            }
        }

        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private func openPromptInDefaultAI() {
        guard canGeneratePrompt else { return }
        let text = generatedPromptText
        copyPromptToClipboard(showStatus: false)
        openedDefaultAI = true

        if let url = store.defaultAIURL(prompt: text) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                openURL(url)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
            openedDefaultAI = false
        }
    }

    private func copyPromptToClipboard() {
        copyPromptToClipboard(showStatus: true)
    }

    private func copyPromptToClipboard(showStatus: Bool) {
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

    private func taskTitle(_ id: String) -> String {
        store.promptConfig.tasks.first(where: { $0.id == id })?.title ?? ""
    }

    private func taskTemplate(_ id: String) -> String {
        store.promptConfig.tasks.first(where: { $0.id == id })?.template ?? ""
    }
}
