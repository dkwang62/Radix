import SwiftUI

struct ManualBrowseCollectionSheet: View {
    @Binding var name: String
    @Binding var text: String
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Saved Page") {
                    TextField("Name", text: $name)
                    TextEditor(text: $text)
                        .frame(minHeight: 180)
                }

                Section {
                    Text("\(CaptureTextExtractor.uniqueCharacters(in: text).count) unique Chinese characters detected.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New Saved Page")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", action: onSave)
                        .disabled(CaptureTextExtractor.uniqueCharacters(in: text).isEmpty)
                }
            }
        }
    }
}

struct EditBrowseCollectionSheet: View {
    let collection: CharacterCollection
    @Binding var name: String
    @Binding var text: String
    let error: String?
    let onCancel: () -> Void
    let onSave: () -> Void

    @FocusState private var charactersFocused: Bool

    private var limitedName: Binding<String> {
        Binding(
            get: { name },
            set: { name = String($0.prefix(11)) }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Image") {
                    TextField("Name", text: limitedName)
                    Text("Maximum 11 characters.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Characters") {
                    TextEditor(text: $text)
                        .frame(minHeight: 140)
                        .focused($charactersFocused)
                    Text("Paste or type Chinese text here. Radix will keep the recognized characters for this saved page.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                }

                if let error {
                    Section {
                        Text(error)
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit Saved Page")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", action: onSave)
                }
            }
        }
    }
}

struct BrowseOCRReviewSheet: View {
    let instruction: String
    let aiName: String
    let message: String?
    let onOpenAI: () -> Void
    let onPasteAndCreate: () -> Void
    let onDone: () -> Void

    @State private var didOpenAI = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Why check it?") {
                    Text("Ask AI to spot likely capture mistakes. Radix will create a separate corrected page and keep this original unchanged.")
                }

                if !didOpenAI {
                    Section("1. Ask AI to check the OCR") {
                        Text("Open \(aiName). Radix copies the instruction for you.")
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.secondary)
                        ScrollView {
                            Text(instruction)
                                .font(.system(size: 13, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(minHeight: 80, maxHeight: 140)
                        Button("Open \(aiName)") {
                            didOpenAI = true
                            onOpenAI()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                Section(didOpenAI ? "Create the corrected page" : "2. Create the corrected page") {
                    Text(didOpenAI ? "Copy the AI answer, then paste it here." : "After the AI answers, copy its complete reply and paste it here.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                    Button("Paste Answer and Create Corrected Page", action: onPasteAndCreate)
                        .buttonStyle(.borderedProminent)
                }

                if let message {
                    Section {
                        Text(message)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Check OCR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done", action: onDone)
                }
            }
        }
        .frame(minWidth: 420, minHeight: 620)
    }
}
