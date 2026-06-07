import SwiftUI

struct DataAITemplatesSection: View {
    @EnvironmentObject private var store: RadixStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label {
                Text("3. AI Link Templates")
                    .font(ResponsiveFont.headline)
            } icon: {
                Image(systemName: RadixIcon.aiLink)
            }
            .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 12) {
                Text(store.promptAutosaveStatus)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)

                promptSystemEditorsSection

                ForEach(store.promptConfig.tasks) { task in
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Instruction Title", text: Binding(
                                get: { store.promptConfig.tasks.first(where: { $0.id == task.id })?.title ?? "" },
                                set: { store.setPromptTaskTitle(taskID: task.id, title: $0) }
                            ))
                            .font(ResponsiveFont.body)
                            .textFieldStyle(.roundedBorder)

                            TextEditor(text: Binding(
                                get: { store.promptConfig.tasks.first(where: { $0.id == task.id })?.template ?? "" },
                                set: { store.setPromptTaskTemplate(taskID: task.id, template: $0) }
                            ))
                            .font(ResponsiveFont.body)
                            .frame(height: 150)
                            .padding(6)
                            .background(RadixTheme.background)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .padding(.vertical, 4)
                    } label: {
                        Text(task.title)
                            .font(ResponsiveFont.subheadline)
                    }
                }
            }
        }
        .padding()
        .background(RadixTheme.secondaryBackground.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var promptSystemEditorsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            promptTextEditor(
                label: "Character Instruction Opening",
                text: Binding(get: { store.promptConfig.preamble }, set: { store.setPromptPreamble($0) }),
                height: 120
            )
            promptTextEditor(
                label: "Character Instruction Closing",
                text: Binding(get: { store.promptConfig.epilogue }, set: { store.setPromptEpilogue($0) }),
                height: 100
            )
            promptTextEditor(
                label: "Image Instruction Opening",
                text: Binding(get: { store.promptConfig.collectionPreamble }, set: { store.setCollectionPromptPreamble($0) }),
                height: 120
            )
            promptTextEditor(
                label: "Image Instruction Closing",
                text: Binding(get: { store.promptConfig.collectionEpilogue }, set: { store.setCollectionPromptEpilogue($0) }),
                height: 100
            )
        }
    }

    private func promptTextEditor(label: String, text: Binding<String>, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(ResponsiveFont.caption.bold())
            TextEditor(text: text)
                .font(ResponsiveFont.body)
                .frame(height: height)
                .padding(6)
                .background(RadixTheme.background)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
