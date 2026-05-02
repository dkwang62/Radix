import SwiftUI

struct PhraseDiscoverySummaryGrid: View {
    let sourceTitle: String
    let sourceCount: Int
    let stats: PhraseDiscoveryStats
    let newCount: Int
    let selectedCount: Int

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 130), spacing: 8)],
            alignment: .leading,
            spacing: 8
        ) {
            DiscoveryStatChip(title: sourceTitle, value: sourceCount)
            DiscoveryStatChip(title: "Read", value: stats.totalParsed)
            DiscoveryStatChip(title: "Duplicates", value: stats.duplicatesRemoved)
            DiscoveryStatChip(title: "Existing", value: stats.alreadyExisting)
            DiscoveryStatChip(title: "Invalid", value: stats.invalidLines)
            DiscoveryStatChip(title: "New", value: newCount)
            DiscoveryStatChip(title: "Selected", value: selectedCount)
        }
    }
}

struct CaptureWorkflowProgressView: View {
    let steps: [CaptureWorkflowStep]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add Phrases Steps")
                .font(ResponsiveFont.caption.bold())
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 118), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(steps) { step in
                    CaptureWorkflowStepChip(step: step)
                }
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground).opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct PhraseDiscoveryCandidateList: View {
    let candidates: [PhraseDiscoveryCandidate]
    let binding: (PhraseDiscoveryCandidate) -> Binding<PhraseDiscoveryCandidate>

    var body: some View {
        VStack(spacing: 0) {
            ForEach(candidates) { candidate in
                PhraseDiscoveryCandidateRow(candidate: binding(candidate))
                Divider()
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct AddedPhraseResultList: View {
    let candidates: [PhraseDiscoveryCandidate]
    let onDelete: (PhraseDiscoveryCandidate) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Added to My Phrases")
                .font(ResponsiveFont.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                ForEach(candidates) { candidate in
                    AddedPhraseResultRow(candidate: candidate, onDelete: onDelete)
                    Divider()
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.separator), lineWidth: 0.5)
            )
        }
    }
}

struct AddExtractsToPhrasesPanel: View {
    let defaultAIName: String
    @Binding var output: String
    let message: String?
    let addedPhrases: [PhraseDiscoveryCandidate]
    let onAdd: () -> Void
    let onClear: () -> Void
    let onDeleteAddedPhrase: (PhraseDiscoveryCandidate) -> Void

    private var outputIsEmpty: Bool {
        output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add extracts to Phrases")
                .font(ResponsiveFont.caption.weight(.semibold))

            Text("Paste one phrase or a batch from \(defaultAIName). Use this format: phrase | pinyin | English meaning.")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)

            phraseAnswerEditor

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                Button("Add Phrases", action: onAdd)
                    .buttonStyle(.borderedProminent)
                    .disabled(outputIsEmpty)

                Button("Clear", action: onClear)
                    .buttonStyle(.bordered)
                    .disabled(output.isEmpty && message == nil)
            }

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
                    .font(ResponsiveFont.body)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 14)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $output)
                .font(ResponsiveFont.body)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(Color.clear)
        }
        .frame(minHeight: 110)
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

private struct CaptureWorkflowStepChip: View {
    let step: CaptureWorkflowStep

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: step.isComplete ? "checkmark.circle.fill" : step.systemImage)
                .font(ResponsiveFont.caption)
                .foregroundStyle(step.isComplete ? Color.green : Color.secondary)

            VStack(alignment: .leading, spacing: 1) {
                Text(step.title)
                    .font(ResponsiveFont.caption.weight(.semibold))
                Text(step.detail)
                    .font(ResponsiveFont.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(step.isComplete ? Color.green.opacity(0.12) : Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(step.isComplete ? Color.green.opacity(0.35) : Color(.separator), lineWidth: 0.5)
        )
    }
}

private struct PhraseDiscoveryCandidateRow: View {
    @Binding var candidate: PhraseDiscoveryCandidate

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $candidate.isSelected) {
                Text(candidate.phrase.isEmpty ? "Phrase" : candidate.phrase)
                    .font(ResponsiveFont.body.bold())
            }

            HStack(alignment: .top, spacing: 8) {
                PhraseDiscoveryField("Phrase") {
                    TextField("Phrase", text: $candidate.phrase)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                }
                PhraseDiscoveryField("Pinyin") {
                    TextField("Pinyin", text: $candidate.pinyin)
                        .textFieldStyle(.roundedBorder)
                }
            }

            PhraseDiscoveryField("English Meaning") {
                TextField("Meaning", text: $candidate.meaning)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding(10)
    }
}

private struct AddedPhraseResultRow: View {
    let candidate: PhraseDiscoveryCandidate
    let onDelete: (PhraseDiscoveryCandidate) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(candidate.phrase)
                    .font(ResponsiveFont.body.bold())
                if !candidate.pinyin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(candidate.pinyin)
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                }
                if !candidate.meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(candidate.meaning)
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button("Delete", role: .destructive) {
                onDelete(candidate)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .font(ResponsiveFont.caption2.weight(.semibold))
        }
        .padding(8)
    }
}

private struct DiscoveryStatChip: View {
    let title: String
    let value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(ResponsiveFont.caption2)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(ResponsiveFont.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct PhraseDiscoveryField<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(ResponsiveFont.caption2)
                .foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
