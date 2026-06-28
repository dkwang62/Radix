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
                    Text(conversationPracticeLibrary.map { "\($0.set.itemCount) sentences" } ?? (topic.hasBundledContent ? "\(topic.targetSentenceCount) sentences" : "Generate"))
                        .font(ResponsiveFont.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                conversationPracticeTopicPicker(selectedTopic: topic)
                conversationPracticeImportStatus

                if let library = conversationPracticeLibrary {
                    conversationPracticeSetCard(library, topic: topic)
                } else {
                    conversationPracticeGenerateCard(topic)
                }
            }
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
                    Text(library.set.title)
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

                Label("\(library.set.itemCount)", systemImage: "list.number")
                    .font(ResponsiveFont.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            LazyVGrid(columns: conversationPracticeSampleColumns, spacing: 6) {
                ForEach(Array(library.items.prefix(conversationPracticeSampleCount))) { item in
                    conversationPracticeSentenceButton(item)
                }
            }

            HStack(spacing: 8) {
                Button {
                    presentConversationPracticeReview(library)
                } label: {
                    Label("Review Cards", systemImage: "rectangle.stack")
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

            Button {
                presentConversationPracticeList(library)
            } label: {
                Label("Sentence List", systemImage: "list.bullet.rectangle")
                    .font(ResponsiveFont.caption.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 38)
            }
            .buttonStyle(.bordered)
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

    func conversationPracticeSentenceButton(_ item: ConversationPracticeItem) -> some View {
        Button {
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
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(RadixTheme.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open phrase \(item.simplified)")
    }

    func presentConversationPracticePhrase(_ item: ConversationPracticeItem) {
        let phrase = store.mergedPhrase(for: item.phraseKey) ?? PhraseItem(
            word: item.phraseKey,
            pinyin: item.pinyin,
            meanings: item.english,
            notes: item.notes
        )
        presentPhrase(phrase)
    }
}
