import SwiftUI

extension PhraseInfoCard {
    var normalizedPhraseWord: String {
        store.normalizedPhraseWord(phrase.word)
    }

    var canDeleteAddedPhrase: Bool {
        store.isPhraseInAdd(normalizedPhraseWord) && !store.isPhraseInBase(normalizedPhraseWord)
    }

    func deleteAddedPhrase() {
        do {
            _ = try store.removeAddedPhrases(words: [normalizedPhraseWord])
            editStatus = "Phrase deleted."
            RadixHaptics.success()
            onDone?()
        } catch {
            editStatus = "Delete failed: \(error.localizedDescription)"
            RadixHaptics.error()
        }
    }

    func deletePracticeSentence() {
        guard let practiceSentenceItem else { return }
        do {
            try store.deleteSentenceExample(practiceSentenceItem)
            RadixHaptics.success()
            onDone?()
        } catch {
            editStatus = "Delete failed: \(error.localizedDescription)"
            RadixHaptics.error()
        }
    }

    var practiceSentenceToolbar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                scriptSegment
                phraseLookupButton
                sentenceExamplesButton
                sentenceReadButton
                Spacer(minLength: 0)
                favoriteTargetButton
                if !isEditingNotes {
                    editNotesButton
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    scriptSegment
                    phraseLookupButton
                    sentenceExamplesButton
                }

                HStack(spacing: 8) {
                    sentenceReadButton
                    favoriteTargetButton
                    if !isEditingNotes {
                        editNotesButton
                    }
                }
            }
        }
    }

    var sentenceReadButton: some View {
        Button {
            if let practiceSentenceItem {
                store.readPhraseAloud(ConversationPracticeScriptSupport.phraseItem(
                    for: practiceSentenceItem,
                    usesTraditionalScript: sentenceUsesTraditionalScript,
                    store: store
                ))
            } else {
                store.readPhraseAloud(phrase)
            }
        } label: {
            Image(systemName: "speaker.wave.2")
                .font(ResponsiveFont.subheadline.weight(.semibold))
                .foregroundStyle(RadixAccent.primary)
                .radixIconButtonSurface(size: 32)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Read sentence aloud")
        .help("Read sentence aloud")
    }

    var animationScriptToggle: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                scriptSegment
                Spacer(minLength: 0)
                phraseLookupButton
                sentenceExamplesButton
            }

            VStack(alignment: .leading, spacing: 10) {
                scriptSegment
                HStack(spacing: 8) {
                    phraseLookupButton
                    sentenceExamplesButton
                }
            }
        }
    }

    var scriptSegment: some View {
        CompactScriptToggle(
            isTraditional: animationScript == "traditional",
            accessibilityLabel: "Phrase animation script",
            minWidth: 42,
            height: 30
        ) {
            animationScript = animationScript == "traditional" ? "simplified" : "traditional"
        }
    }

    @ViewBuilder
    var phraseLookupButton: some View {
        if shouldShowPhraseLookupButton {
            Button {
                showPhraseTableSheet = true
            } label: {
                InfoCardActionPill(title: "Phrase", textIcon: "词", verticalPadding: 8)
            }
            .buttonStyle(.plain)
            .help("Show phrases")
        }
    }

    var shouldShowPhraseLookupButton: Bool {
        guard phraseLookupDepth.allowsPhraseLookup else { return false }
        if isPracticeSentence {
            return phraseCharacters.count > 1
        }
        if let phraseLookupOverride {
            return !phraseLookupOverride.isEmpty
        }
        return phraseCharacters.count > 1
    }

    @ViewBuilder
    var sentenceExamplesButton: some View {
        if shouldShowSentenceExamplesButton {
            Button {
                showSentenceExampleSheet = true
            } label: {
                InfoCardActionPill(
                    title: "Examples",
                    systemImage: RadixGlossaryIcon.systemImage(for: "Sentence"),
                    verticalPadding: 8
                )
            }
            .buttonStyle(.plain)
            .help("Show sentence examples")
        }
    }

    var shouldShowSentenceExamplesButton: Bool {
        !SentenceExampleDisplayRules.examples(containingPhrase: phrase.word, limit: 1).isEmpty
    }
}
