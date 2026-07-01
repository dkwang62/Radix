import SwiftUI

extension FavouritesTab {
    @ViewBuilder
    var conversationPracticeSection: some View {
        if !conversationPracticeTopics.isEmpty {
            let topic = selectedConversationPracticeTopic
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Label("Conversation Practice", systemImage: "bubble.left.and.bubble.right")
                        .font(ResponsiveFont.headline)
                    Spacer(minLength: 8)
                    Text(conversationPracticeStatusText(for: topic))
                        .font(ResponsiveFont.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                conversationPracticeTopicPicker(selectedTopic: topic)
                if isImportedConversationPracticeTopic(topic) {
                    conversationPracticeDeleteButton(topic)
                }
                conversationPracticeImportStatus

                if let library = conversationPracticeLibrary {
                    conversationPracticeSetCard(library, topic: topic)
                } else {
                    conversationPracticeGenerateCard(topic)
                }
            }
        }
    }

    func conversationPracticeStatusText(for topic: ConversationPracticeTopic) -> String {
        if let conversationPracticeLibrary {
            return "\(conversationPracticeLibrary.set.itemCount) sentences"
        }
        return topic.hasBundledContent ? "\(topic.targetSentenceCount) sentences" : "Generate"
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
                    Text(selectedTopic.summary)
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

    func conversationPracticeDeleteButton(_ topic: ConversationPracticeTopic) -> some View {
        Button(role: .destructive) {
            conversationPracticeImportMessage = nil
            conversationPracticeImportError = nil
            pendingConversationPracticeDeletion = topic
        } label: {
            Label("Delete This Practice", systemImage: "trash")
                .font(ResponsiveFont.caption.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 36)
        }
        .buttonStyle(.bordered)
        .tint(.red)
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 32, height: 32)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    Text(topic.difficultyLabel)
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                studyScriptToggle

                Label("\(library.set.itemCount)", systemImage: "list.number")
                    .font(ResponsiveFont.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            conversationPracticeSentenceList(library)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isConversationPracticeExpanded.toggle()
                }
            } label: {
                Label(
                    isConversationPracticeExpanded ? "Show Fewer" : "Show All Sentences",
                    systemImage: isConversationPracticeExpanded ? "chevron.up" : "list.bullet.rectangle"
                )
                .font(ResponsiveFont.caption.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 38)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(
                isConversationPracticeExpanded
                    ? "Collapse conversation practice sentences"
                    : "Show all \(library.set.itemCount) conversation practice sentences"
            )

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
        }
        .padding(10)
        .background(RadixTheme.secondaryBackground.opacity(0.52))
        .clipShape(RoundedRectangle(cornerRadius: 10))
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

    var conversationPracticeSampleColumns: [GridItem] {
        if RadixPlatform.interfaceIdiom == .tablet || RadixPlatform.isDesktop {
            return Array(repeating: GridItem(.flexible(minimum: 0), spacing: 6), count: 2)
        }
        return [GridItem(.flexible(minimum: 0), spacing: 6)]
    }

    var conversationPracticeSampleCount: Int {
        RadixPlatform.interfaceIdiom == .phone ? 3 : 4
    }

    @ViewBuilder
    func conversationPracticeSentenceList(_ library: ConversationPracticeLibrary) -> some View {
        if isConversationPracticeExpanded {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(library.items) { item in
                    conversationPracticeExpandedSentenceRow(item)
                }
            }
        } else {
            LazyVGrid(columns: conversationPracticeSampleColumns, spacing: 6) {
                ForEach(Array(library.items.prefix(conversationPracticeSampleCount))) { item in
                    conversationPracticeSentenceButton(item)
                }
            }
        }
    }

    func conversationPracticeSentenceButton(_ item: ConversationPracticeItem) -> some View {
        let isSelected = isSelectedConversationPracticeSentence(item)
        return Button {
            presentConversationPracticePhrase(item)
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(studyGridDisplayText(item.simplified))
                        .font(ResponsiveFont.body.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(item.pinyin)
                        .font(ResponsiveFont.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .layoutPriority(1)

                Spacer(minLength: 6)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(conversationPracticeSentenceBackground(isSelected: isSelected))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(conversationPracticeSentenceBorder(isSelected: isSelected, cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open phrase \(item.simplified)")
    }

    func conversationPracticeExpandedSentenceRow(_ item: ConversationPracticeItem) -> some View {
        let isSelected = isSelectedConversationPracticeSentence(item)
        return Button {
            presentConversationPracticePhrase(item)
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Text("\(item.rank)")
                    .font(ResponsiveFont.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.white : Color.accentColor)
                    .frame(width: 34, height: 34)
                    .background(isSelected ? Color.accentColor : Color.accentColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    Text(studyGridDisplayText(item.simplified))
                        .font(ResponsiveFont.body.weight(.semibold))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(item.pinyin)
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(item.english)
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .layoutPriority(1)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(conversationPracticeSentenceBackground(isSelected: isSelected))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(conversationPracticeSentenceBorder(isSelected: isSelected, cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open phrase \(studyGridDisplayText(item.simplified))")
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
