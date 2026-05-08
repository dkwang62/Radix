import SwiftUI

struct ManualBrowseCollectionSheet: View {
    @Binding var name: String
    @Binding var text: String
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Image") {
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
            .navigationTitle("New Image")
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
                    Text("Paste or type Chinese text here. Radix will keep the recognized characters for this saved image.")
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
            .navigationTitle("Edit Saved Image")
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
