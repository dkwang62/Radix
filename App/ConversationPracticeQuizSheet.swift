import SwiftUI

struct ConversationPracticeQuizPresentation: Identifiable {
    let id = UUID()
    let library: ConversationPracticeLibrary
}

struct ConversationPracticeQuizSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: RadixStore
    let library: ConversationPracticeLibrary
    @State private var currentIndex = 0
    @State private var selectedAnswerID: String?
    @State private var answered: [String: Bool] = [:]
    @State private var inspectionPath: [ConversationPracticeInspectionRoute] = []

    var currentItem: ConversationPracticeItem {
        library.items[currentIndex]
    }

    var question: ConversationPracticeQuizRules.CharacterQuestion {
        ConversationPracticeQuizRules.characterQuestion(for: currentItem)
    }

    var quizCharacter: String {
        question.character
    }

    var currentCharacterItem: ComponentItem? {
        store.item(for: quizCharacter)
    }

    var choices: [String] {
        ConversationPracticeQuizRules.characterChoices(
            for: quizCharacter,
            from: characterChoiceCandidates()
        )
    }

    var hasAnsweredCurrent: Bool {
        selectedAnswerID != nil
    }

    var selectedIsCorrect: Bool {
        selectedAnswerID == quizCharacter
    }

    var body: some View {
        NavigationStack(path: $inspectionPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    progressHeader
                    questionCard
                    answerChoices
                    if hasAnsweredCurrent {
                        feedbackSection
                    }
                }
                .padding()
            }
            .background(RadixTheme.background)
            .navigationTitle("Quick Quiz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .navigationDestination(for: ConversationPracticeInspectionRoute.self) { route in
                ConversationPracticeInspectionDestination(
                    route: route,
                    sourceTitle: "Quick Quiz",
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

            Text("\(score) correct")
                .font(ResponsiveFont.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    var questionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Which character completes the sentence?")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)

                Text(question.blankedSentence)
                    .font(.system(size: RadixPlatform.isPhone ? 32 : 40, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.55)
                    .fixedSize(horizontal: false, vertical: true)

                Text(currentItem.english)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RadixTheme.secondaryBackground.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    var answerChoices: some View {
        VStack(spacing: 8) {
            ForEach(choices, id: \.self) { choice in
                Button {
                    choose(choice)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: answerIcon(for: choice))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(answerTint(for: choice))
                            .frame(width: 24, height: 24)

                        Text(choice)
                            .font(.system(size: 34, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .minimumScaleFactor(0.7)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    .background(answerBackground(for: choice))
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9)
                            .stroke(answerTint(for: choice).opacity(hasAnsweredCurrent ? 0.5 : 0.18), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(hasAnsweredCurrent)
            }
        }
    }

    var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(selectedIsCorrect ? "Correct" : "Review this one", systemImage: selectedIsCorrect ? "checkmark.circle.fill" : "arrow.counterclockwise.circle")
                .font(ResponsiveFont.body.weight(.semibold))
                .foregroundStyle(selectedIsCorrect ? Color.green : Color.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text(quizCharacter)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                Text(currentCharacterItem?.pinyinText ?? currentItem.pinyin)
                    .font(ResponsiveFont.body.weight(.semibold))
                Text(currentCharacterItem?.definition ?? currentItem.english)
                    .font(ResponsiveFont.body)
            }

            HStack(spacing: 8) {
                Button {
                    openPhrase(currentItem)
                } label: {
                    Label("Sentence Card", systemImage: "text.quote")
                        .font(ResponsiveFont.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)

                Spacer(minLength: 0)

                Button {
                    advance()
                } label: {
                    Label(isLastQuestion ? "Finish" : "Next", systemImage: isLastQuestion ? "checkmark" : "arrow.right")
                        .font(ResponsiveFont.caption.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.accentColor)
            }

            if !currentItem.characterHints.isEmpty {
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
        .padding(12)
        .background(RadixTheme.secondaryBackground.opacity(0.42))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    var score: Int {
        answered.values.filter { $0 }.count
    }

    var isLastQuestion: Bool {
        currentIndex >= library.items.count - 1
    }

    func choose(_ choice: String) {
        selectedAnswerID = choice
        answered["\(currentItem.id)#\(quizCharacter)"] = choice == quizCharacter
    }

    func advance() {
        guard !isLastQuestion else {
            dismiss()
            return
        }
        currentIndex += 1
        selectedAnswerID = nil
    }

    func answerIcon(for choice: String) -> String {
        guard hasAnsweredCurrent else { return "circle" }
        if choice == quizCharacter { return "checkmark.circle.fill" }
        if choice == selectedAnswerID { return "xmark.circle.fill" }
        return "circle"
    }

    func answerTint(for choice: String) -> Color {
        guard hasAnsweredCurrent else { return .secondary }
        if choice == quizCharacter { return .green }
        if choice == selectedAnswerID { return .red }
        return .secondary
    }

    func answerBackground(for choice: String) -> Color {
        guard hasAnsweredCurrent else { return RadixTheme.secondaryBackground.opacity(0.45) }
        if choice == quizCharacter { return Color.green.opacity(0.12) }
        if choice == selectedAnswerID { return Color.red.opacity(0.1) }
        return RadixTheme.secondaryBackground.opacity(0.34)
    }

    func characterChoiceCandidates() -> [ConversationPracticeQuizRules.CharacterChoiceCandidate] {
        var characters = [quizCharacter]
        characters.append(contentsOf: store.componentRepo.sharedComponentPeers(for: quizCharacter, scriptFilter: .any, limit: 80).map(\.character))
        characters.append(contentsOf: store.componentRepo.related(for: quizCharacter, scriptFilter: .any, max: 40).map(\.character))
        characters.append(contentsOf: library.items.flatMap(\.characterHints))

        return characters.filter(isQuizOptionCharacter).map { character in
            ConversationPracticeQuizRules.CharacterChoiceCandidate(
                character: character,
                components: choiceComponents(for: character),
                rank: store.item(for: character)?.rank
            )
        }
    }

    func isQuizOptionCharacter(_ character: String) -> Bool {
        guard character == quizCharacter || !store.componentRepo.isUsedComponent(character) else { return false }
        guard let item = store.item(for: character) else { return character == quizCharacter }
        if item.definition.localizedCaseInsensitiveContains("radical") { return false }
        return true
    }

    func choiceComponents(for character: String) -> [String] {
        var parts = store.components(for: character).map(\.character)
        if let radical = store.item(for: character)?.radical,
           !radical.isEmpty,
           radical != "—",
           !parts.contains(radical) {
            parts.append(radical)
        }
        return parts
    }

    func openPhrase(_ item: ConversationPracticeItem) {
        let phrase = phraseItem(for: item)
        store.pushPhraseBreadcrumb(phrase)
        inspectionPath.append(.phrase(phrase))
    }

    func openCharacter(_ character: String) {
        store.pushRootBreadcrumb(character)
        inspectionPath.append(.character(character))
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
