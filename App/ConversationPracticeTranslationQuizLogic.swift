import SwiftUI

extension ConversationPracticeTranslationQuizSheet {
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
            direction: direction,
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
        answered[answerKey(for: currentItem)] = isCorrect
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
            dismissSheet()
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

    func answerKey(for item: ConversationPracticeItem) -> String {
        "\(direction.rawValue)#\(item.id)"
    }

    func openPhrase(_ item: ConversationPracticeItem) {
        let phrase = ConversationPracticeScriptSupport.phraseItem(
            for: item,
            usesTraditionalScript: selectedScriptFilter == .traditional,
            store: store
        )
        store.readPhraseAloud(phrase)
        store.pushPhraseBreadcrumb(phrase)
        inspectionPath.append(.phrase(phrase, item))
    }

    func openCharacter(_ character: String) {
        store.readCharacterAloud(character)
        store.pushRootBreadcrumb(character)
        inspectionPath.append(.character(character))
    }
}
