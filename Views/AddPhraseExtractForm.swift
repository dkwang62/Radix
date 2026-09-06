import SwiftUI

struct AddPhraseExtractForm: View {
    @EnvironmentObject private var store: RadixStore
    @Binding var addedPhrases: [PhraseDiscoveryCandidate]
    @Binding var resultMessage: String?
    let returnTitle: String
    let onReviewAdded: () -> Void
    let onReturn: () -> Void

    @State private var output = ""
    @State private var message: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    AddExtractsToPhrasesPanel(
                        defaultAIName: store.defaultAIName,
                        output: $output,
                        message: $message,
                        addedPhrases: $addedPhrases,
                        onAdd: addOutputToPhrases,
                        onClear: clear,
                        onDeleteAddedPhrase: deleteAddedPhrase
                    )
                    .padding(12)

                    Color.clear.frame(height: 1).id("extractBottom")
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: addedPhrases.count) { _, _ in
                    withAnimation {
                        proxy.scrollTo("extractBottom", anchor: .bottom)
                    }
                }
            }

            Divider()

            actionRow
        }
    }

    private var actionRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                reviewAddedButton
                Spacer()
                returnButton
            }

            VStack(spacing: 10) {
                reviewAddedButton
                returnButton
            }
        }
        .padding()
        .background(RadixTheme.background)
    }

    @ViewBuilder
    private var reviewAddedButton: some View {
        if !addedPhrases.isEmpty {
            Button {
                onReviewAdded()
            } label: {
                Label("Review Added", systemImage: "checklist")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var returnButton: some View {
        Button {
            onReturn()
        } label: {
            Label("Back to \(returnTitle)", systemImage: "arrow.uturn.backward")
        }
        .buttonStyle(.bordered)
    }

    private func addOutputToPhrases() {
        let parsed = PhraseDiscoveryParser.parse(output)
        let candidates = PhraseDiscoveryCandidateTools.selectingAll(parsed.candidates, isSelected: true)
        let prepared = PhraseDiscoveryCandidateTools.preparingForImport(candidates)
        var added = 0
        var skippedExisting = 0
        var addedCandidates: [PhraseDiscoveryCandidate] = []
        var errors: [String] = []
        for item in prepared.candidates {
            do {
                let wasAdded = try store.addAIPastedPhraseIfNew(
                    word: item.phrase,
                    pinyin: item.candidate.pinyin,
                    meanings: item.candidate.meaning,
                    refreshViews: false
                )
                if wasAdded {
                    added += 1
                    addedCandidates.append(item.candidate)
                } else {
                    skippedExisting += 1
                }
            } catch {
                errors.append("\(item.phrase): \(error.localizedDescription)")
            }
        }
        store.refreshPhraseOverlayViews()
        addedPhrases = PhraseDiscoveryCandidateTools.mergingAddedResults(addedPhrases, addedCandidates)
        let summary = PhraseDiscoveryImportSummary(
            selectedCount: candidates.count,
            addedCount: added,
            skippedCount: prepared.skippedCount + skippedExisting,
            skippedExistingCount: skippedExisting,
            errors: errors
        )
        message = summary.message(defaultAIName: store.defaultAIName)
        resultMessage = message
        if errors.isEmpty && added > 0 {
            RadixHaptics.success()
        } else if !errors.isEmpty {
            RadixHaptics.error()
        }
        if !addedCandidates.isEmpty {
            onReviewAdded()
        }
    }

    private func clear() {
        output = ""
        message = nil
        addedPhrases = []
        resultMessage = nil
    }

    private func deleteAddedPhrase(_ candidate: PhraseDiscoveryCandidate) {
        do {
            try store.removeDataEditPhrase(word: candidate.phrase)
            addedPhrases.removeAll { $0.phrase == candidate.phrase }
            message = CaptureStatusText.removedPhrase(candidate.phrase)
            resultMessage = message
            RadixHaptics.light()
        } catch {
            message = "Delete failed: \(error.localizedDescription)"
            resultMessage = message
            RadixHaptics.error()
        }
    }
}
