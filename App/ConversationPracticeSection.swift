import SwiftUI

extension FavouritesTab {
    @ViewBuilder
    var conversationPracticeSection: some View {
        if let library = conversationPracticeLibrary {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Label("Conversation Practice", systemImage: "bubble.left.and.bubble.right")
                        .font(ResponsiveFont.headline)
                    Spacer(minLength: 8)
                    Text("\(library.set.itemCount) sentences")
                        .font(ResponsiveFont.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                conversationPracticeSetCard(library)
            }
        }
    }

    func conversationPracticeSetCard(_ library: ConversationPracticeLibrary) -> some View {
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
                    Text("Easy starter set")
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
