import SwiftUI

extension PhraseInfoCard {
    var sentenceSourceID: String? {
        guard case .sentence(let item) = favoriteTarget else { return nil }
        return item.id
    }

    var sentenceStudyContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            sentenceStudyToolbar
            sentenceMeaningBlock
            sentenceImprovementStatusLine
            phraseAnimationPicker
            sentenceStudyNotes
        }
    }

    var practiceSentenceItem: ConversationPracticeItem? {
        if let locallyImprovedSentenceItem {
            return locallyImprovedSentenceItem
        }
        if case .sentence(let item) = favoriteTarget {
            return item
        }
        return nil
    }

    var sentencePhraseLookupPhrases: [PhraseItem]? {
        guard let practiceSentenceItem else { return nil }
        let phrases = store.allPracticePhraseMatches(for: practiceSentenceItem)
            .map {
                ConversationPracticeScriptSupport.displayPhrase(
                    $0,
                    usesTraditionalScript: sentenceUsesTraditionalScript,
                    store: store
                )
            }
        return phrases.isEmpty ? nil : phrases
    }

    var sentenceUsesTraditionalScript: Bool {
        animationScript == "traditional"
    }

    var sentenceDisplayChinese: String {
        if let practiceSentenceItem {
            return ConversationPracticeScriptSupport.displayText(
                practiceSentenceItem.simplified,
                usesTraditionalScript: sentenceUsesTraditionalScript,
                store: store
            )
        }
        return sentenceUsesTraditionalScript ? store.traditionalText(phrase.word) : store.simplifiedText(phrase.word)
    }

    var sentenceEnglish: String {
        if let practiceSentenceItem,
           !practiceSentenceItem.english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return practiceSentenceItem.english
        }
        return phrase.meanings
    }

    var sentencePinyin: String {
        if let practiceSentenceItem,
           !practiceSentenceItem.pinyin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return practiceSentenceItem.pinyin
        }
        return phrase.pinyin
    }

    var sentenceStudyToolbar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                sentenceScriptButton
                sentenceReadButton
                sentencePinyinButton
                phraseLookupButton
                Spacer(minLength: 0)
                sentenceDeleteButton
                favoriteTargetButton
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    sentenceScriptButton
                    sentenceReadButton
                    sentencePinyinButton
                    phraseLookupButton
                }
                HStack(spacing: 8) {
                    sentenceDeleteButton
                    favoriteTargetButton
                }
            }
        }
    }

    var sentenceDeleteButton: some View {
        Button(role: .destructive) {
            showDeleteSentenceConfirmation = true
        } label: {
            Image(systemName: "trash")
                .font(ResponsiveFont.subheadline.weight(.semibold))
                .foregroundStyle(Color.red)
                .radixIconButtonSurface()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Delete sentence")
        .help("Delete sentence")
    }

    var sentenceScriptButton: some View {
        CompactScriptToggle(
            isTraditional: sentenceUsesTraditionalScript,
            accessibilityLabel: "Sentence script",
            minWidth: 42,
            height: 30
        ) {
            animationScript = sentenceUsesTraditionalScript ? "simplified" : "traditional"
        }
    }

    var sentencePinyinButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                showsSentencePinyin.toggle()
            }
        } label: {
            InfoCardActionPill(
                title: showsSentencePinyin ? "Hide Pinyin" : "Pinyin",
                systemImage: showsSentencePinyin ? "eye.slash" : nil,
                textIcon: showsSentencePinyin ? nil : "拼",
                verticalPadding: 8
            )
        }
        .buttonStyle(.plain)
        .help(showsSentencePinyin ? "Hide pinyin" : "Show pinyin")
    }

    var sentenceMeaningBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            sentenceHighlightedChineseText

            if showsSentencePinyin {
                let pinyin = sentencePinyin.trimmingCharacters(in: .whitespacesAndNewlines)
                if !pinyin.isEmpty {
                    Text(pinyin)
                        .font(ResponsiveFont.body.weight(.semibold))
                        .foregroundStyle(Color.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            let english = sentenceEnglish.trimmingCharacters(in: .whitespacesAndNewlines)
            if !english.isEmpty {
                Text(english)
                    .font(ResponsiveFont.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RadixTheme.secondaryBackground.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contextMenu {
            if let practiceSentenceItem {
                Menu("Explain Sentence") {
                    Button(PageAIMethodCopy.manualTitle) {
                        store.triggerSentenceAI(practiceSentenceItem)
                    }
                    sentenceAutomaticAIButton(
                        title: PageAIMethodCopy.apiTitle,
                        isDisabled: isRunningSentenceImprovement
                    ) {
                        runAutomaticSentenceExplanation(practiceSentenceItem)
                    }
                }

                Menu("Improve Sentence") {
                    Button(PageAIMethodCopy.manualTitle) {
                        store.goToAILinkSentenceTask(
                            practiceSentenceItem,
                            taskID: PromptConfig.sentenceImprovementTaskID
                        )
                    }
                    sentenceAutomaticAIButton(
                        title: PageAIMethodCopy.apiTitle,
                        isDisabled: isRunningSentenceImprovement
                    ) {
                        runAutomaticSentenceImprovement(practiceSentenceItem)
                    }
                }
            }
        }
    }

    @ViewBuilder
    func sentenceAutomaticAIButton(
        title: String,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        if store.geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Button("Set Up Gemini Key…") {
                store.goToSettingsForAPIKeySetup()
            }
        } else {
            Button(title, action: action)
                .disabled(isDisabled)
        }
    }

    @ViewBuilder
    var sentenceImprovementStatusLine: some View {
        if sentenceImprovementStatus != nil || hasLatestSentenceExplanation {
            HStack(alignment: .center, spacing: 10) {
                if let sentenceImprovementStatus {
                    Text(sentenceImprovementStatus)
                        .font(ResponsiveFont.caption2.weight(.semibold))
                        .foregroundStyle(isRunningSentenceImprovement ? .secondary : RadixAccent.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                if hasLatestSentenceExplanation {
                    Button {
                        store.showLatestAIResult = true
                    } label: {
                        Label("Read Explanation", systemImage: "doc.text.magnifyingglass")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

    var hasLatestSentenceExplanation: Bool {
        guard let result = store.latestAIResult,
              result.taskTitle == "Explain Sentence",
              let practiceSentenceItem else { return false }
        return result.subject == practiceSentenceItem.simplified
    }

    func runAutomaticSentenceImprovement(_ item: ConversationPracticeItem) {
        guard !isRunningSentenceImprovement else { return }
        guard !store.geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            store.goToSettingsForAPIKeySetup()
            return
        }

        let requestID = UUID()
        activeSentenceAIRequestID = requestID
        isRunningSentenceImprovement = true
        sentenceImprovementStatus = "Improving sentence with Gemini..."
        sentenceAITask = Task { @MainActor in
            do {
                let record = try await store.runGeminiSentenceImprovement(to: item)
                guard acceptsSentenceAICompletion(requestID: requestID, sentenceID: item.id) else { return }
                locallyImprovedSentenceItem = ConversationPracticeItem(sentenceExample: record, rank: item.rank)
                sentenceImprovementStatus = "Sentence updated."
                finishSentenceAIWork(requestID: requestID)
                RadixHaptics.success()
            } catch {
                guard acceptsSentenceAICompletion(requestID: requestID, sentenceID: item.id) else { return }
                sentenceImprovementStatus = "Automatic improvement failed: \(error.localizedDescription)"
                finishSentenceAIWork(requestID: requestID)
                RadixHaptics.error()
            }
        }
    }

    func runAutomaticSentenceExplanation(_ item: ConversationPracticeItem) {
        guard !isRunningSentenceImprovement else { return }
        guard !store.geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            store.goToSettingsForAPIKeySetup()
            return
        }

        let requestID = UUID()
        activeSentenceAIRequestID = requestID
        isRunningSentenceImprovement = true
        sentenceImprovementStatus = "Explaining sentence with Gemini..."
        sentenceAITask = Task { @MainActor in
            do {
                let explanation = try await store.runGeminiSentenceExplanation(for: item)
                guard acceptsSentenceAICompletion(requestID: requestID, sentenceID: item.id) else { return }
                store.publishLatestAIResult(
                    taskTitle: "Explain Sentence",
                    subject: item.simplified,
                    body: explanation
                )
                store.showLatestAIResult = true
                sentenceImprovementStatus = "Explanation ready."
                finishSentenceAIWork(requestID: requestID)
                RadixHaptics.success()
            } catch {
                guard acceptsSentenceAICompletion(requestID: requestID, sentenceID: item.id) else { return }
                sentenceImprovementStatus = "Automatic explanation failed: \(error.localizedDescription)"
                finishSentenceAIWork(requestID: requestID)
                RadixHaptics.error()
            }
        }
    }

    func acceptsSentenceAICompletion(requestID: UUID, sentenceID: String) -> Bool {
        !Task.isCancelled && activeSentenceAIRequestID == requestID && sentenceSourceID == sentenceID
    }

    func finishSentenceAIWork(requestID: UUID) {
        guard activeSentenceAIRequestID == requestID else { return }
        activeSentenceAIRequestID = nil
        sentenceAITask = nil
        isRunningSentenceImprovement = false
    }

    func cancelSentenceAIWork() {
        sentenceAITask?.cancel()
        sentenceAITask = nil
        activeSentenceAIRequestID = nil
        isRunningSentenceImprovement = false
    }

    var sentenceHighlightedChineseText: some View {
        Text(sentenceDisplayChinese)
            .font(.system(size: RadixPlatform.isPhone ? 25 : 30, weight: .bold, design: .rounded))
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
            .accessibilityLabel(sentenceDisplayChinese)
    }

    @ViewBuilder
    var sentenceStudyNotes: some View {
        let notes = phrase.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !notes.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                RadixTermLabel(term: RadixTerm.notes)
                    .font(ResponsiveFont.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(notes)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RadixTheme.secondaryBackground.opacity(0.32))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
