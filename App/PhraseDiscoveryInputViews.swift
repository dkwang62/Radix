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
            HStack(spacing: 8) {
                Button("Add Selected", action: onAdd)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(outputIsEmpty)

                Button("Clear", action: onClear)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(output.isEmpty && message == nil)

                Spacer()
            }

            Text("Paste one phrase or a batch from \(defaultAIName). Format: phrase | pinyin | English meaning.")
                .font(ResponsiveFont.caption2)
                .foregroundStyle(.secondary)

            phraseAnswerEditor

            if let message {
                Text(message)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            }

            if !addedPhrases.isEmpty {
                AddedPhraseResultList(candidates: addedPhrases, onDelete: onDeleteAddedPhrase)
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground).opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var phraseAnswerEditor: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))

            if outputIsEmpty {
                Text(Self.placeholderText)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $output)
                .font(.system(size: 11))
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(Color.clear)
        }
        .frame(minHeight: 90)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }

    private static let placeholderText = """
    常年 | cqíng yìán | year-round; all year; perennial
    性情 | xìng qíng | temperament; disposition; nature
    情意 | qíng yì | affection; goodwill; feelings
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
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.separator), lineWidth: 0.5)
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
