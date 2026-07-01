import SwiftUI

struct ConversationPracticeQuizPresentation: Identifiable {
    let id = UUID()
    let library: ConversationPracticeLibrary
}

private struct ConversationPracticeQuizRound: Equatable {
    let itemID: String
    let scriptFilter: ScriptFilter
    let question: ConversationPracticeQuizRules.CharacterQuestion
    let choices: [String]
}

struct ConversationPracticeQuizSheet: View {
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
    @State private var currentRound: ConversationPracticeQuizRound?
    @State private var selectedQuizScriptFilter: ScriptFilter = .simplified
    @State private var hasInitializedQuizScript = false
    @State private var candidateCache: [String: ConversationPracticeQuizRules.CharacterChoiceCandidate] = [:]
    @State private var peerCache: [String: [String]] = [:]

    var quizItems: [ConversationPracticeItem] {
        sessionItems.isEmpty ? Array(library.items.prefix(Self.sessionQuestionLimit)) : sessionItems
    }

    var currentItem: ConversationPracticeItem {
        let items = quizItems
        return items[min(currentIndex, items.count - 1)]
    }

    private var round: ConversationPracticeQuizRound? {
        guard currentRound?.itemID == currentItem.id,
              currentRound?.scriptFilter == quizScriptFilter else { return nil }
        return currentRound
    }

    var quizCharacter: String {
        round?.question.character ?? ConversationPracticeQuizRules.questionCharacter(for: currentItem)
    }

    var currentCharacterItem: ComponentItem? {
        store.item(for: quizCharacter)
    }

    var choices: [String] {
        round?.choices ?? []
    }

    var quizScriptFilter: ScriptFilter {
        selectedQuizScriptFilter
    }

    var defaultQuizScriptFilter: ScriptFilter {
        ConversationPracticeScriptSupport.filter(usesTraditionalScript: usesTraditionalScript)
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
                Group {
                    if let round {
                        VStack(alignment: .leading, spacing: 14) {
                            progressHeader
                            scriptPicker
                            questionCard(round)
                            answerChoices
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
            .onAppear {
                initializeQuizScript()
                initializeQuizSession()
                prepareCurrentRound()
            }
            .onChange(of: selectedQuizScriptFilter) { _, newValue in
                changeQuizScript(newValue)
            }
            .onChange(of: usesTraditionalScript) { _, _ in
                let newValue = defaultQuizScriptFilter
                guard selectedQuizScriptFilter != newValue else { return }
                changeQuizScript(newValue)
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
        Picker("Script", selection: $selectedQuizScriptFilter) {
            Text("Simplified").tag(ScriptFilter.simplified)
            Text("Traditional").tag(ScriptFilter.traditional)
        }
        .pickerStyle(.segmented)
    }

    private func questionCard(_ round: ConversationPracticeQuizRound) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Which character completes the sentence?")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)

                Text(round.question.blankedSentence)
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

            let characterHints = quizCharacterHints(for: currentItem)
            if !characterHints.isEmpty {
                RadixTileFlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                    ForEach(characterHints, id: \.self) { character in
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
        currentIndex >= quizItems.count - 1
    }

    func choose(_ choice: String) {
        selectedAnswerID = choice
        answered["\(currentItem.id)#\(quizCharacter)"] = choice == quizCharacter
        var snapshot = RadixStudyPreferences.conversationPracticeProgress
        snapshot.record(
            packID: currentItem.setID,
            itemID: currentItem.id,
            outcome: choice == quizCharacter ? .correct : .incorrect
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

    func prepareCurrentRound() {
        currentRound = makeRound(for: currentItem)
    }

    func initializeQuizScript() {
        guard !hasInitializedQuizScript else { return }
        selectedQuizScriptFilter = defaultQuizScriptFilter
        hasInitializedQuizScript = true
    }

    func initializeQuizSession() {
        guard sessionItems.isEmpty else { return }
        sessionItems = Array(library.items.shuffled().prefix(Self.sessionQuestionLimit))
        currentIndex = 0
        selectedAnswerID = nil
        answered = [:]
        currentRound = nil
    }

    func changeQuizScript(_ scriptFilter: ScriptFilter) {
        guard scriptFilter == .simplified || scriptFilter == .traditional else { return }
        selectedQuizScriptFilter = scriptFilter
        usesTraditionalScript = scriptFilter == .traditional
        selectedAnswerID = nil
        currentRound = nil
        candidateCache.removeAll()
        peerCache.removeAll()
        prepareCurrentRound()
    }

    private func makeRound(for item: ConversationPracticeItem) -> ConversationPracticeQuizRound {
        let questionCandidates = questionChoiceCandidates(for: item)
        let question = ConversationPracticeQuizRules.characterQuestion(
            sentence: quizSentence(for: item),
            characterHints: quizCharacterHints(for: item),
            candidates: questionCandidates
        )
        let choiceCandidates = characterChoiceCandidates(for: question.character)
        let choices = ConversationPracticeQuizRules.characterChoices(
            for: question.character,
            from: choiceCandidates
        ).shuffled()

        return ConversationPracticeQuizRound(
            itemID: item.id,
            scriptFilter: quizScriptFilter,
            question: question,
            choices: choices
        )
    }

    func characterChoiceCandidates(for character: String) -> [ConversationPracticeQuizRules.CharacterChoiceCandidate] {
        var characters = [character]
        characters.append(contentsOf: peers(for: character, limit: 80))
        characters.append(contentsOf: quizItems.flatMap(quizCharacterHints(for:)))

        var candidates = characterChoiceCandidates(from: characters, allowingAnswer: character)
        if candidates.count < 4 {
            let fallbackCharacters = fallbackChoiceCharacters(
                for: character,
                excluding: Set(candidates.map(\.character)),
                limit: 80
            )
            candidates.append(contentsOf: characterChoiceCandidates(from: fallbackCharacters, allowingAnswer: nil))
        }
        return candidates
    }

    func questionChoiceCandidates(for item: ConversationPracticeItem) -> [ConversationPracticeQuizRules.CharacterChoiceCandidate] {
        let hints = quizCharacterHints(for: item)
        var characters = hints
        for character in hints where isPotentialQuizOptionCharacter(character) {
            characters.append(contentsOf: peers(for: character, limit: 24))
        }
        return characterChoiceCandidates(from: characters, allowingAnswer: nil)
    }

    func peers(for character: String, limit: Int) -> [String] {
        let cacheKey = "\(quizScriptFilter.rawValue)#\(character)#\(limit)"
        if let cached = peerCache[cacheKey] {
            return cached
        }

        let peers = store.componentRepo.confusablePeers(
            for: character,
            scriptFilter: quizScriptFilter,
            limit: limit
        ).map(\.character)
        peerCache[cacheKey] = peers
        return peers
    }

    func characterChoiceCandidates(
        from characters: [String],
        allowingAnswer answer: String?
    ) -> [ConversationPracticeQuizRules.CharacterChoiceCandidate] {
        var seen = Set<String>()
        var result: [ConversationPracticeQuizRules.CharacterChoiceCandidate] = []
        for character in characters {
            guard seen.insert(character).inserted else { continue }
            guard isQuizOptionCharacter(character, allowingAnswer: answer) else { continue }
            if let candidate = characterChoiceCandidate(for: character) {
                result.append(candidate)
            } else if character == answer {
                result.append(ConversationPracticeQuizRules.CharacterChoiceCandidate(character: character))
            }
        }
        return result
    }

    func characterChoiceCandidate(for character: String) -> ConversationPracticeQuizRules.CharacterChoiceCandidate? {
        let cacheKey = "\(quizScriptFilter.rawValue)#\(character)"
        if let cached = candidateCache[cacheKey] {
            return cached
        }

        guard isPotentialQuizOptionCharacter(character) else { return nil }
        let candidate = ConversationPracticeQuizRules.CharacterChoiceCandidate(
            character: character,
            components: choiceComponents(for: character),
            rank: store.item(for: character)?.rank
        )
        candidateCache[cacheKey] = candidate
        return candidate
    }

    func fallbackChoiceCharacters(for character: String, excluding excludedCharacters: Set<String>, limit: Int) -> [String] {
        let answerVariants = Set(store.componentRepo.allVariants(for: character))
        var seen = excludedCharacters.union(answerVariants)
        seen.insert(character)
        var result: [String] = []

        func append(_ characters: [String]) {
            for candidate in characters {
                guard result.count < limit else { return }
                guard seen.insert(candidate).inserted else { continue }
                guard isPotentialQuizOptionCharacter(candidate) else { continue }
                result.append(candidate)
            }
        }

        append(store.componentRepo.sharedComponentPeers(
            for: character,
            scriptFilter: quizScriptFilter,
            limit: limit
        ).map(\.character))
        append(store.componentRepo.related(
            for: character,
            scriptFilter: quizScriptFilter,
            max: limit
        ).map(\.character))

        let rankedDictionaryCharacters = store.componentRepo.byCharacter.values
            .filter { item in
                item.character != character
                && !seen.contains(item.character)
                && isPotentialQuizOptionCharacter(item.character)
            }
            .sorted { lhs, rhs in
                let lhsRank = lhs.rank ?? Int.max
                let rhsRank = rhs.rank ?? Int.max
                if lhsRank != rhsRank { return lhsRank < rhsRank }

                return lhs.character < rhs.character
            }
            .map(\.character)
        append(rankedDictionaryCharacters)

        return result
    }

    func isQuizOptionCharacter(_ character: String, allowingAnswer answer: String?) -> Bool {
        character == answer || isPotentialQuizOptionCharacter(character)
    }

    func isPotentialQuizOptionCharacter(_ character: String) -> Bool {
        guard character.count == 1 else { return false }
        guard character.unicodeScalars.contains(where: { (0x4E00...0x9FFF).contains(Int($0.value)) }) else { return false }
        guard let item = store.item(for: character) else { return false }
        guard store.componentRepo.matchesScriptFilter(item: item, filter: quizScriptFilter) else { return false }
        if item.definition.localizedCaseInsensitiveContains("radical") { return false }
        return true
    }

    func choiceComponents(for character: String) -> [String] {
        var parts = store.componentRepo.components(for: character, scriptFilter: quizScriptFilter).map(\.character)
        if let radical = store.item(for: character)?.radical,
           !radical.isEmpty,
           radical != "—",
           !parts.contains(radical) {
            parts.append(radical)
        }
        return parts
    }

    func quizSentence(for item: ConversationPracticeItem) -> String {
        ConversationPracticeScriptSupport.displayText(
            item.simplified,
            usesTraditionalScript: quizScriptFilter == .traditional,
            store: store
        )
    }

    func quizCharacterHints(for item: ConversationPracticeItem) -> [String] {
        ConversationPracticeScriptSupport.displayCharacters(
            for: item,
            usesTraditionalScript: quizScriptFilter == .traditional,
            store: store
        )
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
        ConversationPracticeScriptSupport.phraseItem(
            for: item,
            usesTraditionalScript: quizScriptFilter == .traditional,
            store: store
        )
    }
}
