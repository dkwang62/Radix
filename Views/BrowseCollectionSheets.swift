import SwiftUI

struct ManualBrowseCollectionSheet: View {
    @EnvironmentObject private var store: RadixStore
    @Binding var name: String
    @Binding var text: String
    let onCancel: () -> Void
    let onSave: () -> Void

    private var characterValidation: CaptureCharacterValidation {
        store.collectionCharacterValidation(for: text)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(RadixCopy.savedPage) {
                    TextField("Name (Optional)", text: $name)

                    Text("Chinese Text")
                        .font(ResponsiveFont.subheadline.weight(.semibold))

                    TextEditor(text: $text)
                        .frame(minHeight: 180)
                        .overlay(alignment: .topLeading) {
                            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("Paste or type Chinese text to enable Save.")
                                    .font(ResponsiveFont.body)
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                        }
                        .accessibilityLabel("Chinese text")
                        .accessibilityHint("Required. Paste or type Chinese text to enable Save.")
                }

                Section {
                    PageCharacterValidationSummary(validation: characterValidation)
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
                        .disabled(!characterValidation.hasChineseCharacters)
                }
            }
        }
    }
}

struct EditBrowseCollectionSheet: View {
    @EnvironmentObject private var store: RadixStore
    let collection: CharacterCollection
    @Binding var name: String
    @Binding var text: String
    let error: String?
    let onCancel: () -> Void
    let onSave: () -> Void

    @FocusState private var charactersFocused: Bool

    private var characterValidation: CaptureCharacterValidation {
        store.collectionCharacterValidation(for: text)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(RadixCopy.savedPage) {
                    TextField("Name", text: $name)
                }

                Section("Characters") {
                    TextEditor(text: $text)
                        .frame(minHeight: 140)
                        .focused($charactersFocused)
                    Text("Paste or type Chinese text here. Radix will keep the recognized characters for this saved page.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                    PageCharacterValidationSummary(validation: characterValidation)
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

private struct PageCharacterValidationSummary: View {
    let validation: CaptureCharacterValidation

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(validation.uniqueCharacters.count) unique Chinese characters detected.")
            if !validation.dictionaryUnsupportedCharacters.isEmpty {
                Text("\(validation.dictionaryUnsupportedCharacters.count) do not have Radix dictionary details. They will still be kept on this saved page.")
            }
        }
        .font(ResponsiveFont.caption)
        .foregroundStyle(.secondary)
    }
}
