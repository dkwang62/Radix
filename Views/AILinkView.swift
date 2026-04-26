import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/*
 AI LINK VIEW
 ============
 Manages the generation of character-specific AI prompts for ChatGPT.
 Includes a built-in configuration editor for customizing global templates.
*/

struct AILinkView: View {
    @EnvironmentObject private var store: RadixStore
    @Environment(\.horizontalSizeClass) var sizeClass
    @Environment(\.openURL) private var openURL
    let item: ComponentItem?
    @State private var copied = false
    @State private var openedChatGPT = false
    @State private var isTasksExpanded = true // Default to expanded for better usability
    @State private var isConfigExpanded = false

    private var selectedCharacter: String? {
        item?.character ?? store.previewCharacter ?? store.selectedCharacter
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
        (!hasCharacterTasks || selectedCharacter != nil) &&
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
                        selectedCharacter: store.selectedCharacter,
                        onClear: { store.previewCharacter = nil }
                    )
                }

                activeSubjectHeader

                collectionSelectionSection

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
                openPromptInChatGPT()
            }
        }
    }

    // MARK: - Sub-Sections

    private var activeSubjectHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("AI Subjects")
                .font(ResponsiveFont.headline)
            Text(activeSubjectDetail)
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var activeSubjectDetail: String {
        let characterText = selectedCharacter.map { "Character: \($0)" } ?? "Character: none"
        let collectionText = selectedCollection.map { "Page: \($0.name) (\($0.characters.count) characters)" } ?? "Page: none"
        return "\(characterText)\n\(collectionText)"
    }

    private var collectionSelectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Page for Task 4")
                        .font(ResponsiveFont.subheadline.bold())
                    Text(selectedCollectionDescription)
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                aiCollectionMenu
            }

            if !store.favoriteCollections.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(store.favoriteCollections) { collection in
                            Button {
                                store.selectAICollection(id: collection.id)
                            } label: {
                                Label(collection.name, systemImage: "star.fill")
                                    .lineLimit(1)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var selectedCollectionDescription: String {
        guard let selectedCollection else {
            return hasCollectionTasks ? "Choose a page before copying or opening Task 4." : "Task 4 will use the page selected here."
        }
        return "Task 4 will use \(selectedCollection.name), not the selected character."
    }

    private var aiCollectionMenu: some View {
        Menu {
            Button("No Page") {
                store.selectAICollection(id: nil)
            }
            if !store.favoriteCollections.isEmpty {
                Section("Favorites") {
                    ForEach(store.favoriteCollections) { collection in
                        Button(collection.name) {
                            store.selectAICollection(id: collection.id)
                        }
                    }
                }
            }
            if !store.allCollections.isEmpty {
                Section("Pages") {
                    ForEach(store.allCollections) { collection in
                        Button(collection.name) {
                            store.selectAICollection(id: collection.id)
                        }
                    }
                }
            }
        } label: {
            Label(selectedCollection?.name ?? "Choose", systemImage: "rectangle.stack")
                .lineLimit(1)
        }
        .buttonStyle(.borderedProminent)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ChatGPT Prompt Generator")
                .font(ResponsiveFont.title2.bold())
            Text("Create custom analytical prompts for character exploration.")
                .font(ResponsiveFont.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var taskSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DisclosureGroup(isExpanded: $isTasksExpanded) {
                VStack(alignment: .leading, spacing: 10) {
                    Button("Enable all tasks") {
                        store.selectAllPromptTasks()
                    }
                    .buttonStyle(.bordered)
                    .font(ResponsiveFont.subheadline)
                    .padding(.vertical, 4)

                    Divider()

                    ForEach(store.promptConfig.tasks) { task in
                        Toggle(isOn: Binding(
                            get: { store.promptSelectedTaskIDs.contains(task.id) },
                            set: { store.setPromptTask(task.id, enabled: $0) }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.title)
                                    .font(ResponsiveFont.body.bold())
                                Text(task.id)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.top, 10)
            } label: {
                HStack {
                    Image(systemName: "checklist")
                    Text("Prompt Tasks (\(store.promptSelectedTaskIDs.count) active)")
                        .font(ResponsiveFont.headline)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var configEditorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DisclosureGroup(isExpanded: $isConfigExpanded) {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("AI settings")
                            .font(ResponsiveFont.subheadline.bold())
                        Text("Character and page prompts use different system text, so Task 4 is not wrapped in single-character wording.")
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Character System Preamble")
                            .font(ResponsiveFont.subheadline.bold())
                        TextEditor(text: Binding(
                            get: { store.promptConfig.preamble },
                            set: { store.setPromptPreamble($0) }
                        ))
                        .font(.system(size: 14, design: .monospaced))
                        .frame(minHeight: 150)
                        .padding(8)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
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
                        Text("Page System Preamble")
                            .font(ResponsiveFont.subheadline.bold())
                        TextEditor(text: Binding(
                            get: { store.promptConfig.collectionPreamble },
                            set: { store.setCollectionPromptPreamble($0) }
                        ))
                        .font(.system(size: 14, design: .monospaced))
                        .frame(minHeight: 140)
                        .padding(8)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Page System Epilogue")
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

            Text("Generated Prompt")
                .font(ResponsiveFont.subheadline)
                .foregroundStyle(.secondary)
            
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
                openPromptInChatGPT()
            } label: {
                Label("Open ChatGPT", systemImage: "arrow.up.forward.app")
            }
            .buttonStyle(.borderedProminent)
            .font(ResponsiveFont.headline)
            .disabled(!canGeneratePrompt)

            if openedChatGPT {
                Text("Opening ChatGPT. Prompt copied as backup.")
                    .font(ResponsiveFont.footnote)
                    .foregroundStyle(.secondary)
            } else if copied {
                Text("Copied. Paste into ChatGPT.")
                    .font(ResponsiveFont.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Logic

    private var generatedPromptText: String {
        if hasCollectionTasks && selectedCollection == nil {
            return "Choose a page for Task 4."
        }
        if hasCharacterTasks && selectedCharacter == nil {
            return "Choose a character for Tasks 1-3."
        }
        let text = store.promptText(character: selectedCharacter, collection: selectedCollection)
        return text.isEmpty ? "Choose at least one AI task." : text
    }

    private func openPromptInChatGPT() {
        guard canGeneratePrompt else { return }
        let text = generatedPromptText
        copyPromptToClipboard(showStatus: false)

        if let url = chatGPTURL(prompt: text) {
            openURL(url)
        }

        openedChatGPT = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            openedChatGPT = false
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

    private func chatGPTURL(prompt: String) -> URL? {
        var components = URLComponents(string: "https://chatgpt.com/")
        components?.queryItems = [
            URLQueryItem(name: "q", value: prompt)
        ]
        return components?.url
    }

    private func taskTitle(_ id: String) -> String {
        store.promptConfig.tasks.first(where: { $0.id == id })?.title ?? ""
    }

    private func taskTemplate(_ id: String) -> String {
        store.promptConfig.tasks.first(where: { $0.id == id })?.template ?? ""
    }
}
