import SwiftUI

struct AddExtractsToPhrasesPanel: View {
    let defaultAIName: String
    @Binding var output: String
    @Binding var message: String?
    @Binding var addedPhrases: [PhraseDiscoveryCandidate]
    let onAdd: () -> Void
    let onClear: () -> Void
    let onDeleteAddedPhrase: (PhraseDiscoveryCandidate) -> Void

    private var outputIsEmpty: Bool {
        output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Label("Import From AI", systemImage: RadixIcon.aiLink)
                    .font(ResponsiveFont.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                // Keep Add above the pasted AI answer. Long bulk imports can fill the
                // editor and trap iPhone/iPad users before they can scroll to a bottom action.
                Button {
                    onAdd()
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(outputIsEmpty)

                Button {
                    onClear()
                } label: {
                    Image(systemName: "xmark")
                        .font(ResponsiveFont.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(output.isEmpty && message == nil)
                .accessibilityLabel("Clear")
            }

            Text("Paste one phrase or a batch from \(defaultAIName).")
                .font(ResponsiveFont.caption2)
                .foregroundStyle(.secondary)

            phraseAnswerEditor

            if let message {
                Label(message, systemImage: addedPhrases.isEmpty ? "info.circle" : "checkmark.circle")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(addedPhrases.isEmpty ? Color.secondary : Color.green)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background((addedPhrases.isEmpty ? RadixTheme.secondaryBackground : Color.green.opacity(0.1)))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if !addedPhrases.isEmpty {
                AddedPhraseResultList(candidates: addedPhrases, onDelete: onDeleteAddedPhrase)
            }
        }
        .padding(10)
        .background(RadixTheme.secondaryBackground.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var phraseAnswerEditor: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8)
                .fill(RadixTheme.background)

            if outputIsEmpty {
                Text(Self.placeholderText)
                    .font(ResponsiveFont.tinySystem(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $output)
                .font(ResponsiveFont.tinySystem(size: 11))
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(Color.clear)
        }
        // Fixed height is intentional: large AI output should scroll inside this box
        // while the surrounding sheet keeps its Add action reachable.
        .frame(height: 150)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(RadixTheme.separator, lineWidth: 0.5)
        )
    }

    private static let placeholderText = """
    常年 | cháng nián | year-round; perennial
    性情 | xìng qíng | temperament; disposition
    情意 | qíng yì | affection; goodwill
    """
}

struct PhraseDiscoveryInputArea: View {
    let defaultAIName: String
    @Binding var output: String
    let hasCandidates: Bool
    let onAddFromBox: () -> Void
    let onPreviewAnswer: () -> Void
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void

    private var outputIsEmpty: Bool {
        output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Paste \(defaultAIName)'s answer here. Radix will add the phrases to My Phrases.")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $output)
                .font(ResponsiveFont.body)
                .frame(minHeight: 150)
                .padding(6)
                .background(RadixTheme.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(RadixTheme.separator, lineWidth: 0.5)
                )

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 120), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                Button("Add from Box", action: onAddFromBox)
                    .buttonStyle(.bordered)
                    .disabled(outputIsEmpty)

                Button("Preview Answer", action: onPreviewAnswer)
                    .buttonStyle(.bordered)
                    .disabled(outputIsEmpty)

                Button("Select All", action: onSelectAll)
                    .buttonStyle(.bordered)
                    .disabled(!hasCandidates)

                Button("Deselect All", action: onDeselectAll)
                    .buttonStyle(.bordered)
                    .disabled(!hasCandidates)
            }
        }
    }
}
