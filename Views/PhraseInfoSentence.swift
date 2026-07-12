import SwiftUI

private struct SentencePhraseHighlightSegment: Identifiable {
    let id = UUID()
    let text: String
    let isPhrase: Bool
}

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
        return store.verifiedPracticePhraseHints(for: practiceSentenceItem)
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
                favoriteTargetButton
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    sentenceScriptButton
                    sentenceReadButton
                    sentencePinyinButton
                    sentencePhraseButton
                }
                favoriteTargetButton
            }
        }
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
        RadixTileFlowLayout(horizontalSpacing: 3, verticalSpacing: 5) {
            ForEach(sentencePhraseHighlightSegments) { segment in
                Text(segment.text)
                    .font(.system(size: RadixPlatform.isPhone ? 25 : 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, segment.isPhrase ? 4 : 0)
                    .padding(.vertical, segment.isPhrase ? 2 : 0)
                    .background(segment.isPhrase ? RadixAccent.primary.opacity(0.14) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: segment.isPhrase ? 6 : 0))
                    .overlay(alignment: .bottom) {
                        if segment.isPhrase {
                            Rectangle()
                                .fill(RadixAccent.primary.opacity(0.7))
                                .frame(height: 2)
                                .offset(y: 2)
                        }
                    }
                    .phraseContextMenu(phrase)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityLabel(sentenceDisplayChinese)
    }

    private var sentencePhraseHighlightSegments: [SentencePhraseHighlightSegment] {
        let text = sentenceDisplayChinese
        let phrases = sentencePhraseHints.map(\.word).filter { !$0.isEmpty }
        guard !text.isEmpty, !phrases.isEmpty else {
            return sentencePlainHighlightSegments(text)
        }

        var segments: [SentencePhraseHighlightSegment] = []
        var cursor = text.startIndex

        for phrase in phrases {
            guard cursor < text.endIndex,
                  let range = text.range(of: phrase, range: cursor..<text.endIndex)
            else { continue }

            if cursor < range.lowerBound {
                segments.append(contentsOf: sentencePlainHighlightSegments(String(text[cursor..<range.lowerBound])))
            }
            segments.append(SentencePhraseHighlightSegment(text: phrase, isPhrase: true))
            cursor = range.upperBound
        }

        if cursor < text.endIndex {
            segments.append(contentsOf: sentencePlainHighlightSegments(String(text[cursor..<text.endIndex])))
        }

        return segments.isEmpty ? sentencePlainHighlightSegments(text) : segments
    }

    private func sentencePlainHighlightSegments(_ text: String) -> [SentencePhraseHighlightSegment] {
        text.map { SentencePhraseHighlightSegment(text: String($0), isPhrase: false) }
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
