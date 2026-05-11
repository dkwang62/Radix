import SwiftUI

extension QuickCharacterEditorView {
    var newCharacterPrompt: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Enter the Chinese character you want to add:")
                .font(ResponsiveFont.body)
                .foregroundStyle(.secondary)

            TextField("Single Chinese character", text: $characterInput)
                .font(.system(size: 36))
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
                .frame(width: 100)

            if let editorError {
                Text(editorError)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.red)
            }

            Button("Open") {
                openNewCharacter()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canOpenCharacter)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    func openNewCharacter() {
        let key = trimmedCharacterInput
        guard key.count == 1 else {
            editorError = "Enter exactly one Chinese character."
            return
        }
        do {
            try store.createCustomDictionaryEntry(character: key)
            editorError = nil
            isLoaded = true
        } catch {
            editorError = error.localizedDescription
        }
    }
}
