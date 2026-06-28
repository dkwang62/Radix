import SwiftUI

struct ConversationPracticeReviewPresentation: Identifiable {
    let id = UUID()
    let library: ConversationPracticeLibrary
}

struct ConversationPracticeReviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: RadixStore
    let library: ConversationPracticeLibrary
    let onOpenPhrase: (PhraseItem) -> Void
    let onOpenCharacter: (String) -> Void
    @State private var currentIndex = 0
    @State private var isRevealed = false
    @State private var progress: [String: ConversationPracticeReviewResponse] = [:]

    var currentItem: ConversationPracticeItem {
        library.items[currentIndex]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    progressHeader
                    reviewCard
                    responseRow
                    linkedPartsSection
                }
                .padding()
            }
            .background(RadixTheme.background)
            .navigationTitle("Review Cards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    var progressHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(library.set.title)
                    .font(ResponsiveFont.body.weight(.semibold))
                Text("\(currentIndex + 1) of \(library.items.count)")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text("\(progress.count) reviewed")
                .font(ResponsiveFont.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    var reviewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(currentItem.simplified)
                .font(.system(size: RadixPlatform.isPhone ? 38 : 46, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)

            if isRevealed {
                VStack(alignment: .leading, spacing: 8) {
                    Label(currentItem.pinyin, systemImage: "speaker.wave.2")
                        .font(ResponsiveFont.body.weight(.semibold))
                    Text(currentItem.english)
                        .font(ResponsiveFont.body)
                    if !currentItem.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(currentItem.notes)
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Button {
                    withAnimation(.snappy) { isRevealed = true }
                } label: {
                    Label("Reveal Pinyin and English", systemImage: "eye")
                        .font(ResponsiveFont.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.accentColor)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RadixTheme.secondaryBackground.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    var responseRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isRevealed {
                HStack(spacing: 8) {
                    responseButton(.again)
                    responseButton(.good)
                    responseButton(.easy)
                }
            } else {
                Text("Reveal the answer, then choose how it felt.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    func responseButton(_ response: ConversationPracticeReviewResponse) -> some View {
        Button {
            record(response)
        } label: {
            Label(response.title, systemImage: response.systemImage)
                .font(ResponsiveFont.caption.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 40)
        }
        .buttonStyle(.bordered)
        .tint(response.tint)
    }

    var linkedPartsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button {
                    openPhrase(currentItem)
                } label: {
                    Label("Phrase Card", systemImage: "text.quote")
                        .font(ResponsiveFont.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)

                Spacer(minLength: 0)
            }

            if !currentItem.phraseHints.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Phrases")
                        .font(ResponsiveFont.caption.bold())
                        .foregroundStyle(.secondary)
                    RadixTileFlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                        ForEach(currentItem.phraseHints, id: \.self) { phrase in
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
                    }
                }
            }

            if !currentItem.characterHints.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Characters")
                        .font(ResponsiveFont.caption.bold())
                        .foregroundStyle(.secondary)
                    RadixTileFlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                        ForEach(currentItem.characterHints, id: \.self) { character in
                            Button {
                                openCharacter(character)
                            } label: {
                                Text(character)
                                    .font(ResponsiveFont.body.weight(.semibold))
                                    .frame(minWidth: 34, minHeight: 32)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(RadixTheme.secondaryBackground.opacity(0.42))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    func record(_ response: ConversationPracticeReviewResponse) {
        progress[currentItem.id] = response
        if response == .again {
            isRevealed = false
            return
        }
        if currentIndex < library.items.count - 1 {
            currentIndex += 1
            isRevealed = false
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

enum ConversationPracticeReviewResponse: Equatable {
    case again
    case good
    case easy

    var title: String {
        switch self {
        case .again: return "Again"
        case .good: return "Good"
        case .easy: return "Easy"
        }
    }

    var systemImage: String {
        switch self {
        case .again: return "arrow.counterclockwise"
        case .good: return "checkmark.circle"
        case .easy: return "sparkles"
        }
    }

    var tint: Color {
        switch self {
        case .again: return .orange
        case .good: return Color.accentColor
        case .easy: return .green
        }
    }
}
