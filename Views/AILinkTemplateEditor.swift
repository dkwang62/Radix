import SwiftUI

extension AILinkView {
    var templateEditorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Customize the repeatable AI actions. Character actions use one character or phrase; page actions use a saved page.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                Text(store.promptAutosaveStatus)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            epilogueEditor(
                title: "Character Instruction Closing",
                minHeight: 100,
                text: Binding(
                    get: { store.promptConfig.epilogue },
                    set: { store.setPromptEpilogue($0) }
                )
            )

            Divider()

            epilogueEditor(
                title: "Saved Page Instruction Closing",
                minHeight: 140,
                text: Binding(
                    get: { store.promptConfig.collectionEpilogue },
                    set: { store.setCollectionPromptEpilogue($0) }
                )
            )

            Divider()

            HStack {
                Text("AI Link Templates")
                    .font(ResponsiveFont.subheadline.bold())

                Spacer()

                Button {
                    store.addPromptTask()
                } label: {
                    Label("Instruction", systemImage: "plus.circle")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel("Add Instruction")
            }

            ForEach(store.promptConfig.tasks) { task in
                taskEditorRow(task: task)
            }

            HStack {
                Spacer()

                Button("Reset Defaults", role: .destructive) {
                    store.resetPromptConfigToDefaults()
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }
        }
        .padding()
        .background(RadixTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    func epilogueEditor(title: String, minHeight: CGFloat, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(ResponsiveFont.subheadline.bold())
            TextEditor(text: text)
                .font(.system(size: 14, design: .monospaced))
                .frame(minHeight: minHeight)
                .padding(8)
                .background(RadixTheme.tertiaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    func taskEditorRow(task: PromptTask) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Instruction Title", text: Binding(
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
            .background(RadixTheme.tertiaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(10)
        .background(Color.accentColor.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    func taskTitle(_ id: String) -> String {
        store.promptConfig.tasks.first(where: { $0.id == id })?.title ?? ""
    }

    func taskTemplate(_ id: String) -> String {
        store.promptConfig.tasks.first(where: { $0.id == id })?.template ?? ""
    }
}
