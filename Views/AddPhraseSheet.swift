import SwiftUI

struct AddPhraseSheet: View {
    @EnvironmentObject private var store: RadixStore
    @Environment(\.dismiss) private var dismiss
    let returnTitle: String
    let initialWord: String

    private enum AddPhraseMode: String, CaseIterable {
        case input = "Type"
        case fromExtract = "From AI"
    }

    private enum AddPhraseStep {
        case add
        case review
    }

    @State private var mode: AddPhraseMode = .input
    @State private var step: AddPhraseStep = .add
    @State private var addedPhrases: [PhraseDiscoveryCandidate] = []
    @State private var resultMessage: String?

    init(returnTitle: String = "Phrase", initialWord: String = "") {
        self.returnTitle = returnTitle
        self.initialWord = initialWord
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if step == .add {
                modePicker
            }

            Divider()

            content
        }
        .frame(minWidth: 320, idealWidth: 460, maxWidth: 560)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: step == .add ? "text.badge.plus" : "checkmark.circle")
                .font(ResponsiveFont.title3.weight(.semibold))
                .foregroundStyle(RadixAccent.primary)
                .radixIconButtonSurface(
                    size: 34,
                    background: RadixAccent.primary.opacity(0.12)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(step == .add ? "Add Phrases" : "Review Added")
                    .font(ResponsiveFont.title3.bold())
                Text(step == .add ? "Type one phrase or import from AI extraction." : "\(addedPhrases.count) saved \(addedPhrases.count == 1 ? "phrase" : "phrases").")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(RadixTheme.background)
    }

    private var modePicker: some View {
        Picker("Mode", selection: $mode) {
            ForEach(AddPhraseMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.bottom, 12)
        .background(RadixTheme.background)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .add:
            addContent
        case .review:
            AddPhraseReview(
                addedPhrases: addedPhrases,
                message: resultMessage,
                returnTitle: returnTitle,
                onAddMore: {
                    resultMessage = nil
                    step = .add
                },
                onDelete: deleteAddedPhrase,
                onReturn: { dismiss() }
            )
        }
    }

    @ViewBuilder
    private var addContent: some View {
        switch mode {
        case .input:
            AddPhraseInputForm(
                initialWord: initialWord,
                onAdd: recordAddedPhrase,
                onCancel: { dismiss() }
            )
            .environmentObject(store)
        case .fromExtract:
            AddPhraseExtractForm(
                addedPhrases: $addedPhrases,
                resultMessage: $resultMessage,
                returnTitle: returnTitle,
                onReviewAdded: { step = .review },
                onReturn: { dismiss() }
            )
            .environmentObject(store)
        }
    }

    private func recordAddedPhrase(_ candidate: PhraseDiscoveryCandidate, message: String?) {
        addedPhrases = PhraseDiscoveryCandidateTools.mergingAddedResults(addedPhrases, [candidate])
        resultMessage = message ?? "Added \(candidate.phrase)."
        step = .review
    }

    private func deleteAddedPhrase(_ candidate: PhraseDiscoveryCandidate) {
        store.removeDataEditPhrase(word: candidate.phrase)
        addedPhrases.removeAll { $0.phrase == candidate.phrase }
        resultMessage = CaptureStatusText.removedPhrase(candidate.phrase)
    }
}

struct AddPhraseLaunchButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Phrase", systemImage: "plus.circle.fill")
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("Add Phrase")
    }
}
