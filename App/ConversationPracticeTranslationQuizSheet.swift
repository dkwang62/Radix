import SwiftUI

struct ConversationPracticeTranslationQuizPresentation: Identifiable {
    let id = UUID()
    let library: ConversationPracticeLibrary
}

private struct ConversationPracticeTranslationRound: Equatable {
    let itemID: String
    let scriptFilter: ScriptFilter
    let choices: [ConversationPracticeItem]
}

struct ConversationPracticeTranslationQuizSheet: View {
    private static let sessionQuestionLimit = 20

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: RadixStore
    let library: ConversationPracticeLibrary
    @Binding var usesTraditionalScript: Bool
    @State private var currentIndex = 0
    @State private var sessionItems: [ConversationPracticeItem] = []
    @State private var selectedAnswerID: String?
    @State private var answered: [String: Bool] = [:]
    @State private var inspectionPath: [ConversationPracticeInspectionRoute] = []
    @State private var currentRound: ConversationPracticeTranslationRound?
    @State private var selectedScriptFilter: ScriptFilter = .simplified
    @State private var hasInitializedScript = false

    var quizItems: [ConversationPracticeItem] {
        sessionItems.isEmpty ? Array(library.items.prefix(Self.sessionQuestionLimit)) : sessionItems
    }

    var currentItem: ConversationPracticeItem {
        let items = quizItems
        return items[min(currentIndex, items.count - 1)]
    }

    private var round: ConversationPracticeTranslationRound? {
        guard currentRound?.itemID == currentItem.id,
              currentRound?.scriptFilter == selectedScriptFilter else { return nil }
        return currentRound
    }

    var hasAnsweredCurrent: Bool {
        selectedAnswerID != nil
    }

    var selectedIsCorrect: Bool {
        selectedAnswerID == currentItem.id
    }

    var isLastQuestion: Bool {
        currentIndex >= quizItems.count - 1
    }

    var score: Int {
        answered.values.filter { $0 }.count
    }

    var defaultScriptFilter: ScriptFilter {
        ConversationPracticeScriptSupport.filter(usesTraditionalScript: usesTraditionalScript)
    }

    var body: some View {
        NavigationStack(path: $inspectionPath) {
            ScrollView {
                Group {
                    if let round {
                        VStack(alignment: .leading, spacing: 14) {
                            progressHeader
                            scriptPicker
                            questionCard
                            answerChoices(round)
                            if hasAnsweredCurrent {
                                feedbackSection
                            }
                        }
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 180)
                    }
                }
                .padding()
            }
            .background(RadixTheme.background)
            .navigationTitle("Translate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .navigationDestination(for: ConversationPracticeInspectionRoute.self) { route in
                ConversationPracticeInspectionDestination(
                    route: route,
                    sourceTitle: "Translate",
                    onOpenCharacter: openCharacter
                )
                .environmentObject(store)
            }
            .onAppear {
                initializeScript()
                initializeSession()
                prepareCurrentRound()
            }
            .onChange(of: selectedScriptFilter) { _, newValue in
                changeScript(newValue)
            }
            .onChange(of: usesTraditionalScript) { _, _ in
                let newValue = defaultScriptFilter
                guard selectedScriptFilter != newValue else { return }
                changeScript(newValue)
            }
        }
    }

    var progressHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(library.set.title)
                    .font(ResponsiveFont.body.weight(.semibold))
                Text("\(currentIndex + 1) of \(quizItems.count)")
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

    var scriptPicker: some View {
        Picker("Script", selection: $selectedScriptFilter) {
            Text("Simplified").tag(ScriptFilter.simplified)
            Text("Traditional").tag(ScriptFilter.traditional)
        }
        .pickerStyle(.segmented)
    }

    var questionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Choose the Chinese sentence.")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)

            Text(currentItem.english)
                .font(.system(size: RadixPlatform.isPhone ? 28 : 36, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RadixTheme.secondaryBackground.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func answerChoices(_ round: ConversationPracticeTranslationRound) -> some View {
        VStack(spacing: 8) {
            ForEach(round.choices) { choice in
                Button {
                    choose(choice)
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Image(systemName: answerIcon(for: choice))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(answerTint(for: choice))
                                .frame(width: 24, height: 24)

                            Text(displayText(choice.simplified))
                                .font(ResponsiveFont.headline.weight(.semibold))
                                .lineLimit(2)
                                .minimumScaleFactor(0.75)
                        }

                        Text(choice.pinyin)
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.leading, 32)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
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
            Label(selectedIsCorrect ? "Correct" : "Review this sentence", systemImage: selectedIsCorrect ? "checkmark.circle.fill" : "arrow.counterclockwise.circle")
                .font(ResponsiveFont.body.weight(.semibold))
                .foregroundStyle(selectedIsCorrect ? Color.green : Color.orange)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(displayText(currentItem.simplified))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 8)

                    ConversationPracticeSpeechButton(
                        item: currentItem,
                        usesTraditionalScript: selectedScriptFilter == .traditional,
                        accessibilityLabel: "Read translated sentence"
                    )
                }
                Text(currentItem.pinyin)
                    .font(ResponsiveFont.body.weight(.semibold))
                Text(currentItem.english)
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

            let hints = store.linkedPracticeHints(for: currentItem)
            let characters = displayCharacters(for: currentItem, excludingPhrases: hints.phrases)
            if !characters.isEmpty {
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
        .padding(12)
        .background(RadixTheme.secondaryBackground.opacity(0.42))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    func initializeScript() {
        guard !hasInitializedScript else { return }
        selectedScriptFilter = defaultScriptFilter
        hasInitializedScript = true
    }

    func initializeSession() {
        guard sessionItems.isEmpty else { return }
        sessionItems = Array(library.items.shuffled().prefix(Self.sessionQuestionLimit))
        currentIndex = 0
        selectedAnswerID = nil
        answered = [:]
        currentRound = nil
    }

    func changeScript(_ scriptFilter: ScriptFilter) {
        guard scriptFilter == .simplified || scriptFilter == .traditional else { return }
        selectedScriptFilter = scriptFilter
        usesTraditionalScript = scriptFilter == .traditional
        selectedAnswerID = nil
        currentRound = nil
        prepareCurrentRound()
    }

    func prepareCurrentRound() {
        currentRound = ConversationPracticeTranslationRound(
            itemID: currentItem.id,
            scriptFilter: selectedScriptFilter,
            choices: translationChoices(for: currentItem)
        )
    }

    func translationChoices(for item: ConversationPracticeItem) -> [ConversationPracticeItem] {
        var choices = [item]
        let candidates = library.items
            .filter { $0.id != item.id }
            .shuffled()

        for candidate in candidates where choices.count < 4 {
            guard !choices.contains(where: { $0.english == candidate.english || phraseKey(for: $0) == phraseKey(for: candidate) }) else {
                continue
            }
            choices.append(candidate)
        }

        return choices.shuffled()
    }

    func choose(_ choice: ConversationPracticeItem) {
        selectedAnswerID = choice.id
        let isCorrect = choice.id == currentItem.id
        answered[currentItem.id] = isCorrect
        var snapshot = RadixStudyPreferences.conversationPracticeProgress
        snapshot.record(
            packID: currentItem.setID,
            itemID: currentItem.id,
            outcome: isCorrect ? .correct : .incorrect
        )
        RadixStudyPreferences.conversationPracticeProgress = snapshot
    }

    func advance() {
        guard !isLastQuestion else {
            dismiss()
            return
        }
        currentIndex += 1
        selectedAnswerID = nil
        prepareCurrentRound()
    }

    func answerIcon(for choice: ConversationPracticeItem) -> String {
        guard hasAnsweredCurrent else { return "circle" }
        if choice.id == currentItem.id { return "checkmark.circle.fill" }
        if choice.id == selectedAnswerID { return "xmark.circle.fill" }
        return "circle"
    }

    func answerTint(for choice: ConversationPracticeItem) -> Color {
        guard hasAnsweredCurrent else { return .secondary }
        if choice.id == currentItem.id { return .green }
        if choice.id == selectedAnswerID { return .red }
        return .secondary
    }

    func answerBackground(for choice: ConversationPracticeItem) -> Color {
        guard hasAnsweredCurrent else { return RadixTheme.secondaryBackground.opacity(0.45) }
        if choice.id == currentItem.id { return Color.green.opacity(0.12) }
        if choice.id == selectedAnswerID { return Color.red.opacity(0.1) }
        return RadixTheme.secondaryBackground.opacity(0.34)
    }

    func displayText(_ text: String) -> String {
        ConversationPracticeScriptSupport.displayText(
            text,
            usesTraditionalScript: selectedScriptFilter == .traditional,
            store: store
        )
    }

    func displayCharacters(for item: ConversationPracticeItem, excludingPhrases phrases: [PhraseItem]) -> [String] {
        ConversationPracticeScriptSupport.displayCharacters(
            for: item,
            excludingPhrases: phrases,
            usesTraditionalScript: selectedScriptFilter == .traditional,
            store: store
        )
    }

    func phraseKey(for item: ConversationPracticeItem) -> String {
        store.phraseStorageWord(item.simplified)
    }

    func openPhrase(_ item: ConversationPracticeItem) {
        let phrase = ConversationPracticeScriptSupport.phraseItem(
            for: item,
            usesTraditionalScript: selectedScriptFilter == .traditional,
            store: store
        )
        store.readPhraseAloud(phrase)
        store.pushPhraseBreadcrumb(phrase)
        inspectionPath.append(.phrase(phrase))
    }

    func openCharacter(_ character: String) {
        store.readCharacterAloud(character)
        store.pushRootBreadcrumb(character)
        inspectionPath.append(.character(character))
    }
}
