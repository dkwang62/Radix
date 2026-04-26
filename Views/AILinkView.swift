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
    let item: ComponentItem
    @State private var copied = false
    @State private var openedChatGPT = false
    @State private var isTasksExpanded = true // Default to expanded for better usability
    @State private var isConfigExpanded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if sizeClass == .compact {
                    // 0. Active Character Context
                    standardPhoneCharacterPreview(
                        character: item.character,
                        selectedCharacter: store.selectedCharacter,
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
                openPromptInChatGPT()
            }
        }
    }

    // MARK: - Sub-Sections

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
                        Text("Global AI settings")
                            .font(ResponsiveFont.subheadline.bold())
                        Text("These templates shape AI Link across the whole app. They are intentionally managed here, next to prompt generation, rather than in My Data.")
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("System Preamble")
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

                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("System Epilogue")
                            .font(ResponsiveFont.subheadline.bold())
                        TextEditor(text: Binding(
                            get: { store.promptConfig.epilogue },
                            set: { store.setPromptEpilogue($0) }
                        ))
                        .font(.system(size: 14, design: .monospaced))
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
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
                Text(store.promptText(for: item.character))
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

            Button {
                openPromptInChatGPT()
            } label: {
                Label("Open ChatGPT", systemImage: "arrow.up.forward.app")
            }
            .buttonStyle(.borderedProminent)
            .font(ResponsiveFont.headline)

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

    private func openPromptInChatGPT() {
        let text = store.promptText(for: item.character)
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
        let text = store.promptText(for: item.character)
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
