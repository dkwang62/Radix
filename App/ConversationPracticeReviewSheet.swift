import SwiftUI

struct ConversationPracticeReviewPresentation: Identifiable {
    let id = UUID()
    let library: ConversationPracticeLibrary
}

struct ConversationPracticeReviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: RadixStore
    let library: ConversationPracticeLibrary
    @Binding var usesTraditionalScript: Bool
    @State private var currentIndex = 0
    @State private var isRevealed = false
    @State private var progress: [String: ConversationPracticeReviewResponse] = [:]
    @State private var inspectionPath: [ConversationPracticeInspectionRoute] = []

    var currentItem: ConversationPracticeItem {
        library.items[currentIndex]
    }

    var body: some View {
        NavigationStack(path: $inspectionPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    progressHeader
                    scriptPicker
                    reviewCard
                    responseRow
                    linkedPartsSection
                }
                .padding()
            }
            .background(RadixTheme.background)
            .navigationTitle("Flashcards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .navigationDestination(for: ConversationPracticeInspectionRoute.self) { route in
                ConversationPracticeInspectionDestination(
                    route: route,
                    sourceTitle: "Flashcards",
                    onOpenCharacter: openCharacter
                )
                .environmentObject(store)
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

    var scriptPicker: some View {
        Picker("Script", selection: $usesTraditionalScript) {
            Text("Simplified").tag(false)
            Text("Traditional").tag(true)
        }
        .pickerStyle(.segmented)
    }

    var reviewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 8) {
                Text(displayText(currentItem.simplified))
                    .font(.system(size: RadixPlatform.isPhone ? 38 : 46, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)

                ConversationPracticeSpeechButton(
                    item: currentItem,
                    usesTraditionalScript: usesTraditionalScript,
                    accessibilityLabel: "Read flashcard sentence"
                )
            }

            if isRevealed {
                VStack(alignment: .leading, spacing: 8) {
                    Text(currentItem.pinyin)
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

            let hints = store.linkedPracticeHints(for: currentItem)
            if !hints.phrases.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Phrases")
                        .font(ResponsiveFont.caption.bold())
                        .foregroundStyle(.secondary)
                    RadixTileFlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                        ForEach(hints.phrases) { phrase in
                            Button {
                                openPhraseHint(phrase)
                            } label: {
                                Text(displayText(phrase.word))
                                    .font(ResponsiveFont.caption.weight(.semibold))
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }

            let characters = displayCharacters(for: currentItem, excludingPhrases: hints.phrases)
            if !characters.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Characters")
                        .font(ResponsiveFont.caption.bold())
                        .foregroundStyle(.secondary)
                    RadixTileFlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                        ForEach(characters, id: \.self) { character in
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
        storePracticeProgress(response)
        if response == .again {
            isRevealed = false
            return
        }
        if currentIndex < library.items.count - 1 {
            currentIndex += 1
            isRevealed = false
        }
    }

    func storePracticeProgress(_ response: ConversationPracticeReviewResponse) {
        var snapshot = RadixStudyPreferences.conversationPracticeProgress
        snapshot.record(
            item: currentItem,
            outcome: response.progressOutcome
        )
        RadixStudyPreferences.conversationPracticeProgress = snapshot
    }

    func openPhrase(_ item: ConversationPracticeItem) {
        let phrase = ConversationPracticeScriptSupport.phraseItem(
            for: item,
            usesTraditionalScript: usesTraditionalScript,
            store: store
        )
        store.readPhraseAloud(phrase)
        store.pushPhraseBreadcrumb(phrase)
        inspectionPath.append(.phrase(phrase, item))
    }

    func openPhraseHint(_ phrase: String) {
        guard let phraseItem = store.databasePhrase(for: phrase) else { return }
        openPhraseHint(phraseItem)
    }

    func openPhraseHint(_ phrase: PhraseItem) {
        let displayPhrase = ConversationPracticeScriptSupport.displayPhrase(
            phrase,
            usesTraditionalScript: usesTraditionalScript,
            store: store
        )
        store.readPhraseAloud(displayPhrase)
        store.pushPhraseBreadcrumb(displayPhrase)
        inspectionPath.append(.phrase(displayPhrase, nil))
    }

    func openCharacter(_ character: String) {
        store.readCharacterAloud(character)
        store.pushRootBreadcrumb(character)
        inspectionPath.append(.character(character))
    }

    func displayText(_ text: String) -> String {
        ConversationPracticeScriptSupport.displayText(
            text,
            usesTraditionalScript: usesTraditionalScript,
            store: store
        )
    }

    func displayCharacters(for item: ConversationPracticeItem, excludingPhrases phrases: [PhraseItem]) -> [String] {
        return ConversationPracticeScriptSupport.displayCharacters(
            for: item,
            excludingPhrases: phrases,
            usesTraditionalScript: usesTraditionalScript,
            store: store
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

    var progressOutcome: ConversationPracticeProgressOutcome {
        switch self {
        case .again: return .again
        case .good: return .good
        case .easy: return .easy
        }
    }
}
