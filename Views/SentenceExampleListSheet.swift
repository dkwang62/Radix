import SwiftUI

struct SentenceExampleListSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: RadixStore

    let title: String
    let examples: [SentenceExampleRecord]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(examples.enumerated()), id: \.element.id) { index, example in
                        sentenceRow(example, rank: index + 1)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .background(RadixTheme.secondaryBackground.opacity(0.3))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func sentenceRow(_ example: SentenceExampleRecord, rank: Int) -> some View {
        Button {
            present(example, rank: rank)
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Text("\(rank)")
                    .font(ResponsiveFont.caption2.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28, height: 28)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 7))

                Text(example.chinese)
                    .font(ResponsiveFont.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
            .background(RadixTheme.background)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open sentence \(example.chinese)")
        .accessibilityHint("Opens the sentence information card.")
    }

    private func present(_ example: SentenceExampleRecord, rank: Int) {
        let item = ConversationPracticeItem(sentenceExample: example, rank: rank)
        let phrase = ConversationPracticeScriptSupport.phraseItem(
            for: item,
            usesTraditionalScript: false,
            store: store
        )
        let sentencePhrases = store.verifiedPracticePhraseHints(for: item)
            .filter { store.phraseStorageWord($0.word) != item.phraseKey }
            .map {
                ConversationPracticeScriptSupport.displayPhrase(
                    $0,
                    usesTraditionalScript: false,
                    store: store
                )
            }

        store.presentPracticeSentenceInSidebar(
            phrase,
            sentencePhrases: sentencePhrases,
            practiceItem: item
        )
        dismiss()
    }
}
