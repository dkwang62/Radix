import SwiftUI

extension FavouritesTab {
    @ViewBuilder
    var conversationPracticeSection: some View {
        if !conversationPracticeTopics.isEmpty {
            let topic = selectedConversationPracticeTopic
            VStack(alignment: .leading, spacing: 10) {
                conversationPracticeTopicControlRow(selectedTopic: topic)
                conversationPracticeImportStatus

                if let library = conversationPracticeLibrary {
                    conversationPracticeSetCard(library, topic: topic)
                } else {
                    conversationPracticeGenerateCard(topic)
                }
            }
        }
    }

    func conversationPracticeTopicControlRow(selectedTopic: ConversationPracticeTopic) -> some View {
        HStack(spacing: 8) {
            conversationPracticeTopicPicker(selectedTopic: selectedTopic)

            if isImportedConversationPracticeTopic(selectedTopic) {
                conversationPracticeDeleteButton(selectedTopic)
            }
        }
    }

    func conversationPracticePageNavigation(_ library: ConversationPracticeLibrary) -> some View {
        HStack(spacing: 6) {
            Button {
                moveConversationPracticePage(by: -1, in: library)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .foregroundStyle(canMoveConversationPracticePage(by: -1, in: library) ? Color.accentColor : .secondary)
            .disabled(!canMoveConversationPracticePage(by: -1, in: library))
            .accessibilityLabel("Previous sentence page")

            Text(conversationPracticePageLabel(for: library))
                .font(ResponsiveFont.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Button {
                moveConversationPracticePage(by: 1, in: library)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .foregroundStyle(canMoveConversationPracticePage(by: 1, in: library) ? Color.accentColor : .secondary)
            .disabled(!canMoveConversationPracticePage(by: 1, in: library))
            .accessibilityLabel("Next sentence page")
        }
    }

    func conversationPracticeTopicPicker(selectedTopic: ConversationPracticeTopic) -> some View {
        Menu {
            ForEach(conversationPracticeTopics) { topic in
                Button {
                    selectConversationPracticeTopic(topic)
                } label: {
                    if topic.id == selectedTopic.id {
                        Label(topic.title, systemImage: "checkmark")
                    } else {
                        Text(topic.title)
                    }
                }
            }

            Divider()

            Button {
                showConversationPracticeImporter = true
            } label: {
                Label("Import Practice JSON", systemImage: "square.and.arrow.down")
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "list.bullet.rectangle.portrait")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 30, height: 30)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedTopic.title)
                        .font(ResponsiveFont.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(conversationPracticeTopicSubtitle(selectedTopic))
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .layoutPriority(1)

                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RadixTheme.background)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    func conversationPracticeTopicSubtitle(_ topic: ConversationPracticeTopic) -> String {
        guard let library = conversationPracticeLibrary, library.set.id == topic.id else {
            return topic.summary
        }
        let summary = conversationPracticeProgress.summary(for: library)
        guard summary.totalItems > 0 else { return topic.summary }
        let completion = "\(summary.completedItems)/\(summary.totalItems) complete"
        if let lastPracticedAt = summary.lastPracticedAt {
            return "\(completion) · Last \(lastPracticedAt.formatted(date: .abbreviated, time: .omitted))"
        }
        return "\(completion) · Not practiced yet"
    }

    func conversationPracticeDeleteButton(_ topic: ConversationPracticeTopic) -> some View {
        Button(role: .destructive) {
            conversationPracticeImportMessage = nil
            conversationPracticeImportError = nil
            pendingConversationPracticeDeletion = topic
        } label: {
            Image(systemName: "trash")
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 44, height: 44)
                .background(Color.red.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.red)
        .accessibilityLabel("Delete this practice")
    }

    @ViewBuilder
    var conversationPracticeImportStatus: some View {
        if let message = conversationPracticeImportMessage {
            Label(message, systemImage: "checkmark.circle")
                .font(ResponsiveFont.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else if let error = conversationPracticeImportError {
            Label(error, systemImage: "exclamationmark.triangle")
                .font(ResponsiveFont.caption.weight(.semibold))
                .foregroundStyle(.red)
                .lineLimit(3)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    func conversationPracticeSetCard(
        _ library: ConversationPracticeLibrary,
        topic: ConversationPracticeTopic
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            conversationPracticeDisplayControls(library)
            conversationPracticeSentenceList(library)
        }
        .padding(10)
        .background(RadixTheme.secondaryBackground.opacity(0.52))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    var showsConversationPracticeFloatingControls: Bool {
        isShowingConversationPractice && conversationPracticeLibrary != nil
    }

    @ViewBuilder
    func conversationPracticeDisplayControls(_ library: ConversationPracticeLibrary) -> some View {
        if isNarrowStudyLayout {
            VStack(alignment: .leading, spacing: 6) {
                conversationPracticePageNavigation(library)
                    .fixedSize(horizontal: true, vertical: false)

                HStack(spacing: 8) {
                    Spacer(minLength: 0)
                    studyScriptToggle
                    conversationPracticeSentenceDisplayToggle
                }
            }
            .padding(.bottom, 2)
        } else {
            HStack(spacing: 8) {
                conversationPracticePageNavigation(library)
                    .fixedSize(horizontal: true, vertical: false)

                Spacer(minLength: 8)

                studyScriptToggle
                conversationPracticeSentenceDisplayToggle
            }
            .padding(.bottom, 2)
        }
    }

    func conversationPracticeFloatingBottomActions(_ library: ConversationPracticeLibrary) -> some View {
        HStack(spacing: 8) {
            Button {
                presentConversationPracticeReview(library)
            } label: {
                Label("Flashcards", systemImage: "rectangle.stack")
                    .font(ResponsiveFont.caption.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 38)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accentColor)

            Button {
                presentConversationPracticeQuiz(library)
            } label: {
                Label("Quick Quiz", systemImage: "checkmark.circle")
                    .font(ResponsiveFont.caption.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 38)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    var conversationPracticeSentenceDisplayToggle: some View {
        Picker("Sentence Display", selection: $conversationPracticeSentenceDisplay) {
            ForEach(ConversationPracticeSentenceDisplay.allCases) { display in
                Text(display.rawValue).tag(display)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 150)
    }

    func conversationPracticeGenerateCard(_ topic: ConversationPracticeTopic) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 32, height: 32)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    Text(topic.title)
                        .font(ResponsiveFont.body.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(topic.difficultyLabel)
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                Label("\(topic.targetSentenceCount)", systemImage: "list.number")
                    .font(ResponsiveFont.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Text(topic.summary)
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            RadixTileFlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                ForEach(topic.situations.prefix(5), id: \.self) { situation in
                    Text(situation)
                        .font(ResponsiveFont.caption2.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            Button {
                generateConversationPracticeTopic(topic)
            } label: {
                Label("Generate Practice Pack", systemImage: "sparkles")
                    .font(ResponsiveFont.caption.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 38)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accentColor)
        }
        .padding(10)
        .background(RadixTheme.secondaryBackground.opacity(0.52))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    func conversationPracticeSentenceList(_ library: ConversationPracticeLibrary) -> some View {
        LazyVStack(alignment: .leading, spacing: 4) {
            ForEach(conversationPracticePagedItems(for: library)) { item in
                conversationPracticeSentenceRow(item)
            }
        }
    }

    var conversationPracticePageSize: Int {
        isNarrowStudyLayout ? 5 : 10
    }

    func conversationPracticePageCount(for library: ConversationPracticeLibrary) -> Int {
        max(1, Int(ceil(Double(library.items.count) / Double(conversationPracticePageSize))))
    }

    func conversationPracticeClampedPageIndex(for library: ConversationPracticeLibrary) -> Int {
        min(max(conversationPracticePageIndex, 0), conversationPracticePageCount(for: library) - 1)
    }

    func conversationPracticePagedItems(for library: ConversationPracticeLibrary) -> [ConversationPracticeItem] {
        let pageIndex = conversationPracticeClampedPageIndex(for: library)
        let startIndex = pageIndex * conversationPracticePageSize
        let endIndex = min(startIndex + conversationPracticePageSize, library.items.count)
        guard startIndex < endIndex else { return [] }
        return Array(library.items[startIndex..<endIndex])
    }

    func conversationPracticePageLabel(for library: ConversationPracticeLibrary) -> String {
        guard !library.items.isEmpty else { return "0 of 0" }
        let pageIndex = conversationPracticeClampedPageIndex(for: library)
        let startRank = pageIndex * conversationPracticePageSize + 1
        let endRank = min(startRank + conversationPracticePageSize - 1, library.items.count)
        return "\(startRank)-\(endRank) of \(library.items.count)"
    }

    func canMoveConversationPracticePage(by offset: Int, in library: ConversationPracticeLibrary) -> Bool {
        let nextIndex = conversationPracticeClampedPageIndex(for: library) + offset
        return nextIndex >= 0 && nextIndex < conversationPracticePageCount(for: library)
    }

    func moveConversationPracticePage(by offset: Int, in library: ConversationPracticeLibrary) {
        guard canMoveConversationPracticePage(by: offset, in: library) else { return }
        withAnimation(.snappy(duration: 0.18)) {
            conversationPracticePageIndex = conversationPracticeClampedPageIndex(for: library) + offset
        }
    }

    func conversationPracticeSentenceRow(_ item: ConversationPracticeItem) -> some View {
        let isSelected = isSelectedConversationPracticeSentence(item)
        return Button {
            presentConversationPracticePhrase(item)
        } label: {
            HStack(alignment: .center, spacing: 8) {
                Text("\(item.rank)")
                    .font(ResponsiveFont.caption2.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.white : Color.accentColor)
                    .frame(width: 28, height: 28)
                    .background(isSelected ? Color.accentColor : Color.accentColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 7))

                conversationPracticeSentenceRowText(item)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
            .background(conversationPracticeSentenceBackground(isSelected: isSelected))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(conversationPracticeSentenceBorder(isSelected: isSelected, cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open phrase \(studyGridDisplayText(item.simplified))")
        .accessibilityHint("Opens and reads the practice sentence.")
    }

    @ViewBuilder
    func conversationPracticeSentenceRowText(_ item: ConversationPracticeItem) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            switch conversationPracticeSentenceDisplay {
            case .chinese:
                Text(studyGridDisplayText(item.simplified))
                    .font(ResponsiveFont.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(item.pinyin)
                    .font(ResponsiveFont.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            case .english:
                Text(item.english)
                    .font(ResponsiveFont.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
        }
        .layoutPriority(1)
    }

    func presentConversationPracticePhrase(_ item: ConversationPracticeItem) {
        selectedConversationPracticeItemID = item.id
        let phrase = ConversationPracticeScriptSupport.phraseItem(
            for: item,
            usesTraditionalScript: studyGridUsesTraditionalScript,
            store: store
        )
        let sentencePhrases = store.verifiedPracticePhraseHints(for: item)
            .filter { store.phraseStorageWord($0.word) != item.phraseKey }
            .map {
                ConversationPracticeScriptSupport.displayPhrase(
                    $0,
                    usesTraditionalScript: studyGridUsesTraditionalScript,
                    store: store
                )
            }
        store.speakPhrase(phrase)
        store.presentPracticeSentenceInSidebar(phrase, sentencePhrases: sentencePhrases)
    }

    func isSelectedConversationPracticeSentence(_ item: ConversationPracticeItem) -> Bool {
        selectedConversationPracticeItemID == item.id
    }

    func conversationPracticeSentenceBackground(isSelected: Bool) -> Color {
        isSelected ? Color.accentColor.opacity(0.12) : RadixTheme.background
    }

    func conversationPracticeSentenceBorder(isSelected: Bool, cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .stroke(isSelected ? Color.accentColor.opacity(0.75) : Color.clear, lineWidth: 1.4)
    }
}
