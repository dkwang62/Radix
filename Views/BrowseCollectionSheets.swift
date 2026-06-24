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
    @Binding var response: String
    let message: String?
    let onCopyInstruction: () -> Void
    let onCopyImage: () -> Void
    let onOpenAI: () -> Void
    let onPaste: () -> Void
    let onApply: (String) -> Void
    let onDone: () -> Void

    private var proposal: OCRReviewProposal? {
        OCRReviewParser.parse(response)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Why check it?") {
                    Text("OCR mistakes can weaken phrase extraction and translation. ChatGPT proposes corrections, but Radix keeps the original and changes nothing until you approve.")
                }

                Section("1. Send to ChatGPT") {
                    Text("Copy the instruction. If the page has an image, copy it separately and paste it into the same ChatGPT conversation.")
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

                Section("2. Paste ChatGPT’s answer") {
                    TextEditor(text: $response)
                        .font(.system(size: 14, design: .monospaced))
                        .frame(minHeight: 140)
                    Button("Paste Answer", action: onPaste)
                }

                if let proposal {
                    Section("3. Review proposed text") {
                        comparison(title: "Original OCR", text: collection.originalOCRText ?? collection.characters.joined())
                        comparison(title: "Proposed correction", text: proposal.correctedText)
                        if !proposal.changes.isEmpty {
                            comparison(title: "Changes and confidence", text: proposal.changes)
                        }
                        if !proposal.uncertainties.isEmpty {
                            comparison(title: "Still uncertain", text: proposal.uncertainties)
                        }
                        Button("Apply Corrected Text") {
                            onApply(proposal.correctedText)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if !response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section {
                        Text("Radix could not read the answer. Ask ChatGPT to keep the required [[CORRECTED TEXT]], [[CHANGES]], and [[UNCERTAIN]] headings.")
                            .foregroundStyle(.orange)
                    }
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
        Button("Open ChatGPT", action: onOpenAI)
    }

    private func comparison(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(ResponsiveFont.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
