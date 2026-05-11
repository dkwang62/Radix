import SwiftUI

struct PhraseDiscoveryImportContent: View {
    let parserSource: PhraseParserSource
    let defaultAIName: String
    let parserInputCount: Int
    let rawText: String
    let workflowSteps: [CaptureWorkflowStep]
    let canBuildPrompt: Bool
    let promptCopied: Bool
    @Binding var output: String
    let candidates: [PhraseDiscoveryCandidate]
    let candidateBinding: (PhraseDiscoveryCandidate) -> Binding<PhraseDiscoveryCandidate>
    let addedPhrases: [PhraseDiscoveryCandidate]
    let summarySourceTitle: String
    let summarySourceCount: Int
    let stats: PhraseDiscoveryStats
    let message: String?
    let onOpenPrompt: () -> Void
    let onPasteAndAdd: () -> Void
    let onClear: () -> Void
    let onAddFromBox: () -> Void
    let onPreviewAnswer: () -> Void
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void
    let onImportSelected: () -> Void
    let onDeleteAddedPhrase: (PhraseDiscoveryCandidate) -> Void

    private var outputIsEmpty: Bool {
        output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var selectedCount: Int {
        candidates.filter(\.isSelected).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CaptureWorkflowProgressView(steps: workflowSteps)

            guidanceCard

            if !rawText.isEmpty {
                ocrPreview
            }

            promptActions

            if promptCopied && outputIsEmpty && candidates.isEmpty {
                ProgressView("Waiting for \(defaultAIName) answer...")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            }

            PhraseDiscoveryInputArea(
                defaultAIName: defaultAIName,
                output: $output,
                hasCandidates: !candidates.isEmpty,
                onAddFromBox: onAddFromBox,
                onPreviewAnswer: onPreviewAnswer,
                onSelectAll: onSelectAll,
                onDeselectAll: onDeselectAll
            )

            PhraseDiscoverySummaryGrid(
                sourceTitle: summarySourceTitle,
                sourceCount: summarySourceCount,
                stats: stats,
                newCount: candidates.count,
                selectedCount: selectedCount
            )

            if !candidates.isEmpty {
                PhraseDiscoveryCandidateList(candidates: candidates, binding: candidateBinding)
            }

            if !addedPhrases.isEmpty {
                AddedPhraseResultList(candidates: addedPhrases, onDelete: onDeleteAddedPhrase)
            }

            HStack {
                Spacer()
                Button("Add Selected to My Phrases", action: onImportSelected)
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedCount == 0)
            }

            if let message {
                Text(message)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var guidanceCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(parserSource.guidanceTitle(defaultAIName: defaultAIName))
                .font(ResponsiveFont.caption.weight(.semibold))
            Text(parserSource.guidanceDetail(count: parserInputCount, defaultAIName: defaultAIName))
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var ocrPreview: some View {
        DisclosureGroup("OCR Text Preview") {
            Text(rawText)
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .font(ResponsiveFont.caption.weight(.semibold))
    }

    private var promptActions: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 150), spacing: 8)],
            alignment: .leading,
            spacing: 8
        ) {
            Button("Open \(defaultAIName)", action: onOpenPrompt)
                .buttonStyle(.borderedProminent)
                .disabled(!canBuildPrompt)

            Button(action: onPasteAndAdd) {
                Label("Paste \(defaultAIName) Answer and Add", systemImage: "doc.on.clipboard")
            }
            .buttonStyle(.bordered)

            Button("Clear", action: onClear)
                .buttonStyle(.bordered)
                .disabled(output.isEmpty && candidates.isEmpty)
        }
    }
}
