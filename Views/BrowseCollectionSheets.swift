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
    let collection: CharacterCollection
    let instruction: String
    let aiName: String
    let message: String?
    let onCopyInstruction: () -> Void
    let onCopyImage: () -> Void
    let onOpenAI: () -> Void
    let onPasteAndCreate: () -> Void
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Why check it?") {
                    Text("OCR mistakes can weaken phrase extraction and translation. Radix creates a corrected Browse page from the AI answer while keeping the original OCR page unchanged.")
                }

                Section("1. Ask AI to check the OCR") {
                    Text("Copy the instruction into \(aiName) or another AI app. If the page has an image, copy it separately and paste it into the same conversation.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                    ScrollView {
                        Text(instruction)
                            .font(.system(size: 13, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 110, maxHeight: 180)
                    ocrReviewActionButtons
                }

                Section("2. Create the corrected page") {
                    Text("When the AI finishes, copy its complete answer. Radix will create and open the corrected page immediately.")
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

    private var ocrReviewActionButtons: some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                actionButtonContent
            }
            VStack(alignment: .leading) {
                actionButtonContent
            }
        }
    }

    @ViewBuilder
    private var actionButtonContent: some View {
        Button("Copy Instruction", action: onCopyInstruction)
        if collection.sourceImageJPEGData != nil || collection.thumbnailJPEGData != nil {
            Button("Copy Image", action: onCopyImage)
        }
        Button("Open \(aiName)", action: onOpenAI)
    }

}
