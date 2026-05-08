import SwiftUI

struct AddPhraseSheet: View {
    @EnvironmentObject private var store: RadixStore
    @Environment(\.dismiss) private var dismiss
    let returnTitle: String

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

    init(returnTitle: String = "Phrase") {
        self.returnTitle = returnTitle
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(step == .add ? "Add Phrases" : "Review Added")
                    .font(ResponsiveFont.title3.bold())
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top)
            .padding(.bottom, 8)

            if step == .add {
                Picker("Mode", selection: $mode) {
                    ForEach(AddPhraseMode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 12)
            }

            Divider()

            switch step {
            case .add:
                switch mode {
                case .input:
                    AddPhraseInputForm(
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
        .frame(minWidth: 320, idealWidth: 460, maxWidth: 560)
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

private struct AddPhraseInputForm: View {
    @EnvironmentObject private var store: RadixStore
    let onAdd: (PhraseDiscoveryCandidate, String?) -> Void
    let onCancel: () -> Void

    @State private var word = ""
    @State private var pinyin = ""
    @State private var meanings = ""
    @State private var notes = ""
    @State private var editorError: String?

    @FocusState private var focused: InputField?
    private enum InputField: Hashable { case word, pinyin, meanings, notes }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let editorError {
                    Text(editorError)
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.red)
                }

                fieldBlock("Phrase") {
                    TextField("Chinese phrase", text: $word)
                        .font(ResponsiveFont.body.bold())
                        .textFieldStyle(.roundedBorder)
                        .focused($focused, equals: .word)
                }

                fieldBlock("Pinyin") {
                    TextField("Pinyin", text: $pinyin)
                        .font(ResponsiveFont.body.monospaced())
                        .textFieldStyle(.roundedBorder)
                        .focused($focused, equals: .pinyin)
                }

                fieldBlock("English Meaning") {
                    TextEditor(text: $meanings)
                        .font(ResponsiveFont.body)
                        .frame(height: 80)
                        .padding(8)
                        .background(Color(.secondarySystemBackground).opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.separator), lineWidth: 0.5))
                        .focused($focused, equals: .meanings)
                }

                fieldBlock("Notes / Sentences / Practice") {
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $notes)
                            .font(ResponsiveFont.body)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .focused($focused, equals: .notes)
                        if notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Example sentences, usage notes, reminders...")
                                .font(ResponsiveFont.body)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                    }
                    .frame(height: 140)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.separator), lineWidth: 1))
                }
            }
            .padding()
        }

        Divider()

        HStack {
            Spacer()
            Button("Cancel", action: onCancel)
                .buttonStyle(.bordered)
            Button("Add Phrase") { addPhrase() }
                .buttonStyle(.borderedProminent)
                .disabled(word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
        .background(Color(.systemBackground))
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Button("Done") { focused = nil }
                Spacer()
                Button("Add Phrase") { addPhrase() }
                    .disabled(word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func fieldBlock<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(ResponsiveFont.caption.bold())
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func addPhrase() {
        do {
            let trimmed = store.normalizedPhraseWord(word)
            try store.addCustomPhrase(word: trimmed, pinyin: pinyin, meanings: meanings, notes: notes)
            editorError = nil
            onAdd(
                PhraseDiscoveryCandidate(
                    phrase: trimmed,
                    pinyin: pinyin,
                    meaning: meanings,
                    isSelected: true
                ),
                "Added \(trimmed)."
            )
            word = ""
            pinyin = ""
            meanings = ""
            notes = ""
        } catch {
            editorError = error.localizedDescription
        }
    }
}

private struct AddPhraseExtractForm: View {
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

            HStack {
                if !addedPhrases.isEmpty {
                    Button("Review Added", action: onReviewAdded)
                        .buttonStyle(.borderedProminent)
                }

                Spacer()

                Button {
                    onReturn()
                } label: {
                    Text("Back to \(returnTitle)")
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(.systemBackground))
        }
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
        store.removeDataEditPhrase(word: candidate.phrase)
        addedPhrases.removeAll { $0.phrase == candidate.phrase }
        message = CaptureStatusText.removedPhrase(candidate.phrase)
        resultMessage = message
    }
}

private struct AddPhraseReview: View {
    let addedPhrases: [PhraseDiscoveryCandidate]
    let message: String?
    let returnTitle: String
    let onAddMore: () -> Void
    let onDelete: (PhraseDiscoveryCandidate) -> Void
    let onReturn: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if addedPhrases.isEmpty {
                        if let message {
                            Text(message)
                                .font(ResponsiveFont.caption)
                                .foregroundStyle(.secondary)
                        }
                        ContentUnavailableView(
                            "No added phrases left",
                            systemImage: "text.badge.xmark",
                            description: Text("You deleted all phrases added in this round.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 220)
                    } else {
                        Text("\(addedPhrases.count) added to My Phrases. Delete any you do not want to keep.")
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.secondary)

                        AddedPhraseResultList(candidates: addedPhrases, onDelete: onDelete)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }

            Divider()

            HStack {
                Button("Add More", action: onAddMore)
                    .buttonStyle(.bordered)

                Spacer()

                Button("Back to \(returnTitle)", action: onReturn)
                    .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
