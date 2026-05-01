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
                openPromptInDefaultAI()
            }
        }
    }

    // MARK: - Sub-Sections

    private var collectionSelectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Image for Task 4")
                        .font(ResponsiveFont.subheadline.bold())
                    Text(selectedCollectionDescription)
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                aiCollectionMenu
            }

            if let selectedCollection {
                HStack(spacing: 8) {
                    Text("📄")
                    Text("\(selectedCollection.name) (\(selectedCollection.characters.count) characters)")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                }
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
            return hasCollectionTasks ? "Choose the image you want to use for Task 4." : "Choose the image you want to use for Task 4."
        }
        return "Task 4 will use the selected image, not the selected character."
    }

    private var aiCollectionMenu: some View {
        Menu {
            Button("No Image") {
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
                Section("Images") {
                    ForEach(store.allCollections) { collection in
                        Button(collection.name) {
                            store.selectAICollection(id: collection.id)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text("📄")
                Text("Choose Image")
                    .lineLimit(1)
            }
        }
        .buttonStyle(.borderedProminent)
    }

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
        if hasCharacterTasks && selectedCharacter == nil {
            return "Choose a character for Tasks 1-3."
        }
        let text = store.promptText(character: selectedCharacter, collection: selectedCollection)
        return text.isEmpty ? "Choose at least one AI task." : text
    }

    private var promptContextLine: String? {
        var parts: [String] = []

        if hasCharacterTasks {
            if let selectedCharacter {
                parts.append("Tasks 1-3: \(selectedCharacter)")
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
