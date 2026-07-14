import SwiftUI

extension PhraseInfoCard {
    var sentenceStudyContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            sentenceStudyToolbar
            sentenceMeaningBlock
            sentenceStudyNotes
            sentenceCharacterDisclosure
        }
    }

    var practiceSentenceItem: ConversationPracticeItem? {
        if case .sentence(let item) = favoriteTarget {
            return item
        }
        return nil
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

    var sentencePhraseHints: [PhraseItem] {
        if let phraseLookupOverride {
            return phraseLookupOverride
        }
        guard let practiceSentenceItem else { return [] }
        return store.storedPracticePhraseHints(for: practiceSentenceItem)
            .map {
                ConversationPracticeScriptSupport.displayPhrase(
                    $0,
                    usesTraditionalScript: sentenceUsesTraditionalScript,
                    store: store
                )
            }
    }

    var sentenceCharacterHints: [String] {
        guard let practiceSentenceItem else {
            return phraseCharacters
        }
        return ConversationPracticeScriptSupport.displayCharacters(
            for: practiceSentenceItem,
            excludingPhrases: sentencePhraseHints,
            usesTraditionalScript: sentenceUsesTraditionalScript,
            store: store
        )
    }

    var sentenceStudyToolbar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                sentenceScriptButton
                sentenceReadButton
                sentencePinyinButton
                sentencePhraseButton
                Spacer(minLength: 0)
                sentenceDeleteButton
                favoriteTargetButton
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    sentenceScriptButton
                    sentenceReadButton
                    sentencePinyinButton
                    sentencePhraseButton
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
                systemImage: showsSentencePinyin ? "eye.slash" : "textformat.abc",
                verticalPadding: 8
            )
        }
        .buttonStyle(.plain)
        .help(showsSentencePinyin ? "Hide pinyin" : "Show pinyin")
    }

    @ViewBuilder
    var sentencePhraseButton: some View {
        if !sentencePhraseHints.isEmpty {
            Button {
                showPhraseTableSheet = true
            } label: {
                InfoCardActionPill(title: "Phrase", textIcon: "词", verticalPadding: 8)
            }
            .buttonStyle(.plain)
            .help("Show sentence phrases")
        }
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

    @ViewBuilder
    var sentenceCharacterDisclosure: some View {
        let characters = sentenceCharacterHints
        if !characters.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showsSentenceCharacters.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Label("Characters", systemImage: "square.grid.2x2")
                            .font(ResponsiveFont.caption.weight(.semibold))
                        Spacer(minLength: 0)
                        Image(systemName: showsSentenceCharacters ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(RadixAccent.primary)
                    .padding(10)
                    .background(RadixAccent.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                if showsSentenceCharacters {
                    phraseAnimationPicker
                }
            }
        }
    }
}
