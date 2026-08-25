import SwiftUI

extension FavouritesTab {
    func sentenceExampleRow(_ example: SentenceExampleRecord, usesCompactLayout: Bool = false) -> some View {
        let item = sentenceExamplePracticeItem(example)
        let isSelected = selectedConversationPracticeItemID == item.id
        return VStack(alignment: .leading, spacing: 4) {
            practiceSentenceRow(
                item,
                isSelected: isSelected,
                showsPhoneTrailing: !isPhone || isSelectingSentenceExamples,
                showsTrailing: !usesCompactLayout || isSelectingSentenceExamples,
                openAccessibilityLabel: "Open sentence \(studyGridDisplayText(item.simplified))",
                openAccessibilityHint: "Opens the sentence info card."
            ) {
                if isSelectingSentenceExamples {
                    toggleSentenceExampleSelection(example)
                } else {
                    presentConversationPracticePhrase(item)
                }
            } trailing: {
                if isSelectingSentenceExamples {
                    sentenceExampleSelectionButton(example)
                } else {
                    sentenceExampleFavoriteButton(example)
                    sentenceExampleActions(example)
                }
            }
            .contextMenu {
                if (isPhone || usesCompactLayout) && !isSelectingSentenceExamples {
                    sentenceExampleActionsMenuContent(example)
                }
            }

            if isSelected {
                sentenceExampleSourceActions(example)
                    .padding(.leading, 44)
            }
        }
    }

    func sentenceExamplePracticeItem(_ example: SentenceExampleRecord) -> ConversationPracticeItem {
        let rank = clampedSentenceExamplePageIndex * sentenceExamplePageSize
            + (sentenceExamplePageRecords.firstIndex(where: { $0.id == example.id }) ?? 0)
            + 1
        return ConversationPracticeItem(sentenceExample: example, rank: rank)
    }

    func sentenceExampleFavoriteButton(_ example: SentenceExampleRecord) -> some View {
        Button {
            toggleSentenceExampleFavorite(example)
        } label: {
            Image(systemName: example.isFavorited ? "star.fill" : "star")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .foregroundStyle(example.isFavorited ? Color.yellow : .secondary)
        .accessibilityLabel(example.isFavorited ? "Remove favorite sentence" : "Save favorite sentence")
    }

    func sentenceExampleSelectionButton(_ example: SentenceExampleRecord) -> some View {
        let isSelected = selectedSentenceExampleIDs.contains(example.id)
        return Button {
            toggleSentenceExampleSelection(example)
        } label: {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? RadixAccent.primary : .secondary)
        .accessibilityLabel(isSelected ? "Deselect sentence" : "Select sentence")
    }

    func sentenceExampleActions(_ example: SentenceExampleRecord) -> some View {
        Menu {
            sentenceExampleActionsMenuContent(example)
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 18, weight: .semibold))
                .radixIconButtonSurface(
                    size: 34,
                    background: RadixTheme.systemGray5,
                    radius: 17
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(RadixAccent.primary)
        .accessibilityLabel("Sentence actions")
    }

    @ViewBuilder
    func sentenceExampleActionsMenuContent(_ example: SentenceExampleRecord) -> some View {
        Button {} label: {
            Label(store.sentenceExampleSourceLabel(example), systemImage: sentenceExampleSourceIcon(example))
        }
        .disabled(true)

        Divider()

        Button {
            toggleSentenceExampleFavorite(example)
        } label: {
            Label(example.isFavorited ? "Remove Favorite" : "Favorite", systemImage: RadixIcon.saved)
        }

        Button {
            presentSentenceExamplePracticeAgain(example)
        } label: {
            Label("Practice Again", systemImage: "rectangle.stack")
        }

        Button {
            presentSentenceExampleEditor(example)
        } label: {
            Label("Edit", systemImage: "pencil")
        }

        Button {
            RadixPlatform.copyToPasteboard(example.chinese)
            sentenceExampleStatusMessage = "Copied"
        } label: {
            Label("Copy Chinese", systemImage: RadixIcon.copy)
        }

        if let pageID = sentenceExampleSourcePageID(example),
           store.collection(id: pageID) != nil {
            Button {
                openSentenceExampleSourcePage(pageID)
            } label: {
                Label("Open Page", systemImage: RadixGlossaryIcon.systemImage(for: RadixTerm.savedPage))
            }
        }

        Divider()

        Button(role: .destructive) {
            pendingSentenceExampleDeletion = PendingSentenceExampleDeletion(record: example)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    func deleteFilteredSentenceExamples() {
        let examples = RadixStudyPreferences.sentenceExamples(matching: allMatchingSentenceExampleQuery)
        guard !examples.isEmpty else { return }
        deleteSentenceExamples(
            examples,
            statusMessage: "Deleted \(examples.count) sentence\(examples.count == 1 ? "" : "s")",
            resetPage: true
        )
    }

    func startSelectingSentenceExamples() {
        isSelectingSentenceExamples = true
        sentenceExampleStatusMessage = nil
    }

    func stopSelectingSentenceExamples() {
        clearSentenceExampleSelection()
        isSelectingSentenceExamples = false
    }

    func toggleSentenceExampleSelection(_ example: SentenceExampleRecord) {
        if selectedSentenceExampleIDs.contains(example.id) {
            selectedSentenceExampleIDs.remove(example.id)
        } else {
            selectedSentenceExampleIDs.insert(example.id)
        }
    }

    func clearSentenceExampleSelection() {
        selectedSentenceExampleIDs.removeAll()
    }

    func deleteSelectedSentenceExamples() {
        let examples = selectedSentenceExamples
        guard !examples.isEmpty else { return }
        deleteSentenceExamples(
            examples,
            statusMessage: "Deleted \(examples.count) selected sentence\(examples.count == 1 ? "" : "s")",
            exitSelection: true
        )
    }

    func deleteSentenceExamples(
        _ examples: [SentenceExampleRecord],
        statusMessage: String,
        resetPage: Bool = false,
        exitSelection: Bool = false
    ) {
        guard !examples.isEmpty else { return }
        store.deleteSentenceExamples(examples)
        if resetPage {
            resetSentenceExamplePage()
        }
        if exitSelection {
            stopSelectingSentenceExamples()
        } else {
            clearSentenceExampleSelection()
        }
        refreshSentenceExamplesAfterMutation(statusMessage: statusMessage)
    }

    @ViewBuilder
    func sentenceExampleSourceActions(_ example: SentenceExampleRecord) -> some View {
        let hasPageAction = sentenceExampleSourcePageID(example).flatMap { store.collection(id: $0) } != nil
        let hasPracticeAction = sentenceExamplePracticeTopic(for: example) != nil
        if hasPageAction || hasPracticeAction {
            VStack(alignment: .leading, spacing: 4) {
                Label(sentenceExampleOriginSummary(example), systemImage: sentenceExampleSourceIcon(example))
                    .font(ResponsiveFont.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                HStack(spacing: 6) {
                    if let pageID = sentenceExampleSourcePageID(example),
                       store.collection(id: pageID) != nil {
                        Button {
                            openSentenceExampleSourcePage(pageID)
                        } label: {
                            Label("Open Page", systemImage: RadixGlossaryIcon.systemImage(for: RadixTerm.savedPage))
                                .font(ResponsiveFont.caption2.weight(.semibold))
                                .labelStyle(.titleAndIcon)
                                .radixPill(horizontal: 8, vertical: 5, background: RadixAccent.primary.opacity(0.1))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(RadixAccent.primary)
                        .accessibilityLabel("Open source page")
                    }

                    if let topic = sentenceExamplePracticeTopic(for: example) {
                        Button {
                            openSentenceExamplePracticeSource(example, topic: topic)
                        } label: {
                            Label("Open Practice", systemImage: "bubble.left.and.bubble.right")
                                .font(ResponsiveFont.caption2.weight(.semibold))
                                .labelStyle(.titleAndIcon)
                                .radixPill(horizontal: 8, vertical: 5, background: RadixAccent.primary.opacity(0.1))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(RadixAccent.primary)
                        .accessibilityLabel("Open source practice")
                    }
                }
            }
        }
    }

    func toggleSentenceExampleFavorite(_ example: SentenceExampleRecord) {
        RadixStudyPreferences.setSentenceExampleFavorite(id: example.id, isFavorited: !example.isFavorited)
        refreshSentenceExamplesAfterMutation(
            statusMessage: example.isFavorited ? "Removed favorite" : "Favorited"
        )
    }

    func presentSentenceExamplePracticeAgain(_ example: SentenceExampleRecord) {
        guard let library = ConversationPracticeLibrary.sentenceExamplesLibrary(
            from: [example],
            title: "Practice Again"
        ) else { return }
        presentConversationPracticeReview(library)
    }

    func presentSentenceExampleEditor(_ example: SentenceExampleRecord) {
        sentenceExampleEditDraft = SentenceExampleEditDraft(record: example)
    }

    func sentenceExampleSourcePageID(_ example: SentenceExampleRecord) -> UUID? {
        example.sources.first(where: { $0.sourcePageID != nil })?.sourcePageID
    }

    func sentenceExamplePracticeSource(_ example: SentenceExampleRecord) -> SentenceExampleSourceReference? {
        example.sources.first {
            switch $0.sourceType {
            case .conversationPractice, .sentencePractice, .favoriteSentence:
                return $0.practicePackID != nil || $0.sourceID != nil
            default:
                return false
            }
        }
    }

    func sentenceExamplePracticeTopic(for example: SentenceExampleRecord) -> ConversationPracticeTopic? {
        guard let source = sentenceExamplePracticeSource(example) else { return nil }
        let candidateIDs = [
            source.practicePackID,
            source.sourceID
        ].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return conversationPracticeTopics.first { topic in
            candidateIDs.contains(topic.id)
        }
    }

    func openSentenceExampleSourcePage(_ pageID: UUID) {
        store.goToPagesWorkspace(id: pageID, preservingOrigin: true)
    }

    func openSentenceExamplePracticeSource(_ example: SentenceExampleRecord, topic: ConversationPracticeTopic) {
        let source = sentenceExamplePracticeSource(example)
        withAnimation(.snappy(duration: 0.18)) {
            screenState.presentFocusedSection(.conversationPractice)
        }
        selectConversationPracticeTopic(topic)
        selectPracticeItemForSentenceExample(example, source: source)
    }

    func selectPracticeItemForSentenceExample(
        _ example: SentenceExampleRecord,
        source: SentenceExampleSourceReference?
    ) {
        guard let library = conversationPracticeLibrary else { return }
        let targetID = source?.practiceItemID?.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetKey = example.normalizedChineseKey
        guard let index = library.items.firstIndex(where: { item in
            if let targetID, !targetID.isEmpty, item.id == targetID {
                return true
            }
            if item.sentenceExampleID == example.id {
                return true
            }
            return item.sentenceKey == targetKey
        }) else { return }
        selectedConversationPracticeItemID = library.items[index].id
        conversationPracticePageIndex = index / conversationPracticePageSize
    }

    func sentenceExampleOriginSummary(_ example: SentenceExampleRecord) -> String {
        let source = store.sentenceExampleSourceLabel(example)
        if let topic = sentenceExamplePracticeTopic(for: example),
           topic.title != source {
            return "From \(source) / \(topic.title)"
        }
        return "From \(source)"
    }

    func sentenceExampleSourceIcon(_ example: SentenceExampleRecord) -> String {
        if example.hasSourceType(.ocrSource) { return "doc.text" }
        if example.hasSourceType(.sentencePractice) { return RadixGlossaryIcon.systemImage(for: RadixTerm.savedPage) }
        if example.hasSourceType(.conversationPractice) { return "bubble.left.and.bubble.right" }
        if example.hasSourceType(.favoriteSentence) { return RadixIcon.saved }
        return RadixGlossaryIcon.systemImage(for: "Sentence")
    }
}
