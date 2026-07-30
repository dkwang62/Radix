import SwiftUI

extension FavouritesTab {
    var favouritesScrollContent: some View {
        Group {
            if studyAICleanedPageCollectionID != nil {
                aiCleanedPageStudyScreen
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    if showsStudyPinnedControls {
                        studyPinnedControls
                    }

                    if isShowingConversationPractice {
                        ScrollView {
                            conversationPracticeStudyScreen
                                .padding(.horizontal)
                                .padding(.bottom, 20)
                        }
                    } else if isShowingAddedPhraseReview {
                        addedPhraseReviewStudyScreen
                    } else if isShowingSentenceExamples {
                        sentenceExamplesStudyScreen
                    } else {
                        ScrollView {
                            studyReviewScrollContent
                                .padding(.horizontal)
                                .padding(.bottom, 20)
                        }
                    }
                }
            }
        }
    }

    var studyPinnedControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            recentStudyHeader
        }
        .padding(.horizontal)
        .padding(.top, 2)
        .padding(.bottom, 8)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(RadixTheme.separator.opacity(0.72))
                .frame(height: 0.5)
        }
    }

    var studyReviewScrollContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            studyReviewContent
        }
        .padding(.top, 10)
    }

    @ViewBuilder
    var conversationPracticeStudyScreen: some View {
        if conversationPracticeTopics.isEmpty {
            ContentUnavailableView(
                "No Practice Sets",
                systemImage: "bubble.left.and.bubble.right",
                description: Text("Conversation practice sets will appear here when they are available.")
            )
            .frame(maxWidth: .infinity, minHeight: 220)
        } else {
            conversationPracticeSection
        }
    }

    var addedPhraseReviewStudyScreen: some View {
        AddedPhraseReviewSheet(isWorkspace: true, showsWorkspaceCloseButton: false) {
            store.refreshAddedPhrases()
        }
        .environmentObject(store)
    }

    var sentenceExamplesStudyScreen: some View {
        VStack(alignment: .leading, spacing: 10) {
            sentenceExamplesControls
                .padding(.horizontal, isPhone ? 4 : 16)
                .padding(.top, isPhone ? 4 : 8)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: isPhone ? 2 : 8) {
                    if sentenceExampleResultCount == 0 {
                        ContentUnavailableView(
                            "No Sentences",
                            systemImage: RadixGlossaryIcon.systemImage(for: "Sentence"),
                            description: Text("Import page sentences or practice packs to create saved sentences.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 240)
                    } else {
                        ForEach(pagedSentenceExamples) { example in
                            sentenceExampleRow(example)
                        }
                    }
                }
                .padding(.horizontal, isPhone ? 4 : 16)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            refreshSentenceExampleResults()
        }
    }

    func clearFocusedStudySections() {
        focusedStudySection = nil
    }

    var studyCheckpointsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label("Checkpoints", systemImage: "clock.arrow.circlepath")
                    .font(ResponsiveFont.headline)
                Spacer()
                Text("\(checkpoints.count)/\(LocalDataSnapshotStore.maximumSnapshotCount)")
                    .font(ResponsiveFont.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            checkpointActionRow

            latestCheckpointRows
        }
        .radixCard(padding: 10, background: RadixTheme.secondaryBackground.opacity(0.52))
    }

    var checkpointActionRow: some View {
        checkpointActionButton(
            title: isCreatingCheckpoint ? "Creating…" : RadixCopy.createCheckpoint,
            subtitle: "Save this moment",
            systemImage: "clock.badge.checkmark",
            tint: RadixAccent.primary,
            isLocked: entitlement.requiresPro(.datedCopies),
            action: {
                if entitlement.requiresPro(.datedCopies) {
                    onRequirePro(.datedCopies)
                } else {
                    onCreateCheckpoint()
                }
            }
        )
    }

    @ViewBuilder
    var latestCheckpointRows: some View {
        if checkpoints.isEmpty {
            Text("No checkpoints created yet.")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .radixSurface(RadixTheme.background)
        } else {
            VStack(spacing: 6) {
                ForEach(checkpoints) { checkpoint in
                    Button {
                        pendingCheckpointReturn = checkpoint
                    } label: {
                        checkpointListRow(checkpoint)
                    }
                    .buttonStyle(.plain)
                    .disabled(isCreatingCheckpoint || isReturningToCheckpoint)
                }
            }
        }
    }

    func checkpointListRow(_ checkpoint: LocalDataSnapshot) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: RadixIconSize.standard, weight: .semibold))
                .foregroundStyle(RadixAccent.primary)
                .radixIconButtonSurface(
                    size: 24,
                    background: RadixAccent.primary.opacity(0.1)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(checkpoint.title)
                    .font(ResponsiveFont.caption.weight(.semibold))
                    .lineLimit(1)
                Text("\(checkpoint.relativeSavedText) · \(checkpoint.subtitle)")
                    .font(ResponsiveFont.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: RadixIconSize.small, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .radixSurface(RadixTheme.background)
    }

    func checkpointActionButton(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        isLocked: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            checkpointActionButtonContent(
                title: title,
                subtitle: subtitle,
                systemImage: systemImage,
                tint: tint,
                isLocked: isLocked
            )
        }
        .buttonStyle(.plain)
        .disabled(isCreatingCheckpoint || isReturningToCheckpoint)
    }

    func checkpointActionButtonContent(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        isLocked: Bool
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isLocked ? "lock.fill" : systemImage)
                .font(.system(size: RadixIconSize.standard, weight: .bold))
                .foregroundStyle(tint)
                .radixIconButtonSurface(
                    size: 28,
                    background: tint.opacity(0.12)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(ResponsiveFont.caption.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(subtitle)
                    .font(ResponsiveFont.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .layoutPriority(1)

            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        .radixSurface(tint.opacity(0.08), border: tint.opacity(0.25))
    }

    func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(ResponsiveFont.caption.bold())
            .foregroundStyle(.secondary)
    }

    func collectionDisplayName(_ collection: CharacterCollection) -> String {
        let name = collection.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? RadixCopy.savedPage : name
    }
}

struct SentenceExampleEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let record: SentenceExampleRecord
    let onSave: (SentenceExampleRecord) -> Void

    @State private var chinese: String
    @State private var pinyin: String
    @State private var english: String
    @State private var targetCharacters: String
    @State private var targetPhrases: String
    @State private var tags: String
    @State private var notes: String

    init(record: SentenceExampleRecord, onSave: @escaping (SentenceExampleRecord) -> Void) {
        self.record = record
        self.onSave = onSave
        _chinese = State(initialValue: record.chinese)
        _pinyin = State(initialValue: record.pinyin ?? "")
        _english = State(initialValue: record.english ?? "")
        _targetCharacters = State(initialValue: record.targetCharacters.joined(separator: ", "))
        _targetPhrases = State(initialValue: record.targetPhrases.joined(separator: ", "))
        _tags = State(initialValue: record.tags.joined(separator: ", "))
        _notes = State(initialValue: record.notes)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Sentence") {
                    TextEditor(text: $chinese)
                        .frame(minHeight: 72)
                    TextField("Pinyin", text: $pinyin, axis: .vertical)
                    TextField("English", text: $english, axis: .vertical)
                }

                Section("Learning Hints") {
                    TextField("Characters", text: $targetCharacters, axis: .vertical)
                    TextField("Phrases", text: $targetPhrases, axis: .vertical)
                    TextField("Tags", text: $tags, axis: .vertical)
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 82)
                }
            }
            .navigationTitle("Edit Sentence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        !trimmed(chinese).isEmpty
    }

    private func save() {
        var updated = record
        updated.chinese = trimmed(chinese)
        updated.pinyin = cleanOptional(pinyin)
        updated.english = cleanOptional(english)
        updated.targetCharacters = splitCharacters(targetCharacters)
        updated.targetPhrases = splitList(targetPhrases)
        updated.detectedCharacters = SentenceExampleRecord.detectChineseCharacters(in: updated.chinese)
        updated.tags = splitList(tags)
        updated.notes = trimmed(notes)
        onSave(updated)
        dismiss()
    }

    private func splitList(_ value: String) -> [String] {
        deduplicated(
            value.split { character in
                character == "," || character == ";" || character.isNewline
            }.map { trimmed(String($0)) }
        )
    }

    private func splitCharacters(_ value: String) -> [String] {
        let hasSeparators = value.contains(",") || value.contains(";") || value.contains { $0.isNewline }
        if hasSeparators {
            return splitList(value)
        }
        return deduplicated(
            value.map(String.init).map(trimmed).filter { !$0.isEmpty }
        )
    }

    private func cleanOptional(_ value: String) -> String? {
        let cleaned = trimmed(value)
        return cleaned.isEmpty ? nil : cleaned
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func deduplicated(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.filter { value in
            guard !value.isEmpty else { return false }
            return seen.insert(value).inserted
        }
    }
}
