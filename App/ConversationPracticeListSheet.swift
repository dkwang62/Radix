import SwiftUI

struct ConversationPracticeListPresentation: Identifiable {
    let id = UUID()
    let library: ConversationPracticeLibrary
}

struct ConversationPracticeListSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: RadixStore
    let library: ConversationPracticeLibrary
    let onOpenPhrase: (PhraseItem) -> Void
    let onOpenCharacter: (String) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(library.items) { item in
                        sentenceRow(item)
                    }
                }
                .padding()
            }
            .background(RadixTheme.background)
            .navigationTitle(library.set.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    func sentenceRow(_ item: ConversationPracticeItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                openPhrase(item)
            } label: {
                HStack(alignment: .center, spacing: 10) {
                    Text("\(item.rank)")
                        .font(ResponsiveFont.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 34, height: 34)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.simplified)
                            .font(ResponsiveFont.body.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        Text(item.pinyin)
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(item.english)
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .layoutPriority(1)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open phrase \(item.simplified)")

            linkedHintRow(item)
        }
        .padding(12)
        .background(RadixTheme.secondaryBackground.opacity(0.52))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    func linkedHintRow(_ item: ConversationPracticeItem) -> some View {
        if !item.phraseHints.isEmpty || !item.characterHints.isEmpty {
            RadixTileFlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                ForEach(item.phraseHints, id: \.self) { phrase in
                    Button {
                        openPhraseHint(phrase)
                    } label: {
                        Text(phrase)
                            .font(ResponsiveFont.caption.weight(.semibold))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)
                }

                ForEach(item.characterHints, id: \.self) { character in
                    Button {
                        openCharacter(character)
                    } label: {
                        Text(character)
                            .font(ResponsiveFont.caption.weight(.semibold))
                            .frame(minWidth: 30, minHeight: 30)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    func openPhrase(_ item: ConversationPracticeItem) {
        dismiss()
        onOpenPhrase(phraseItem(for: item))
    }

    func openPhraseHint(_ phrase: String) {
        dismiss()
        onOpenPhrase(store.mergedPhrase(for: phrase) ?? PhraseItem(word: phrase, pinyin: "", meanings: ""))
    }

    func openCharacter(_ character: String) {
        dismiss()
        onOpenCharacter(character)
    }

    func phraseItem(for item: ConversationPracticeItem) -> PhraseItem {
        store.mergedPhrase(for: item.phraseKey) ?? PhraseItem(
            word: item.phraseKey,
            pinyin: item.pinyin,
            meanings: item.english,
            notes: item.notes
        )
    }
}
